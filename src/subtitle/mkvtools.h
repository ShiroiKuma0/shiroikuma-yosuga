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

#pragma once

#include <functional>

#include <QByteArray>
#include <QJsonValue>
#include <QString>
#include <QStringList>

/**
 * Fork: small helpers around the mkvtoolnix command-line tools, shared by
 * the subtitle editor and the correction mode.
 */
namespace MkvTools
{

/**
 * @brief Whether a path names a Matroska file, by its suffix.
 */
[[nodiscard]]
bool isMatroska(const QString &path);

/**
 * @brief Runs a mkvtoolnix tool to completion. Exit code 1 is "warnings only".
 *
 * Blocking: call it from a worker thread.
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
    const std::function<void(double)> &progress = {});

/**
 * @brief The exact value of a UID from mkvmerge -J output.
 *
 * QJsonDocument keeps integers beyond the qint64 range only as doubles, so
 * a UID above 2^63 is matched back against the digits in the raw JSON.
 *
 * @param json  The raw mkvmerge -J output.
 * @param value The parsed "uid" value.
 * @return The UID, or 0 if it cannot be determined exactly.
 */
[[nodiscard]]
quint64 exactUid(const QByteArray &json, const QJsonValue &value);

/**
 * @brief Writes the track's own tags (statistics tags left out) as a
 *        mkvmerge tags XML file with an empty target, ready for
 *        `--tags 0:<file>` on the track that replaces it.
 *
 * Blocking: call it from a worker thread.
 *
 * @param path     The Matroska file.
 * @param trackUid The track's UID (mkvmerge -J properties.uid).
 * @param outPath  Where to write the XML.
 * @param written  Set to true if the track had tags and the file was written.
 * @param error    Receives the reason on failure.
 * @return false on failure, true otherwise (with or without tags).
 */
bool extractTrackTags(
    const QString &path,
    quint64 trackUid,
    const QString &outPath,
    bool &written,
    QString &error);

} // namespace MkvTools
