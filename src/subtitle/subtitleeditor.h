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

#include <vector>

#include <QObject>
#include <QPointer>
#include <QStringList>
#include <QThreadPool>
#include <QTimer>

#include "player/mpvplayer.h"
#include "subtitle/subtitleentry.h"
#include "subtitle/subtitlelists.h"

/**
 * Fork: writes an inline edit of the current primary subtitle back to its
 * source, then reloads the file.
 *
 * Every save writes the whole subtitle stream anew. An external SRT/VTT/ASS
 * file is rewritten. A track inside a Matroska file is extracted with
 * mkvextract, edited, and muxed back with mkvmerge into a new file beside
 * the original — every other track, attachment, chapter and tag carried
 * over — which then replaces the original by rename.
 *
 * mpv is then made to reopen the file at the same position, with the same
 * pause state, track selection (external subtitles re-added) and subtitle
 * list contents; the window is left alone.
 */
class SubtitleEditor : public QObject
{
    Q_OBJECT

    Q_PROPERTY(
        MpvPlayer *player
        READ player
        WRITE setPlayer
        NOTIFY playerChanged
    )

    Q_PROPERTY(
        SubtitleLists *lists
        MEMBER m_lists
        NOTIFY listsChanged
    )

    /* True from the save request until the reloaded file is restored */
    Q_PROPERTY(
        bool busy
        READ busy
        NOTIFY busyChanged
    )

    /* True while mpv reopens the file; suppresses autofit and auto-play */
    Q_PROPERTY(
        bool reloading
        READ reloading
        NOTIFY reloadingChanged
    )

    /* What is happening now, for the progress dialog */
    Q_PROPERTY(
        QString stage
        READ stage
        NOTIFY stageChanged
    )

    /* 0–1 overall, or -1 when there is no measurable progress */
    Q_PROPERTY(
        double progress
        READ progress
        NOTIFY progressChanged
    )

public:
    SubtitleEditor(QObject *parent = nullptr);
    virtual ~SubtitleEditor();

    [[nodiscard]]
    MpvPlayer *player() const noexcept;
    void setPlayer(MpvPlayer *player);

    [[nodiscard]]
    bool busy() const noexcept;

    [[nodiscard]]
    bool reloading() const noexcept;

    [[nodiscard]]
    const QString &stage() const noexcept;

    [[nodiscard]]
    double progress() const noexcept;

    /**
     * @brief Saves an edit of the current primary subtitle and reloads.
     *
     * @param oldText The subtitle text as mpv showed it when editing began.
     * @param start   The subtitle start time as mpv reported it (seconds,
     *                including the subtitle delay).
     * @param end     The subtitle end time as mpv reported it.
     * @param delay   The subtitle delay at the time editing began.
     * @param newText The edited text.
     * @param resume  true to resume playback when done.
     * @return true if the save started, false if it was refused or there was
     *         nothing to save (the reason, if any, is emitted as failed()).
     */
    Q_INVOKABLE bool save(
        const QString &oldText,
        double start,
        double end,
        double delay,
        QString newText,
        bool resume);

signals:
    void playerChanged();
    void listsChanged();
    void busyChanged();
    void reloadingChanged();
    void stageChanged();
    void progressChanged();

    /**
     * @brief Emitted when the edit was saved and the file reloaded.
     */
    void finished(QString message);

    /**
     * @brief Emitted when the edit could not be saved.
     */
    void failed(QString message);

private:
    /**
     * @brief Identifies a track across a reload, where ids may change.
     */
    struct TrackKey
    {
        bool valid{false};
        bool external{false};
        QString externalFilename;
        int64_t sourceId{0};
    };

    /**
     * @brief Everything the reload must put back.
     */
    struct ReloadState
    {
        double position{0};
        bool resume{false};
        QString previousStart;

        TrackKey aid;
        TrackKey vid;
        TrackKey sid;
        TrackKey secondarySid;

        /* External subtitle files, in track order */
        QStringList externalSubtitles;

        /* Subtitle list contents of embedded tracks (lists of external ones
         * are parsed from the file again) */
        bool restorePrimaryList{false};
        std::vector<SubtitleEntry> primaryList;
        bool restoreSecondaryList{false};
        std::vector<SubtitleEntry> secondaryList;

        /* Track ids after the reload */
        int64_t newSid{0};
        int64_t newSecondarySid{0};

        QString message;
    };

    void setStage(const QString &stage, double progress);
    void setBusy(bool busy);
    void setReloading(bool reloading);

    void handleSaveFinished(bool ok, const QString &message);
    void startReload(const QString &message);
    void handleFileLoaded();
    void restoreLists();
    void stopListRestore();
    void finish(const QString &message);

    [[nodiscard]]
    TrackKey keyFor(const QList<MpvTrack *> &tracks, int64_t id) const;

    [[nodiscard]]
    int64_t idFor(const QList<MpvTrack *> &tracks, const TrackKey &key) const;

    QPointer<MpvPlayer> m_player;
    QPointer<SubtitleLists> m_lists;

    /* One worker: saves to the same file must never overlap */
    QThreadPool m_pool;

    bool m_busy{false};
    bool m_reloading{false};
    QString m_stage;
    double m_progress{-1};

    /* The edit in flight */
    double m_editStart{0};
    double m_editDelay{0};
    QString m_editOld;
    QString m_editNew;
    bool m_resume{false};

    ReloadState m_reload;

    /* Gives the subtitle lists a moment to follow the restored tracks */
    QTimer m_listRestoreTimer;
    QList<QMetaObject::Connection> m_listRestoreConnections;
};
