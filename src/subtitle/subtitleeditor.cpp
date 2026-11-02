////////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2026 白い熊
//
// This file is part of shiroikuma-yosuga, a fork of Memento.
//
// Memento is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 2 of the License.
//
// Memento is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Memento.  If not, see <https://www.gnu.org/licenses/>.
//
////////////////////////////////////////////////////////////////////////////////

#include "subtitle/subtitleeditor.h"

#include <cmath>
#include <cstdio>
#include <functional>
#include <optional>

#include <QDir>
#include <QFile>
#include <QHash>
#include <QSet>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStorageInfo>
#include <QStringConverter>
#include <QTemporaryDir>
#include <QUuid>
#include <QtConcurrent>

#include "player/mpvplayer.h"
#include "subtitle/subtitlelistmodel.h"

namespace
{

enum class Format
{
    Srt,
    Vtt,
    Ass,
};

struct EditRequest
{
    /* The subtitle file, or the Matroska file holding the track */
    QString path;
    bool matroska{false};

    /* mpv's src-id: the Matroska TrackNumber for the mkv demuxer */
    int64_t srcId{0};

    /* The cue start in file time */
    double fileStart{0};

    QString oldText;
    QString newText;
};

struct EditResult
{
    bool ok{false};
    QString message;
};

/* Reports a stage (0 = extracting, 1 = writing) and its completion 0–1 */
using Progress = std::function<void(int stage, double fraction)>;

/* Seconds a cue start may drift from mpv's report and still be a candidate */
constexpr double START_TOLERANCE = 1.0;

/**
 * Parses H:MM:SS.mmm, MM:SS.mmm, H:MM:SS,mmm and ASS H:MM:SS.cc.
 */
std::optional<double> parseTimecode(const QString &timecode)
{
    static const QRegularExpression re{
        "^\\s*(?:(\\d+):)?(\\d{1,2}):(\\d{1,2})[.,](\\d{1,3})\\s*$"
    };
    const QRegularExpressionMatch m = re.match(timecode);
    if (!m.hasMatch())
    {
        return std::nullopt;
    }
    const QString fraction = m.captured(4);
    return m.captured(1).toDouble() * 3600.0 +
           m.captured(2).toDouble() * 60.0 +
           m.captured(3).toDouble() +
           fraction.toDouble() / std::pow(10.0, fraction.size());
}

/**
 * The text a cue renders to, for comparison with mpv's sub-text.
 */
QString plainText(const QString &raw, Format format)
{
    static const QRegularExpression braces{"\\{[^}]*\\}"};
    static const QRegularExpression angles{"<[^>]*>"};
    static const QRegularExpression assNewline{"\\\\[Nn]"};

    QString text = raw;
    text.remove(braces);
    if (format == Format::Ass)
    {
        text.replace(assNewline, "\n");
        text.replace("\\h", " ");
    }
    else
    {
        text.remove(angles);
        text.replace("&lt;", "<");
        text.replace("&gt;", ">");
        text.replace("&nbsp;", " ");
        text.replace("&amp;", "&");
    }
    return text;
}

/**
 * Whitespace-insensitive key, so line breaks and spacing differences between
 * mpv's rendering and the file never break a match.
 */
QString compareKey(const QString &text)
{
    static const QRegularExpression whitespace{"\\s+"};
    QString key = text;
    key.remove(whitespace);
    return key;
}

/**
 * Rebuilds a cue's raw text: formatting tags that wrap the whole cue (a
 * leading {\an8} or <i>, a closing </i>) are kept around the new text.
 */
QString rebuildRaw(const QString &oldRaw, QString newText, Format format)
{
    static const QRegularExpression prefixRe{
        "^(?:\\s*(?:<[^>]*>|\\{[^}]*\\}))*"
    };
    static const QRegularExpression suffixRe{
        "(?:(?:<[^>]*>|\\{[^}]*\\})\\s*)*$"
    };

    QString prefix = prefixRe.match(oldRaw).captured(0);
    QString suffix = suffixRe.match(oldRaw).captured(0);
    if (prefix.size() + suffix.size() > oldRaw.size())
    {
        suffix.clear();
    }
    if (format == Format::Ass)
    {
        /* ASS cue text takes no angle-bracket markup */
        static const QRegularExpression angles{"<[^>]*>"};
        prefix.remove(angles);
        suffix.remove(angles);
    }

    QStringList lines;
    for (const QString &line : newText.split('\n'))
    {
        QString l = line;
        while (!l.isEmpty() && l.back().isSpace())
        {
            l.chop(1);
        }
        /* A blank line would end an SRT/VTT cue */
        if (!l.trimmed().isEmpty())
        {
            lines << l;
        }
    }
    QString body;
    if (format == Format::Ass)
    {
        body = lines.join("\\N");
    }
    else
    {
        body = lines.join('\n');
        if (format == Format::Vtt)
        {
            body.replace("&", "&amp;");
            body.replace("<", "&lt;");
            body.replace(">", "&gt;");
        }
    }
    return prefix + body + suffix;
}

struct TextFile
{
    QStringList lines;
    QStringConverter::Encoding encoding{QStringConverter::Utf8};
    bool bom{false};
    bool crlf{false};
};

bool readTextFile(const QString &path, TextFile &out, QString &error)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
    {
        error = QObject::tr("Cannot read %1: %2").arg(path, file.errorString());
        return false;
    }
    const QByteArray bytes = file.readAll();

    std::optional<QStringConverter::Encoding> detected =
        QStringConverter::encodingForData(bytes);
    out.encoding = detected.value_or(QStringConverter::Utf8);
    out.bom = detected.has_value();

    QStringDecoder decoder(out.encoding, QStringConverter::Flag::Stateless);
    QString text = decoder.decode(bytes);
    if (decoder.hasError())
    {
        error = QObject::tr(
            "%1 is not UTF-8 — refusing to rewrite it").arg(QFileInfo(path).fileName());
        return false;
    }
    if (!text.isEmpty() && text.front() == QChar(0xFEFF))
    {
        text.remove(0, 1);
        out.bom = true;
    }

    out.crlf = text.contains("\r\n");
    text.replace("\r\n", "\n");
    text.replace('\r', '\n');
    out.lines = text.split('\n');
    return true;
}

bool writeTextFile(const QString &path, const TextFile &in, QString &error)
{
    QString text = in.lines.join(in.crlf ? "\r\n" : "\n");
    if (in.bom)
    {
        text.prepend(QChar(0xFEFF));
    }
    QStringEncoder encoder(in.encoding, QStringConverter::Flag::Stateless);
    const QByteArray bytes = encoder.encode(text);

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly) ||
        file.write(bytes) != bytes.size() ||
        !file.commit())
    {
        error = QObject::tr("Cannot write %1: %2").arg(path, file.errorString());
        return false;
    }
    return true;
}

struct Cue
{
    /* SRT/VTT: the text lines [first, last); ASS: the Dialogue line */
    qsizetype first{0};
    qsizetype last{0};

    /* ASS: the Dialogue line up to and including the comma before Text */
    QString assHead;

    double start{0};
    QString raw;
};

QList<Cue> findSrtCues(const QStringList &lines)
{
    static const QRegularExpression timing{
        "^\\s*((?:\\d+:)?\\d{1,2}:\\d{1,2}[.,]\\d{1,3})\\s*-->"
    };

    QList<Cue> cues;
    for (qsizetype i = 0; i < lines.size(); ++i)
    {
        const QRegularExpressionMatch m = timing.match(lines[i]);
        if (!m.hasMatch())
        {
            continue;
        }
        std::optional<double> start = parseTimecode(m.captured(1));
        if (!start)
        {
            continue;
        }
        Cue cue;
        cue.start = *start;
        cue.first = i + 1;
        cue.last = cue.first;
        while (cue.last < lines.size() && !lines[cue.last].trimmed().isEmpty())
        {
            ++cue.last;
        }
        cue.raw = lines.mid(cue.first, cue.last - cue.first).join('\n');
        cues << cue;
        i = cue.last;
    }
    return cues;
}

QList<Cue> findAssCues(const QStringList &lines)
{
    QList<Cue> cues;
    bool inEvents = false;
    qsizetype fieldCount = 10;
    qsizetype startIndex = 1;

    for (qsizetype i = 0; i < lines.size(); ++i)
    {
        const QString line = lines[i].trimmed();
        if (line.startsWith('['))
        {
            inEvents = line.compare("[Events]", Qt::CaseInsensitive) == 0;
            continue;
        }
        if (!inEvents)
        {
            continue;
        }
        if (line.startsWith("Format:", Qt::CaseInsensitive))
        {
            QStringList fields = line.mid(7).split(',');
            for (QString &f : fields)
            {
                f = f.trimmed();
            }
            fieldCount = fields.size();
            startIndex = fields.indexOf("Start", 0);
            if (startIndex < 0)
            {
                startIndex = 1;
            }
            continue;
        }
        if (!line.startsWith("Dialogue:", Qt::CaseInsensitive))
        {
            continue;
        }

        /* The Text field is last and may itself contain commas */
        const QString &orig = lines[i];
        const qsizetype colon = orig.indexOf(':');
        qsizetype pos = colon;
        QList<qsizetype> commas;
        while (commas.size() < fieldCount - 1)
        {
            pos = orig.indexOf(',', pos + 1);
            if (pos < 0)
            {
                break;
            }
            commas << pos;
        }
        if (commas.size() < fieldCount - 1 || startIndex >= commas.size())
        {
            continue;
        }

        const qsizetype startBegin = startIndex == 0 ? colon + 1 : commas[startIndex - 1] + 1;
        std::optional<double> start = parseTimecode(
            orig.mid(startBegin, commas[startIndex] - startBegin));
        if (!start)
        {
            continue;
        }

        Cue cue;
        cue.first = i;
        cue.last = i + 1;
        cue.start = *start;
        cue.assHead = orig.left(commas.back() + 1);
        cue.raw = orig.mid(commas.back() + 1);
        cues << cue;
    }
    return cues;
}

/**
 * Rewrites the cue matching req in a text subtitle file.
 */
bool editTextSubtitle(
    const QString &path, Format format, const EditRequest &req, QString &error)
{
    TextFile file;
    if (!readTextFile(path, file, error))
    {
        return false;
    }

    const QList<Cue> cues = format == Format::Ass ?
        findAssCues(file.lines) : findSrtCues(file.lines);

    const QString wanted = compareKey(req.oldText);
    const Cue *best = nullptr;
    for (const Cue &cue : cues)
    {
        const double drift = std::abs(cue.start - req.fileStart);
        if (drift > START_TOLERANCE)
        {
            continue;
        }
        if (compareKey(plainText(cue.raw, format)) != wanted)
        {
            continue;
        }
        if (best == nullptr || drift < std::abs(best->start - req.fileStart))
        {
            best = &cue;
        }
    }
    if (best == nullptr)
    {
        error = QObject::tr("Could not find this subtitle in %1")
            .arg(QFileInfo(path).fileName());
        return false;
    }

    const QString raw = rebuildRaw(best->raw, req.newText, format);
    if (format == Format::Ass)
    {
        file.lines[best->first] = best->assHead + raw;
    }
    else
    {
        file.lines.remove(best->first, best->last - best->first);
        const QStringList newLines = raw.split('\n');
        for (qsizetype i = 0; i < newLines.size(); ++i)
        {
            file.lines.insert(best->first + i, newLines[i]);
        }
    }

    return writeTextFile(path, file, error);
}

std::optional<Format> formatForSuffix(const QString &suffix)
{
    const QString s = suffix.toLower();
    if (s == "srt")
    {
        return Format::Srt;
    }
    if (s == "vtt" || s == "webvtt")
    {
        return Format::Vtt;
    }
    if (s == "ass" || s == "ssa")
    {
        return Format::Ass;
    }
    return std::nullopt;
}

bool isMatroska(const QString &path)
{
    static const QStringList suffixes{"mkv", "mka", "mks", "mk3d", "webm"};
    return suffixes.contains(QFileInfo(path).suffix().toLower());
}

/**
 * Runs a mkvtoolnix tool to completion. Exit code 1 is "warnings only".
 *
 * @param output   If set, receives stdout (used for JSON identification).
 * @param progress If set, the tool runs in --gui-mode and its progress lines
 *                 are reported as 0–1.
 */
bool runTool(
    const QString &program,
    QStringList args,
    QByteArray *output,
    QString &error,
    const std::function<void(double)> &progress = {})
{
    if (progress)
    {
        args.prepend("--gui-mode");
    }

    QProcess proc;
    proc.setProcessChannelMode(
        output ? QProcess::SeparateChannels : QProcess::MergedChannels);
    proc.start(program, args);
    if (!proc.waitForStarted())
    {
        error = QObject::tr("%1 is not installed (mkvtoolnix)").arg(program);
        return false;
    }

    QByteArray collected;
    QByteArray pending;
    QString lastLine;
    auto consume = [&] (const QByteArray &chunk) {
        if (output)
        {
            collected += chunk;
            return;
        }
        pending += chunk;
        qsizetype cut;
        while ((cut = pending.indexOf('\n')) >= 0 || (cut = pending.indexOf('\r')) >= 0)
        {
            const QString line = QString::fromUtf8(pending.left(cut)).trimmed();
            pending.remove(0, cut + 1);
            static const QRegularExpression progressRe{"^#GUI#progress\\s+(\\d+)%"};
            const QRegularExpressionMatch m = progressRe.match(line);
            if (m.hasMatch())
            {
                if (progress)
                {
                    progress(m.captured(1).toDouble() / 100.0);
                }
            }
            else if (!line.isEmpty())
            {
                lastLine = line;
            }
        }
    };

    while (proc.state() != QProcess::NotRunning)
    {
        proc.waitForReadyRead(200);
        consume(proc.readAllStandardOutput());
    }
    consume(proc.readAllStandardOutput());
    consume("\n");

    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() > 1)
    {
        QString detail = lastLine;
        if (output)
        {
            const QStringList lines = QString::fromUtf8(
                proc.readAllStandardError() + collected).trimmed().split('\n');
            detail = lines.isEmpty() ? QString() : lines.back().trimmed();
        }
        static const QRegularExpression guiPrefix{"^#GUI#\\w+\\s*"};
        detail.remove(guiPrefix);
        error = QObject::tr("%1 failed: %2")
            .arg(program, detail.isEmpty() ? QString::number(proc.exitCode()) : detail);
        return false;
    }
    if (output)
    {
        *output = collected;
    }
    return true;
}

EditResult editMatroska(const EditRequest &req, const Progress &progress)
{
    EditResult result;
    QString &error = result.message;

    const QString path = QFileInfo(req.path).canonicalFilePath();
    if (path.isEmpty())
    {
        error = QObject::tr("Cannot find %1").arg(req.path);
        return result;
    }

    /* Identify the track mpv is showing */
    QByteArray json;
    if (!runTool("mkvmerge", {"-J", path}, &json, error))
    {
        return result;
    }
    const QJsonObject info = QJsonDocument::fromJson(json).object();
    if (info["container"].toObject()["type"].toString() != "Matroska")
    {
        error = QObject::tr("Not a Matroska file: %1").arg(QFileInfo(path).fileName());
        return result;
    }

    const QJsonArray tracks = info["tracks"].toArray();
    QJsonObject track;
    for (const QJsonValue &v : tracks)
    {
        const QJsonObject t = v.toObject();
        if (t["type"].toString() == "subtitles" &&
            t["properties"].toObject()["number"].toInteger() == req.srcId)
        {
            track = t;
            break;
        }
    }
    if (track.isEmpty())
    {
        error = QObject::tr("Cannot find subtitle track %1 in the file").arg(req.srcId);
        return result;
    }
    const int64_t trackId = track["id"].toInteger();
    const QJsonObject props = track["properties"].toObject();
    const QString codecId = props["codec_id"].toString();

    Format format;
    QString suffix;
    if (codecId == "S_TEXT/UTF8")
    {
        format = Format::Srt;
        suffix = "srt";
    }
    else if (codecId == "S_TEXT/ASS")
    {
        format = Format::Ass;
        suffix = "ass";
    }
    else if (codecId == "S_TEXT/SSA")
    {
        format = Format::Ass;
        suffix = "ssa";
    }
    else if (codecId == "S_TEXT/WEBVTT")
    {
        format = Format::Vtt;
        suffix = "vtt";
    }
    else
    {
        error = QObject::tr("Subtitle codec %1 cannot be edited").arg(codecId);
        return result;
    }

    /* Room for the new file beside the original */
    const QFileInfo fileInfo(path);
    const QStorageInfo storage(fileInfo.absolutePath());
    if (storage.isValid() && storage.bytesAvailable() < fileInfo.size() + (64 << 20))
    {
        error = QObject::tr("Not enough free space to write a new %1").arg(fileInfo.fileName());
        return result;
    }

    QTemporaryDir tempDir;
    if (!tempDir.isValid())
    {
        error = QObject::tr("Cannot create a temporary directory");
        return result;
    }
    const QString subPath = tempDir.filePath("track." + suffix);

    progress(0, 0);
    if (!runTool(
            "mkvextract",
            {path, "tracks", QString("%1:%2").arg(trackId).arg(subPath)},
            nullptr, error,
            [&progress] (double f) { progress(0, f); }))
    {
        return result;
    }
    if (!editTextSubtitle(subPath, format, req, error))
    {
        return result;
    }

    /* Mux: every track of the original except this one, plus the whole
     * edited stream in its place, with the same flags */
    QStringList args;
    const QString outPath = QDir(fileInfo.absolutePath()).filePath(
        QString(".%1.yosuga-edit-%2.%3")
            .arg(fileInfo.completeBaseName())
            .arg(QUuid::createUuid().toString(QUuid::Id128).left(8))
            .arg(fileInfo.suffix()));
    args << "-o" << outPath;
    args << "--subtitle-tracks" << QString("!%1").arg(trackId) << path;

    const QString language = props.contains("language_ietf") ?
        props["language_ietf"].toString() : props["language"].toString();
    if (!language.isEmpty())
    {
        args << "--language" << "0:" + language;
    }
    if (props.contains("track_name"))
    {
        args << "--track-name" << "0:" + props["track_name"].toString();
    }
    const QList<std::pair<const char *, const char *>> flags{
        {"default_track", "--default-track-flag"},
        {"forced_track", "--forced-display-flag"},
        {"enabled_track", "--track-enabled-flag"},
        {"flag_hearing_impaired", "--hearing-impaired-flag"},
        {"flag_visual_impaired", "--visual-impaired-flag"},
        {"flag_text_descriptions", "--text-descriptions-flag"},
        {"flag_original", "--original-flag"},
        {"flag_commentary", "--commentary-flag"},
    };
    for (const auto &[key, option] : flags)
    {
        if (props.contains(key))
        {
            args << option << QString("0:%1").arg(props[key].toBool() ? 1 : 0);
        }
    }
    args << "--sub-charset" << "0:UTF-8" << subPath;

    QStringList order;
    for (const QJsonValue &v : tracks)
    {
        const int64_t id = v.toObject()["id"].toInteger();
        order << (id == trackId ? QString("1:0") : QString("0:%1").arg(id));
    }
    args << "--track-order" << order.join(',');

    progress(1, 0);
    if (!runTool("mkvmerge", args, nullptr, error,
                 [&progress] (double f) { progress(1, f); }))
    {
        QFile::remove(outPath);
        return result;
    }

    QFile::setPermissions(outPath, QFile::permissions(path));
    if (std::rename(QFile::encodeName(outPath).constData(),
                    QFile::encodeName(path).constData()) != 0)
    {
        QFile::remove(outPath);
        error = QObject::tr("Cannot replace %1").arg(fileInfo.fileName());
        return result;
    }

    result.ok = true;
    result.message = fileInfo.fileName();
    return result;
}

EditResult performEdit(const EditRequest &req, const Progress &progress)
{
    if (req.matroska)
    {
        return editMatroska(req, progress);
    }

    EditResult result;
    std::optional<Format> format = formatForSuffix(QFileInfo(req.path).suffix());
    if (!format)
    {
        result.message = QObject::tr("Cannot edit %1 subtitles")
            .arg(QFileInfo(req.path).suffix());
        return result;
    }
    progress(1, -1);
    result.ok = editTextSubtitle(req.path, *format, req, result.message);
    if (result.ok)
    {
        result.message = QFileInfo(req.path).fileName();
    }
    return result;
}

} // namespace

SubtitleEditor::SubtitleEditor(QObject *parent) : QObject(parent)
{
    m_pool.setMaxThreadCount(1);

    m_listRestoreTimer.setSingleShot(true);
    m_listRestoreTimer.setInterval(3000);
    connect(
        &m_listRestoreTimer, &QTimer::timeout,
        this, &SubtitleEditor::stopListRestore
    );
}

SubtitleEditor::~SubtitleEditor()
{
    /* A remux in flight must finish, or its partial file is left behind */
    m_pool.waitForDone();
}

MpvPlayer *SubtitleEditor::player() const noexcept
{
    return m_player;
}

void SubtitleEditor::setPlayer(MpvPlayer *player)
{
    if (m_player == player)
    {
        return;
    }
    if (m_player)
    {
        disconnect(m_player, nullptr, this, nullptr);
    }
    m_player = player;
    if (m_player)
    {
        /* Queued, and connected after PlayerManager's own fileLoaded
         * handlers, so the restore runs last and overrides the default
         * secondary subtitle choice */
        connect(
            m_player, &MpvPlayer::fileLoaded,
            this, &SubtitleEditor::handleFileLoaded,
            Qt::QueuedConnection
        );
    }
    emit playerChanged();
}

bool SubtitleEditor::busy() const noexcept
{
    return m_busy;
}

bool SubtitleEditor::reloading() const noexcept
{
    return m_reloading;
}

const QString &SubtitleEditor::stage() const noexcept
{
    return m_stage;
}

double SubtitleEditor::progress() const noexcept
{
    return m_progress;
}

void SubtitleEditor::setStage(const QString &stage, double progress)
{
    if (m_stage != stage)
    {
        m_stage = stage;
        emit stageChanged();
    }
    if (m_progress != progress)
    {
        m_progress = progress;
        emit progressChanged();
    }
}

void SubtitleEditor::setBusy(bool busy)
{
    if (m_busy != busy)
    {
        m_busy = busy;
        emit busyChanged();
    }
}

void SubtitleEditor::setReloading(bool reloading)
{
    if (m_reloading != reloading)
    {
        m_reloading = reloading;
        emit reloadingChanged();
    }
}

bool SubtitleEditor::save(
    const QString &oldText,
    double start,
    double end,
    double delay,
    QString newText,
    bool resume)
{
    Q_UNUSED(end);

    if (!m_player || m_busy)
    {
        return false;
    }

    auto refuse = [this, resume] (const QString &message) {
        if (resume && m_player)
        {
            m_player->controller()->play();
        }
        emit failed(message);
        return false;
    };

    newText.replace("\r\n", "\n");
    if (newText == oldText)
    {
        if (resume)
        {
            m_player->controller()->play();
        }
        return false;
    }
    if (newText.trimmed().isEmpty())
    {
        return refuse(tr("The subtitle text is empty."));
    }

    MpvState *state = m_player->state();
    const MpvTrack *track = nullptr;
    for (const MpvTrack *t : state->subtitleTracks())
    {
        if (t->id() == state->sid())
        {
            track = t;
            break;
        }
    }
    if (track == nullptr)
    {
        return refuse(tr("No subtitle track is selected."));
    }

    EditRequest req;
    req.fileStart = start - delay;
    req.oldText = oldText;
    req.newText = newText;
    req.srcId = track->sourceId();
    if (track->external())
    {
        req.path = track->externalFilename();
        req.matroska = isMatroska(req.path);
        if (!req.matroska && !formatForSuffix(QFileInfo(req.path).suffix()))
        {
            return refuse(tr("%1 subtitles cannot be edited.")
                .arg(QFileInfo(req.path).suffix()));
        }
    }
    else
    {
        req.path = state->path();
        req.matroska = true;
        if (!isMatroska(req.path))
        {
            return refuse(tr("Embedded subtitles can only be edited in "
                             "Matroska files."));
        }
    }
    if (!QFileInfo(req.path).isFile())
    {
        return refuse(tr("%1 is not a local file.").arg(req.path));
    }

    m_editStart = start;
    m_editDelay = delay;
    m_editOld = oldText;
    m_editNew = newText;
    m_resume = resume;

    const QString name = QFileInfo(req.path).fileName();
    setBusy(true);
    setStage(tr("Saving %1…").arg(name), -1);

    /* Called on the worker thread */
    QPointer<SubtitleEditor> self = this;
    Progress progress = [self, name, matroska = req.matroska] (int stage, double f) {
        QMetaObject::invokeMethod(
            self.data(),
            [self, name, matroska, stage, f] {
                if (!self)
                {
                    return;
                }
                if (!matroska)
                {
                    self->setStage(tr("Writing %1…").arg(name), -1);
                }
                else if (stage == 0)
                {
                    self->setStage(tr("Reading the subtitle track from %1…").arg(name),
                                   0.3 * f);
                }
                else
                {
                    self->setStage(tr("Writing the new %1…").arg(name),
                                   0.3 + 0.7 * f);
                }
            },
            Qt::QueuedConnection
        );
    };

    QtConcurrent::run(&m_pool, performEdit, req, progress).then(
        this,
        [this] (EditResult result) {
            handleSaveFinished(result.ok, result.message);
        }
    );
    return true;
}

void SubtitleEditor::handleSaveFinished(bool ok, const QString &message)
{
    if (!ok)
    {
        setBusy(false);
        setStage({}, -1);
        if (m_resume && m_player)
        {
            m_player->controller()->play();
        }
        emit failed(message);
        return;
    }
    startReload(message);
}

SubtitleEditor::TrackKey SubtitleEditor::keyFor(
    const QList<MpvTrack *> &tracks, int64_t id) const
{
    TrackKey key;
    if (id <= 0)
    {
        return key;
    }
    for (const MpvTrack *t : tracks)
    {
        if (t->id() == id)
        {
            key.valid = true;
            key.external = t->external();
            key.externalFilename = t->externalFilename();
            key.sourceId = t->sourceId();
            break;
        }
    }
    return key;
}

int64_t SubtitleEditor::idFor(
    const QList<MpvTrack *> &tracks, const TrackKey &key) const
{
    if (!key.valid)
    {
        return 0;
    }
    for (const MpvTrack *t : tracks)
    {
        if (key.external ?
                (t->external() && t->externalFilename() == key.externalFilename) :
                (!t->external() && t->sourceId() == key.sourceId))
        {
            return t->id();
        }
    }
    return 0;
}

void SubtitleEditor::startReload(const QString &message)
{
    if (!m_player)
    {
        finish(message);
        return;
    }

    MpvState *state = m_player->state();
    MpvController *controller = m_player->controller();

    stopListRestore();
    m_reload = ReloadState{};
    m_reload.message = message;
    m_reload.resume = m_resume;
    m_reload.position = state->timePosition();
    bool ok = false;
    const double pos = controller->propertyString("time-pos").toDouble(&ok);
    if (ok)
    {
        m_reload.position = pos;
    }

    m_reload.aid = keyFor(state->audioTracks(), state->aid());
    m_reload.vid = keyFor(state->videoTracks(), state->vid());
    m_reload.sid = keyFor(state->subtitleTracks(), state->sid());
    m_reload.secondarySid = keyFor(state->subtitleTracks(), state->secondarySid());
    for (const MpvTrack *t : state->subtitleTracks())
    {
        if (t->external())
        {
            m_reload.externalSubtitles << t->externalFilename();
        }
    }

    if (m_lists)
    {
        if (m_lists->primary() && m_reload.sid.valid && !m_reload.sid.external)
        {
            m_reload.restorePrimaryList = true;
            m_reload.primaryList = m_lists->primary()->items();
            /* The list shows the edit too */
            constexpr double TIME_DELTA = 0.05;
            for (SubtitleEntry &entry : m_reload.primaryList)
            {
                const bool atStart =
                    std::abs(entry.start - m_editStart) < TIME_DELTA ||
                    std::abs(entry.start - (m_editStart - m_editDelay)) < TIME_DELTA;
                if (atStart && entry.text == m_editOld)
                {
                    entry.text = m_editNew;
                }
            }
        }
        if (m_lists->secondary() && m_reload.secondarySid.valid &&
            !m_reload.secondarySid.external)
        {
            m_reload.restoreSecondaryList = true;
            m_reload.secondaryList = m_lists->secondary()->items();
        }
    }

    setStage(tr("Reloading…"), -1);
    setReloading(true);

    /* Reopen the same playlist entry at the same spot: the playlist, its
     * position and the window stay as they are */
    m_reload.previousStart = controller->propertyString("start");
    controller->setPropertyString("start", QString::number(m_reload.position, 'f', 3));
    if (!controller->command({"playlist-play-index", "current"}))
    {
        controller->setPropertyString(
            "start", m_reload.previousStart.isEmpty() ? "none" : m_reload.previousStart);
        setReloading(false);
        finish(message);
    }
}

void SubtitleEditor::handleFileLoaded()
{
    if (!m_reloading || !m_player)
    {
        return;
    }

    MpvState *state = m_player->state();
    MpvController *controller = m_player->controller();

    controller->setPropertyString(
        "start", m_reload.previousStart.isEmpty() ? "none" : m_reload.previousStart);

    /* mpv auto-loads only matching external subtitles; re-add the others in
     * their old order. Track ids are assigned sequentially per type. */
    QSet<QString> present;
    int64_t nextSubId = 1;
    for (const MpvTrack *t : state->subtitleTracks())
    {
        if (t->external())
        {
            present.insert(t->externalFilename());
        }
        nextSubId = std::max(nextSubId, t->id() + 1);
    }
    QHash<QString, int64_t> added;
    for (const QString &file : m_reload.externalSubtitles)
    {
        if (present.contains(file) || added.contains(file))
        {
            continue;
        }
        if (controller->command({"sub-add", file, "auto"}))
        {
            added.insert(file, nextSubId++);
        }
    }
    auto subId = [&] (const TrackKey &key) -> int64_t {
        if (key.valid && key.external && added.contains(key.externalFilename))
        {
            return added.value(key.externalFilename);
        }
        return idFor(state->subtitleTracks(), key);
    };

    const int64_t aid = idFor(state->audioTracks(), m_reload.aid);
    const int64_t vid = idFor(state->videoTracks(), m_reload.vid);
    m_reload.newSid = subId(m_reload.sid);
    m_reload.newSecondarySid = subId(m_reload.secondarySid);

    if (aid > 0)
    {
        controller->setAid(aid);
    }
    if (vid > 0)
    {
        controller->setVid(vid);
    }
    /* mpv refuses one track in both slots: clear the secondary first */
    controller->setSecondarySid(0);
    controller->setSid(m_reload.newSid);
    controller->setSecondarySid(m_reload.newSecondarySid);

    /* A watch-later entry could have overridden the start position */
    bool ok = false;
    const double pos = controller->propertyString("time-pos").toDouble(&ok);
    if (!ok || std::abs(pos - m_reload.position) > 0.25)
    {
        controller->command({
            "seek", QString::number(m_reload.position, 'f', 3), "absolute+exact"
        });
    }

    if (m_reload.resume)
    {
        controller->play();
    }
    else
    {
        controller->pause();
    }

    setReloading(false);

    /* The lists follow the track selection as mpv reports it back */
    if (m_lists && (m_reload.restorePrimaryList || m_reload.restoreSecondaryList))
    {
        m_listRestoreConnections << connect(
            state, &MpvState::sidChanged, this, &SubtitleEditor::restoreLists,
            Qt::QueuedConnection);
        m_listRestoreConnections << connect(
            state, &MpvState::secondarySidChanged, this, &SubtitleEditor::restoreLists,
            Qt::QueuedConnection);
        m_listRestoreConnections << connect(
            state, &MpvState::subtitleTracksChanged, this, &SubtitleEditor::restoreLists,
            Qt::QueuedConnection);
        m_listRestoreConnections << connect(
            m_lists.data(), &SubtitleLists::primaryChanged, this, &SubtitleEditor::restoreLists,
            Qt::QueuedConnection);
        m_listRestoreConnections << connect(
            m_lists.data(), &SubtitleLists::secondaryChanged, this, &SubtitleEditor::restoreLists,
            Qt::QueuedConnection);
        m_listRestoreTimer.start();
        restoreLists();
    }

    finish(m_reload.message);
}

void SubtitleEditor::restoreLists()
{
    if (!m_player || !m_lists)
    {
        stopListRestore();
        return;
    }
    MpvState *state = m_player->state();

    /* Idempotent (addSubtitle skips entries already present): it runs again
     * whenever mpv's late track-list or selection reports rebuild the lists */
    if (m_reload.restorePrimaryList && m_lists->primary() &&
        state->sid() == m_reload.newSid)
    {
        for (const SubtitleEntry &e : m_reload.primaryList)
        {
            m_lists->primary()->addSubtitle(e.text, e.start, e.end);
        }
    }
    if (m_reload.restoreSecondaryList && m_lists->secondary() &&
        state->secondarySid() == m_reload.newSecondarySid)
    {
        for (const SubtitleEntry &e : m_reload.secondaryList)
        {
            m_lists->secondary()->addSubtitle(e.text, e.start, e.end);
        }
    }
}

void SubtitleEditor::stopListRestore()
{
    m_listRestoreTimer.stop();
    m_reload.restorePrimaryList = false;
    m_reload.primaryList.clear();
    m_reload.restoreSecondaryList = false;
    m_reload.secondaryList.clear();
    for (const QMetaObject::Connection &c : m_listRestoreConnections)
    {
        disconnect(c);
    }
    m_listRestoreConnections.clear();
}

void SubtitleEditor::finish(const QString &message)
{
    setBusy(false);
    setStage({}, -1);
    if (m_player)
    {
        m_player->controller()->showText(tr("Subtitle saved: %1").arg(message));
    }
    emit finished(message);
}
