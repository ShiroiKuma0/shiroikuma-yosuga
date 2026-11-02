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

#include "subtitle/mkvtools.h"

#include <QFile>
#include <QFileInfo>
#include <QJsonValue>
#include <QVariant>
#include <QObject>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QXmlStreamReader>
#include <QXmlStreamWriter>

namespace MkvTools
{

bool isMatroska(const QString &path)
{
    static const QStringList suffixes{"mkv", "mka", "mks", "mk3d", "webm"};
    return suffixes.contains(QFileInfo(path).suffix().toLower());
}

bool runTool(
    const QString &program,
    QStringList args,
    QByteArray *output,
    QString &error,
    const std::function<void(double)> &progress)
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

quint64 exactUid(const QByteArray &json, const QJsonValue &value)
{
    const QVariant v = value.toVariant();
    if (v.typeId() == QMetaType::LongLong)
    {
        return static_cast<quint64>(v.toLongLong());
    }
    if (!value.isDouble())
    {
        return 0;
    }
    const double wanted = value.toDouble();
    static const QRegularExpression uidRe{"\"uid\"\\s*:\\s*(\\d+)"};
    quint64 found = 0;
    int matches = 0;
    for (const QRegularExpressionMatch &m : uidRe.globalMatch(QString::fromUtf8(json)))
    {
        bool ok = false;
        const quint64 candidate = m.captured(1).toULongLong(&ok);
        if (ok && static_cast<double>(candidate) == wanted && candidate != found)
        {
            found = candidate;
            ++matches;
        }
    }
    return matches == 1 ? found : 0;
}

namespace
{

/* Tags mkvmerge writes itself for every track; they describe the old stream */
bool isStatisticsTag(const QString &name)
{
    static const QSet<QString> names{
        "BPS", "DURATION", "NUMBER_OF_FRAMES", "NUMBER_OF_BYTES",
    };
    return names.contains(name) || name.startsWith("_STATISTICS_");
}

/* A parsed <Simple>, with its nested <Simple>s */
struct SimpleTag
{
    QString name;
    QList<std::pair<QString, QString>> fields;
    QList<SimpleTag> children;
};

SimpleTag readSimple(QXmlStreamReader &xml)
{
    SimpleTag tag;
    while (xml.readNextStartElement())
    {
        if (xml.name() == QLatin1String("Simple"))
        {
            tag.children << readSimple(xml);
        }
        else
        {
            const QString field = xml.name().toString();
            const QString value = xml.readElementText();
            if (field == QLatin1String("Name"))
            {
                tag.name = value;
            }
            tag.fields << std::pair{field, value};
        }
    }
    return tag;
}

void writeSimple(QXmlStreamWriter &out, const SimpleTag &tag)
{
    out.writeStartElement("Simple");
    for (const auto &[field, value] : tag.fields)
    {
        out.writeTextElement(field, value);
    }
    for (const SimpleTag &child : tag.children)
    {
        writeSimple(out, child);
    }
    out.writeEndElement();
}

} // namespace

bool extractTrackTags(
    const QString &path,
    quint64 trackUid,
    const QString &outPath,
    bool &written,
    QString &error)
{
    written = false;

    QByteArray xmlData;
    if (!runTool("mkvextract", {path, "tags", "-"}, &xmlData, error))
    {
        return false;
    }
    if (xmlData.trimmed().isEmpty())
    {
        return true;
    }

    /* Each <Tag> aimed at this track alone: its targets other than the
     * TrackUID, and its non-statistics <Simple>s */
    struct TagGroup
    {
        QList<std::pair<QString, QString>> targets;
        QList<SimpleTag> simples;
    };
    QList<TagGroup> groups;

    QXmlStreamReader xml(xmlData);
    if (!xml.readNextStartElement() || xml.name() != QLatin1String("Tags"))
    {
        error = QObject::tr("Cannot read the track tags of %1")
            .arg(QFileInfo(path).fileName());
        return false;
    }
    while (xml.readNextStartElement())
    {
        if (xml.name() != QLatin1String("Tag"))
        {
            xml.skipCurrentElement();
            continue;
        }
        TagGroup group;
        bool forTrack = false;
        bool otherTarget = false;
        while (xml.readNextStartElement())
        {
            if (xml.name() == QLatin1String("Targets"))
            {
                while (xml.readNextStartElement())
                {
                    const QString field = xml.name().toString();
                    const QString value = xml.readElementText().trimmed();
                    if (field == QLatin1String("TrackUID"))
                    {
                        if (value.toULongLong() == trackUid)
                        {
                            forTrack = true;
                        }
                        else
                        {
                            otherTarget = true;
                        }
                    }
                    else if (field.endsWith(QLatin1String("UID")))
                    {
                        otherTarget = true;
                    }
                    else
                    {
                        group.targets << std::pair{field, value};
                    }
                }
            }
            else if (xml.name() == QLatin1String("Simple"))
            {
                SimpleTag simple = readSimple(xml);
                if (!isStatisticsTag(simple.name))
                {
                    group.simples << simple;
                }
            }
            else
            {
                xml.skipCurrentElement();
            }
        }
        if (forTrack && !otherTarget && !group.simples.isEmpty())
        {
            groups << group;
        }
    }
    if (xml.hasError())
    {
        error = QObject::tr("Cannot read the track tags of %1: %2")
            .arg(QFileInfo(path).fileName(), xml.errorString());
        return false;
    }
    if (groups.isEmpty())
    {
        return true;
    }

    QSaveFile file(outPath);
    if (!file.open(QIODevice::WriteOnly))
    {
        error = QObject::tr("Cannot write %1").arg(outPath);
        return false;
    }
    QXmlStreamWriter out(&file);
    out.setAutoFormatting(true);
    out.writeStartDocument();
    out.writeStartElement("Tags");
    for (const TagGroup &group : groups)
    {
        out.writeStartElement("Tag");
        out.writeStartElement("Targets");
        for (const auto &[field, value] : group.targets)
        {
            out.writeTextElement(field, value);
        }
        out.writeEndElement();
        for (const SimpleTag &simple : group.simples)
        {
            writeSimple(out, simple);
        }
        out.writeEndElement();
    }
    out.writeEndElement();
    out.writeEndDocument();
    if (!file.commit())
    {
        error = QObject::tr("Cannot write %1").arg(outPath);
        return false;
    }
    written = true;
    return true;
}

} // namespace MkvTools
