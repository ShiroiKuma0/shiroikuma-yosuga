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

#include <QList>
#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QSet>
#include <QStringList>
#include <QThreadPool>

#include "player/mpvplayer.h"

/**
 * Fork: correction mode. Works through the review cues the subtitles tool
 * leaves beside a film (`<film>.possible-ja-CORRECTIONS-review.srt`).
 *
 * The film's tool track (the one jpn SubRip track tagged
 * SHIROIKUMA_SUBTITLES) is extracted to `<film>.ja-whisper-working.srt`,
 * which becomes the primary subtitle, so every edit is an instant rewrite
 * of that file. The review SRT is only parsed: its cues give where to go
 * and the note to show; it is never loaded into mpv. When every cue has
 * been reached, Fix MKV closes the film and runs
 * `subtitles fix-mkv FILM WORKING --review REVIEW --expect-sha256 HEX`,
 * which writes the working copy back into the film and deletes both SRTs.
 *
 * The resume state (checked cues, the SHA-256 of the track as extracted)
 * lives in ~/.local/share/shiroikuma-yosuga/review/<film basename>.json.
 */
class ReviewSession : public QObject
{
    Q_OBJECT

    Q_PROPERTY(MpvPlayer *player READ player WRITE setPlayer NOTIFY playerChanged)

    /* True from a successful preparation until Fix MKV succeeds */
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)

    /* True while the track is read or the film is being fixed */
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString stage READ stage NOTIFY stageChanged)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)

    Q_PROPERTY(int count READ count NOTIFY cuesChanged)
    /* 0-based index of the current cue, -1 before the first one */
    Q_PROPERTY(int current READ current NOTIFY currentChanged)
    Q_PROPERTY(int checkedCount READ checkedCount NOTIFY checkedChanged)
    Q_PROPERTY(bool allChecked READ allChecked NOTIFY checkedChanged)
    Q_PROPERTY(QString note READ note NOTIFY currentChanged)

    Q_PROPERTY(QString filmPath READ filmPath NOTIFY filesChanged)
    Q_PROPERTY(QString workingPath READ workingPath NOTIFY filesChanged)

public:
    struct Cue
    {
        double start{0};
        double end{0};
        QString text;
    };

    ReviewSession(QObject *parent = nullptr);
    virtual ~ReviewSession();

    [[nodiscard]] MpvPlayer *player() const noexcept;
    void setPlayer(MpvPlayer *player);

    [[nodiscard]] bool active() const noexcept;
    [[nodiscard]] bool busy() const noexcept;
    [[nodiscard]] const QString &stage() const noexcept;
    [[nodiscard]] double progress() const noexcept;
    [[nodiscard]] int count() const noexcept;
    [[nodiscard]] int current() const noexcept;
    [[nodiscard]] int checkedCount() const noexcept;
    [[nodiscard]] bool allChecked() const noexcept;
    [[nodiscard]] QString note() const;
    [[nodiscard]] const QString &filmPath() const noexcept;
    [[nodiscard]] const QString &workingPath() const noexcept;

    /**
     * @brief Takes over loading if the command line asks for correction
     *        mode (`--review=FILE` or `--review FILE`).
     *
     * @param args The application arguments.
     * @return true if --review was given (the session then loads the film
     *         itself), false to load the arguments the normal way.
     */
    Q_INVOKABLE bool startFromArguments(const QStringList &args);

    /**
     * @brief Starts correction mode for a review SRT or a film.
     */
    Q_INVOKABLE void start(const QString &path);

    /**
     * @brief After the "track changed" question: extract the track anew,
     *        replacing the working copy.
     */
    Q_INVOKABLE void reextract();

    /**
     * @brief After the "track changed" question: leave the working copy
     *        alone and play the film normally.
     */
    Q_INVOKABLE void abort();

    /**
     * @brief Called when a file finished loading (not an editor reload):
     *        selects the working copy and goes to the first unchecked cue.
     */
    Q_INVOKABLE void handleFileLoaded(const QString &path);

    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void goTo(int index);

    /**
     * @brief Closes the film and writes the working copy into it.
     */
    Q_INVOKABLE void fixMkv();

signals:
    void playerChanged();
    void activeChanged();
    void busyChanged();
    void stageChanged();
    void progressChanged();
    void cuesChanged();
    void currentChanged();
    void checkedChanged();
    void filesChanged();

    /**
     * @brief The film should be loaded (in correction mode or, after a
     *        refusal, normally).
     */
    void loadRequested(const QString &film);

    /**
     * @brief The film's track no longer matches the working copy; the
     *        answer is reextract() or abort().
     */
    void confirmRequested(const QString &message);

    /**
     * @brief Something went wrong; nothing was deleted.
     */
    void failed(const QString &message);

    /**
     * @brief Fix MKV succeeded.
     */
    void fixed(const QString &message);

private:
    struct Prepared
    {
        bool ok{false};
        bool needsConfirm{false};
        QString message;
        QList<Cue> cues;
        QString sha256;
        QSet<int> checked;
    };

    void prepare(bool forceReextract);
    void handlePrepared(const Prepared &result);
    void setBusy(bool busy, const QString &stage = {}, double progress = -1);
    void setActive(bool active);
    void saveState() const;
    void handlePosition(double position);
    void dropCorrectionFiles();
    void enterPlayerMode();
    void leavePlayerMode();
    void handleFixOutput();
    void handleFixFinished(int exitCode, QProcess::ExitStatus status);

    [[nodiscard]] QString statePath() const;

    /* Where next/previous seek to for a cue */
    [[nodiscard]] double landingFor(int index) const;

    QPointer<MpvPlayer> m_player;
    QThreadPool m_pool;

    bool m_active{false};
    bool m_busy{false};
    QString m_stage;
    double m_progress{-1};

    QString m_film;
    QString m_review;
    QString m_working;
    QString m_sha256;

    QList<Cue> m_cues;
    QSet<int> m_checked;
    int m_current{-1};

    /* The cue a next/previous is heading for until playback reaches it */
    int m_navTarget{-1};
    double m_navLanding{0};

    /* Player options changed for the mode, to put back afterwards */
    bool m_playerModeSet{false};
    QString m_savedSubAuto;

    QProcess *m_fix{nullptr};
    QByteArray m_fixPending;
    QString m_fixLastError;
    bool m_fixVerified{false};
    int m_fixChanged{-1};
};
