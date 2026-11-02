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

#include "subtitle/reviewsession.h"

#include <algorithm>

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QtConcurrent>

#include <mpv/client.h>

#include "subtitle/mkvtools.h"
#include "util/directoryutils.h"

namespace
{

const QString REVIEW_SUFFIX = QStringLiteral(".possible-ja-CORRECTIONS-review.srt");
const QString WORKING_SUFFIX = QStringLiteral(".ja-whisper-working.srt");
const QString TOOL_TAG = QStringLiteral("tag_shiroikuma_subtitles");

/* Seconds before a cue's start that next/previous land on, at most */
constexpr double LEAD_IN = 0.25;

/* Landing this far after the end of an earlier primary line */
constexpr double LANDING_GAP = 0.005;

/* A sub-skip interval no gap reaches: the script never skips in this mode */
const QString NO_SKIP_INTERVAL = QStringLiteral("1000000");

QList<ReviewSession::Cue> parseSrt(const QByteArray &data)
{
    static const QRegularExpression timeRe{
        "^\\s*(\\d+):(\\d{1,2}):(\\d{1,2})[,.](\\d{1,3})\\s*-->\\s*"
        "(\\d+):(\\d{1,2}):(\\d{1,2})[,.](\\d{1,3})"
    };
    auto seconds = [] (const QRegularExpressionMatch &m, int first) {
        return m.captured(first).toDouble() * 3600 +
            m.captured(first + 1).toDouble() * 60 +
            m.captured(first + 2).toDouble() +
            m.captured(first + 3).leftJustified(3, '0').toDouble() / 1000.0;
    };

    QString text = QString::fromUtf8(data);
    if (text.startsWith(QChar(0xFEFF)))
    {
        text.remove(0, 1);
    }
    text.replace("\r\n", "\n");
    text.replace('\r', '\n');
    const QStringList lines = text.split('\n');

    QList<ReviewSession::Cue> cues;
    for (qsizetype i = 0; i < lines.size(); ++i)
    {
        const QRegularExpressionMatch m = timeRe.match(lines[i]);
        if (!m.hasMatch())
        {
            continue;
        }
        ReviewSession::Cue cue;
        cue.start = seconds(m, 1);
        cue.end = seconds(m, 5);
        QStringList body;
        while (i + 1 < lines.size() && !lines[i + 1].trimmed().isEmpty())
        {
            body << lines[++i];
        }
        cue.text = body.join('\n');
        cues << cue;
    }
    std::stable_sort(cues.begin(), cues.end(),
        [] (const ReviewSession::Cue &a, const ReviewSession::Cue &b) {
            return a.start < b.start;
        });
    return cues;
}

QString sha256Hex(const QByteArray &data)
{
    return QString::fromLatin1(
        QCryptographicHash::hash(data, QCryptographicHash::Sha256).toHex());
}

bool readFile(const QString &path, QByteArray &out)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
    {
        return false;
    }
    out = file.readAll();
    return true;
}

/* The film's video file for a review SRT: <base>.mkv, else any Matroska
 * file with that base name */
QString filmForReview(const QString &review)
{
    const QString base = review.left(review.size() - REVIEW_SUFFIX.size());
    if (QFileInfo(base + ".mkv").isFile())
    {
        return base + ".mkv";
    }
    const QFileInfo baseInfo(base);
    const QDir dir = baseInfo.absoluteDir();
    for (const QString &name : dir.entryList(QDir::Files))
    {
        const QString path = dir.filePath(name);
        if (QFileInfo(path).completeBaseName() == baseInfo.fileName() &&
            MkvTools::isMatroska(path))
        {
            return path;
        }
    }
    return {};
}

/* sub-skip's own minimum interval, to put back after the mode */
QString subSkipInterval()
{
    QFile conf(QDir(DirectoryUtils::getConfigDir()).filePath("script-opts/sub_skip.conf"));
    if (conf.open(QIODevice::ReadOnly | QIODevice::Text))
    {
        static const QRegularExpression re{"^\\s*min_skip_interval\\s*=\\s*([0-9.]+)\\s*$"};
        while (!conf.atEnd())
        {
            const QRegularExpressionMatch m =
                re.match(QString::fromUtf8(conf.readLine()).trimmed());
            if (m.hasMatch())
            {
                return m.captured(1);
            }
        }
    }
    return QStringLiteral("3");
}

void setSubSkipInterval(mpv_handle *mpv, const QString &value)
{
    const QByteArray entry = ("sub_skip-min_skip_interval=" + value).toUtf8();
    const char *args[]{"change-list", "script-opts", "append", entry.constData(), nullptr};
    mpv_command_async(mpv, 0, args);
}

} // namespace

ReviewSession::ReviewSession(QObject *parent) : QObject(parent)
{
    m_pool.setMaxThreadCount(1);
}

ReviewSession::~ReviewSession()
{
    m_pool.waitForDone();
}

MpvPlayer *ReviewSession::player() const noexcept
{
    return m_player;
}

void ReviewSession::setPlayer(MpvPlayer *player)
{
    if (m_player == player)
    {
        return;
    }
    if (m_player)
    {
        disconnect(m_player->state(), nullptr, this, nullptr);
    }
    m_player = player;
    if (m_player)
    {
        connect(
            m_player->state(), &MpvState::timePositionChanged,
            this, &ReviewSession::handlePosition
        );
        connect(
            m_player, &MpvPlayer::fileLoaded,
            this, &ReviewSession::dropCorrectionFiles
        );
    }
    emit playerChanged();
}

bool ReviewSession::active() const noexcept { return m_active; }
bool ReviewSession::busy() const noexcept { return m_busy; }
const QString &ReviewSession::stage() const noexcept { return m_stage; }
double ReviewSession::progress() const noexcept { return m_progress; }
int ReviewSession::count() const noexcept { return m_cues.size(); }
int ReviewSession::current() const noexcept { return m_current; }
int ReviewSession::checkedCount() const noexcept { return m_checked.size(); }
const QString &ReviewSession::filmPath() const noexcept { return m_film; }
const QString &ReviewSession::workingPath() const noexcept { return m_working; }

bool ReviewSession::allChecked() const noexcept
{
    return m_active && m_checked.size() >= m_cues.size();
}

QString ReviewSession::note() const
{
    if (m_current < 0 || m_current >= m_cues.size())
    {
        return {};
    }
    return m_cues[m_current].text;
}

QString ReviewSession::statePath() const
{
    return QDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation))
        .filePath("shiroikuma-yosuga/review/" +
                  QFileInfo(m_film).completeBaseName() + ".json");
}

void ReviewSession::setBusy(bool busy, const QString &stage, double progress)
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
    if (m_busy != busy)
    {
        m_busy = busy;
        emit busyChanged();
    }
}

void ReviewSession::setActive(bool active)
{
    if (m_active == active)
    {
        return;
    }
    m_active = active;
    emit activeChanged();
    emit checkedChanged();
}

bool ReviewSession::startFromArguments(const QStringList &args)
{
    for (qsizetype i = 1; i < args.size(); ++i)
    {
        if (args[i].startsWith("--review="))
        {
            start(args[i].mid(QStringLiteral("--review=").size()));
            return true;
        }
        if (args[i] == "--review" && i + 1 < args.size())
        {
            start(args[i + 1]);
            return true;
        }
    }
    return false;
}

void ReviewSession::start(const QString &path)
{
    if (m_busy || m_active)
    {
        return;
    }

    const QString absolute = QFileInfo(path).absoluteFilePath();
    if (absolute.endsWith(REVIEW_SUFFIX))
    {
        m_review = absolute;
        m_film = filmForReview(absolute);
        if (m_film.isEmpty())
        {
            emit failed(tr("There is no film beside %1.")
                .arg(QFileInfo(absolute).fileName()));
            return;
        }
    }
    else
    {
        m_film = absolute;
        const QFileInfo info(absolute);
        m_review = info.absoluteDir().filePath(info.completeBaseName() + REVIEW_SUFFIX);
    }
    const QFileInfo filmInfo(m_film);
    m_working = filmInfo.absoluteDir().filePath(filmInfo.completeBaseName() + WORKING_SUFFIX);
    emit filesChanged();

    if (!QFileInfo(m_review).isFile())
    {
        /* Nothing to review: just play the film */
        emit loadRequested(m_film);
        return;
    }
    if (!MkvTools::isMatroska(m_film))
    {
        emit failed(tr("%1 is not a Matroska file; correction mode needs one.")
            .arg(filmInfo.fileName()));
        emit loadRequested(m_film);
        return;
    }

    prepare(false);
}

void ReviewSession::reextract()
{
    prepare(true);
}

void ReviewSession::abort()
{
    emit loadRequested(m_film);
}

void ReviewSession::prepare(bool forceReextract)
{
    const QString film = m_film;
    const QString review = m_review;
    const QString working = m_working;
    const QString statePath = this->statePath();
    const QString filmName = QFileInfo(film).fileName();

    setBusy(true, tr("Reading the 日本語 track from %1…").arg(filmName), -1);

    QPointer<ReviewSession> self = this;
    auto progress = [self, filmName] (double f) {
        QMetaObject::invokeMethod(self.data(), [self, filmName, f] {
            if (self)
            {
                self->setBusy(true,
                    tr("Reading the 日本語 track from %1…").arg(filmName), f);
            }
        }, Qt::QueuedConnection);
    };

    auto work = [=] () -> Prepared {
        Prepared r;
        QString &error = r.message;

        QByteArray reviewData;
        if (!readFile(review, reviewData))
        {
            error = tr("Cannot read %1.").arg(QFileInfo(review).fileName());
            return r;
        }
        r.cues = parseSrt(reviewData);

        /* The one subtitles-tool track */
        QByteArray json;
        if (!MkvTools::runTool("mkvmerge", {"-J", film}, &json, error))
        {
            return r;
        }
        QList<int64_t> toolTracks;
        for (const QJsonValue &v :
                QJsonDocument::fromJson(json).object()["tracks"].toArray())
        {
            const QJsonObject t = v.toObject();
            const QJsonObject p = t["properties"].toObject();
            const QString lang = p["language"].toString();
            const QString ietf = p["language_ietf"].toString();
            if (t["type"].toString() == "subtitles" &&
                p["codec_id"].toString() == "S_TEXT/UTF8" &&
                (lang == "jpn" || ietf == "ja" || ietf.startsWith("ja-")) &&
                p.contains(TOOL_TAG))
            {
                toolTracks << t["id"].toInteger();
            }
        }
        if (toolTracks.size() != 1)
        {
            error = toolTracks.isEmpty() ?
                tr("%1 has no track from the subtitles tool (a Japanese SubRip "
                   "track tagged SHIROIKUMA_SUBTITLES), so there is nothing to "
                   "correct.").arg(filmName) :
                tr("%1 has %2 tracks tagged SHIROIKUMA_SUBTITLES; correction "
                   "mode needs exactly one.").arg(filmName).arg(toolTracks.size());
            return r;
        }

        /* What was recorded last time */
        QString stateSha;
        QSet<int> stateChecked;
        QByteArray stateData;
        if (readFile(statePath, stateData))
        {
            const QJsonObject state = QJsonDocument::fromJson(stateData).object();
            stateSha = state["sha256"].toString();
            for (const QJsonValue &v : state["checked"].toArray())
            {
                stateChecked.insert(v.toInt());
            }
        }

        /* The track as it is now */
        QTemporaryDir tempDir;
        if (!tempDir.isValid())
        {
            error = tr("Cannot create a temporary directory.");
            return r;
        }
        const QString extracted = tempDir.filePath("track.srt");
        if (!MkvTools::runTool(
                "mkvextract",
                {film, "tracks", QString("%1:%2").arg(toolTracks.first()).arg(extracted)},
                nullptr, error, progress))
        {
            return r;
        }
        QByteArray trackData;
        if (!readFile(extracted, trackData))
        {
            error = tr("Cannot read the extracted track.");
            return r;
        }
        r.sha256 = sha256Hex(trackData);

        QByteArray workingData;
        if (!forceReextract && readFile(working, workingData))
        {
            if (!stateSha.isEmpty() && stateSha == r.sha256)
            {
                r.checked = stateChecked;
            }
            else if (stateSha.isEmpty() && sha256Hex(workingData) == r.sha256)
            {
                /* An untouched copy of the current track */
            }
            else
            {
                r.needsConfirm = true;
                error = !stateSha.isEmpty() ?
                    tr("The 日本語 track in %1 has changed since the working copy "
                       "was taken, most likely because a line was edited in normal "
                       "play.\n\nRe-extract replaces the working copy with the "
                       "current track; the corrections in the working copy are "
                       "lost. Abort leaves everything as it is and plays the film "
                       "normally.").arg(filmName) :
                    tr("%1 exists, but there is no record of which track it was "
                       "taken from.\n\nRe-extract replaces it with the film's "
                       "current 日本語 track. Abort leaves everything as it is and "
                       "plays the film normally.")
                        .arg(QFileInfo(working).fileName());
                return r;
            }
        }
        else
        {
            QSaveFile out(working);
            if (!out.open(QIODevice::WriteOnly) ||
                out.write(trackData) != trackData.size() ||
                !out.commit())
            {
                error = tr("Cannot write %1.").arg(QFileInfo(working).fileName());
                return r;
            }
            if (stateSha == r.sha256)
            {
                r.checked = stateChecked;
            }
        }

        r.ok = true;
        return r;
    };

    QtConcurrent::run(&m_pool, work).then(this, [this] (Prepared result) {
        handlePrepared(result);
    });
}

void ReviewSession::handlePrepared(const Prepared &result)
{
    setBusy(false);

    if (result.needsConfirm)
    {
        emit confirmRequested(result.message);
        return;
    }
    if (!result.ok)
    {
        emit failed(result.message);
        emit loadRequested(m_film);
        return;
    }

    m_cues = result.cues;
    m_sha256 = result.sha256;
    m_checked.clear();
    for (int i : result.checked)
    {
        if (i >= 0 && i < m_cues.size())
        {
            m_checked.insert(i);
        }
    }
    m_current = -1;
    emit cuesChanged();
    emit currentChanged();
    saveState();

    setActive(true);
    enterPlayerMode();
    emit loadRequested(m_film);
}

void ReviewSession::saveState() const
{
    if (m_film.isEmpty() || m_sha256.isEmpty())
    {
        return;
    }
    QList<int> checked(m_checked.begin(), m_checked.end());
    std::sort(checked.begin(), checked.end());
    QJsonArray checkedArray;
    for (int i : checked)
    {
        checkedArray << i;
    }
    QJsonObject state{
        {"film", m_film},
        {"review", m_review},
        {"working", m_working},
        {"sha256", m_sha256},
        {"count", static_cast<int>(m_cues.size())},
        {"checked", checkedArray},
        {"current", m_current},
    };

    const QString path = statePath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    if (file.open(QIODevice::WriteOnly))
    {
        file.write(QJsonDocument(state).toJson());
        file.commit();
    }
}

void ReviewSession::enterPlayerMode()
{
    if (!m_player || m_playerModeSet)
    {
        return;
    }
    mpv_handle *mpv = m_player->handle();

    /* The working copy and the review SRT would otherwise be auto-loaded;
     * the working copy is added by hand, the review SRT never */
    char *subAuto = mpv_get_property_string(mpv, "sub-auto");
    m_savedSubAuto = subAuto ? QString::fromUtf8(subAuto) : QString();
    mpv_free(subAuto);
    mpv_set_property_string(mpv, "sub-auto", "no");

    /* sub-skip would jump to the next Japanese line, not the next cue */
    setSubSkipInterval(mpv, NO_SKIP_INTERVAL);

    m_playerModeSet = true;
}

void ReviewSession::leavePlayerMode()
{
    if (!m_player || !m_playerModeSet)
    {
        return;
    }
    mpv_handle *mpv = m_player->handle();
    if (!m_savedSubAuto.isEmpty())
    {
        mpv_set_property_string(mpv, "sub-auto", m_savedSubAuto.toUtf8().constData());
    }
    setSubSkipInterval(mpv, subSkipInterval());
    m_playerModeSet = false;
}

void ReviewSession::handleFileLoaded(const QString &path)
{
    if (!m_active || !m_player || m_busy)
    {
        return;
    }
    /* mpv's path property can still be empty or stale when the load is
     * reported; only the path the load itself names counts */
    const QString loaded = path.isEmpty() ? m_player->state()->path() : path;
    if (!loaded.isEmpty() && QFileInfo(loaded).absoluteFilePath() != m_film)
    {
        /* Another file was opened: the mode ends without fixing */
        leavePlayerMode();
        setActive(false);
        return;
    }

    /* The working copy is the primary subtitle */
    int64_t workingId = -1;
    for (const MpvTrack *t : m_player->state()->subtitleTracks())
    {
        if (t->external() &&
            QFileInfo(t->externalFilename()).absoluteFilePath() == m_working)
        {
            workingId = t->id();
            break;
        }
    }
    if (workingId >= 0)
    {
        m_player->controller()->setSid(workingId);
    }
    else
    {
        m_player->controller()->loadSubtitle(m_working);
    }

    int first = -1;
    for (int i = 0; i < m_cues.size(); ++i)
    {
        if (!m_checked.contains(i))
        {
            first = i;
            break;
        }
    }
    if (first < 0)
    {
        first = m_current >= 0 ? m_current : 0;
    }
    goTo(first);
}

void ReviewSession::dropCorrectionFiles()
{
    /* Correction mode adds its working copy itself, and never the review
     * SRT; this is for normal play, where sub-auto=fuzzy loads both and mpv
     * prefers them (external tracks) over the film's own 日本語 track */
    if (m_active || !m_player)
    {
        return;
    }
    mpv_handle *mpv = m_player->handle();

    QList<int64_t> drop;
    bool primaryDropped = false;
    const MpvTrack *japanese = nullptr;
    for (const MpvTrack *t : m_player->state()->subtitleTracks())
    {
        const QString name = t->externalFilename();
        if (t->external() &&
            (name.endsWith(REVIEW_SUFFIX) || name.endsWith(WORKING_SUFFIX)))
        {
            drop << t->id();
            if (t->selected() && t->mainSelection() == 0)
            {
                primaryDropped = true;
            }
            continue;
        }
        const QString lang = t->language();
        if (!t->external() &&
            (lang == "ja" || lang == "jpn" || lang.startsWith("ja-")) &&
            (japanese == nullptr ||
             (japanese->title() != "日本語" && t->title() == "日本語")))
        {
            japanese = t;
        }
    }
    if (drop.isEmpty())
    {
        return;
    }

    if (primaryDropped)
    {
        int64_t sid = japanese ? japanese->id() : 0;
        if (sid > 0)
        {
            mpv_set_property(mpv, "sid", MPV_FORMAT_INT64, &sid);
        }
        else
        {
            mpv_set_property_string(mpv, "sid", "no");
        }
    }
    for (int64_t id : drop)
    {
        const QByteArray idStr = QByteArray::number(id);
        const char *args[]{"sub-remove", idStr.constData(), nullptr};
        mpv_command(mpv, args);
    }
}

void ReviewSession::next()
{
    goTo(m_current + 1);
}

void ReviewSession::previous()
{
    goTo(m_current - 1);
}

double ReviewSession::landingFor(int index) const
{
    const double start = m_cues[index].start;
    double target = std::max(0.0, start - LEAD_IN);

    /* Never land inside an earlier primary line: sub-pause.lua would pause
     * at its end and the counter would read the previous cue. Land just
     * after the last such line instead (at the cue start if lines touch). */
    QByteArray data;
    if (m_player && readFile(m_working, data))
    {
        const double delay = m_player->state()->subtitle()->delay();
        for (const Cue &line : parseSrt(data))
        {
            const double lineStart = line.start + delay;
            const double lineEnd = line.end + delay;
            if (lineStart < start - 0.001 && lineEnd > target)
            {
                target = std::max(target, lineEnd + LANDING_GAP);
            }
        }
    }
    return std::min(target, start);
}

void ReviewSession::goTo(int index)
{
    if (!m_active || !m_player || m_cues.isEmpty())
    {
        return;
    }
    index = std::clamp(index, 0, static_cast<int>(m_cues.size()) - 1);

    /* The counter follows the button, not the position: until playback
     * reaches this cue, positions short of it must not pull it back */
    const double landing = landingFor(index);
    m_navTarget = index;
    m_navLanding = landing;
    if (m_current != index)
    {
        m_current = index;
        emit currentChanged();
        saveState();
    }
    m_player->controller()->seek(landing);
    m_player->controller()->play();
}

void ReviewSession::handlePosition(double position)
{
    if (!m_active || m_busy)
    {
        return;
    }
    if (m_navTarget >= 0 && m_navTarget < m_cues.size())
    {
        const Cue &target = m_cues[m_navTarget];
        if (position >= target.start - 0.001 && position <= target.end + 0.001)
        {
            m_navTarget = -1;
        }
        else if (position >= m_navLanding - 1.0 && position < target.start)
        {
            /* On the way to the cue (or a position from before the seek) */
            return;
        }
        else
        {
            /* Seeked elsewhere */
            m_navTarget = -1;
        }
    }
    for (int i = 0; i < m_cues.size(); ++i)
    {
        if (m_cues[i].start <= position && position <= m_cues[i].end)
        {
            bool changed = false;
            if (m_current != i)
            {
                m_current = i;
                emit currentChanged();
                changed = true;
            }
            if (!m_checked.contains(i))
            {
                m_checked.insert(i);
                emit checkedChanged();
                changed = true;
            }
            if (changed)
            {
                saveState();
            }
            return;
        }
    }
}

void ReviewSession::fixMkv()
{
    if (!m_active || m_busy || !allChecked() || !m_player)
    {
        return;
    }

    QString program = QStandardPaths::findExecutable("subtitles");
    if (program.isEmpty())
    {
        const QString fallback = QDir::home().filePath("0/bin/subtitles");
        if (QFileInfo(fallback).isExecutable())
        {
            program = fallback;
        }
    }
    if (program.isEmpty())
    {
        emit failed(tr("The subtitles tool is not installed: there is no "
                       "“subtitles” on the PATH or in ~/0/bin. Nothing was "
                       "changed."));
        return;
    }

    const QString filmName = QFileInfo(m_film).fileName();
    setBusy(true, tr("Writing the corrections into %1…").arg(filmName), -1);

    /* The film is closed first, so nothing holds it during the rename */
    m_player->controller()->stop();

    m_fixPending.clear();
    m_fixLastError.clear();
    m_fixVerified = false;
    m_fixChanged = -1;

    m_fix = new QProcess(this);
    m_fix->setProcessChannelMode(QProcess::SeparateChannels);
    connect(m_fix, &QProcess::readyReadStandardOutput,
            this, &ReviewSession::handleFixOutput);
    connect(m_fix, &QProcess::readyReadStandardError, this, [this] {
        const QStringList lines = QString::fromUtf8(
            m_fix->readAllStandardError()).split('\n', Qt::SkipEmptyParts);
        for (const QString &line : lines)
        {
            if (!line.trimmed().isEmpty())
            {
                m_fixLastError = line.trimmed();
            }
        }
    });
    connect(m_fix, &QProcess::finished, this, &ReviewSession::handleFixFinished);
    connect(m_fix, &QProcess::errorOccurred, this, [this] (QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart)
        {
            handleFixFinished(-1, QProcess::CrashExit);
        }
    });
    m_fix->start(program, {
        "fix-mkv", m_film, m_working,
        "--review", m_review,
        "--expect-sha256", m_sha256,
    });
}

void ReviewSession::handleFixOutput()
{
    m_fixPending += m_fix->readAllStandardOutput();
    qsizetype cut;
    while ((cut = m_fixPending.indexOf('\n')) >= 0)
    {
        const QString line = QString::fromUtf8(m_fixPending.left(cut)).trimmed();
        m_fixPending.remove(0, cut + 1);
        if (line.startsWith("PROGRESS "))
        {
            bool ok = false;
            const double f = line.mid(9).toDouble(&ok);
            if (ok)
            {
                setBusy(true, m_stage, std::clamp(f, 0.0, 1.0));
            }
        }
        else if (line.startsWith("CHANGED "))
        {
            m_fixChanged = line.mid(8).toInt();
        }
        else if (line == "VERIFIED")
        {
            m_fixVerified = true;
        }
        else if (line.startsWith("FIXES "))
        {
            /* The corrections log; nothing to do with it here */
        }
        else if (!line.isEmpty())
        {
            /* fix-mkv reports its errors on stdout ("Error: …") */
            if (line.startsWith("Error:") || !m_fixLastError.startsWith("Error:"))
            {
                m_fixLastError = line;
            }
        }
    }
}

void ReviewSession::handleFixFinished(int exitCode, QProcess::ExitStatus status)
{
    if (!m_fix)
    {
        return;
    }
    handleFixOutput();
    m_fix->deleteLater();
    m_fix = nullptr;
    setBusy(false);

    const QString filmName = QFileInfo(m_film).fileName();
    if (status == QProcess::NormalExit && exitCode == 0 && m_fixVerified)
    {
        QFile::remove(statePath());
        leavePlayerMode();
        setActive(false);
        m_cues.clear();
        m_checked.clear();
        m_current = -1;
        emit cuesChanged();
        emit currentChanged();
        emit checkedChanged();
        emit fixed(m_fixChanged >= 0 ?
            tr("%1 is fixed: %n line(s) changed.", nullptr, m_fixChanged).arg(filmName) :
            tr("%1 is fixed.").arg(filmName));
        return;
    }

    QString reason;
    if (status != QProcess::NormalExit)
    {
        reason = exitCode == -1 ?
            tr("The subtitles tool could not be started.") :
            tr("The subtitles tool crashed.");
    }
    else
    {
        switch (exitCode)
        {
        case 0:
            reason = tr("The subtitles tool did not confirm the result (no VERIFIED line).");
            break;
        case 2:
            reason = tr("The subtitles tool rejected its arguments.");
            break;
        case 3:
            reason = tr("The film has no tagged 日本語 track, or more than one.");
            break;
        case 4:
            reason = tr("The working copy is not valid UTF-8 SubRip, or it failed the lint check.");
            break;
        case 5:
            reason = tr("The remuxed film failed verification. The film is untouched; "
                        "the temporary file was kept beside it.");
            break;
        case 6:
            reason = tr("There is not enough free space beside the film.");
            break;
        case 7:
            reason = tr("The 日本語 track in the film changed after the working copy was taken.");
            break;
        default:
            reason = tr("The subtitles tool failed with exit code %1.").arg(exitCode);
            break;
        }
    }
    if (!m_fixLastError.isEmpty())
    {
        reason += "\n\n" + m_fixLastError;
    }
    emit failed(tr("%1 was not fixed. Nothing was deleted.\n\n%2").arg(filmName, reason));

    if (status == QProcess::NormalExit && exitCode == 7)
    {
        /* Ask again whether to re-extract */
        leavePlayerMode();
        setActive(false);
        prepare(false);
    }
    else
    {
        /* Back to the film, still in correction mode */
        emit loadRequested(m_film);
    }
}
