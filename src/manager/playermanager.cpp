////////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2026 Ripose
//
// This file is part of Memento.
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

#include "manager/playermanager.h"

#include <QRegularExpression>

#include "player/mpvplayer.h"
#include "state/context.h"

PlayerManager::PlayerManager(Context *context, QObject *parent) :
    QObject(parent),
    m_context(context)
{
    connect(
        m_context->settings(), &Settings::behaviorSubtitlePauseChanged,
        this, &PlayerManager::resetAutoPause,
        Qt::QueuedConnection
    );
    connect(
        m_context->player(), &MpvPlayer::fileLoaded,
        this, &PlayerManager::resetAutoPause,
        Qt::QueuedConnection
    );
    connect(
        m_context->player(), &MpvPlayer::fileLoaded,
        this, &PlayerManager::selectDefaultSecondarySubtitle,
        Qt::QueuedConnection
    );
    connect(
        m_context->player()->state()->subtitle(), &MpvSubtitle::delayChanged,
        this, &PlayerManager::resetAutoPause,
        Qt::QueuedConnection
    );
    connect(
        m_context->player()->state(), &MpvState::timePositionChanged,
        this, &PlayerManager::handleAutoPausePosition,
        Qt::QueuedConnection
    );
    connect(
        m_context->player()->state()->subtitle(), &MpvSubtitle::textChanged,
        this, &PlayerManager::handleAutoPause,
        Qt::QueuedConnection
    );
}

PlayerManager::~PlayerManager()
{

}

/**
 * @brief Whether a track is an English one.
 *
 * Goes by the language tag (en, eng, en-US, ...). Tracks that carry no tag
 * (or an undetermined one) often have the language in the title instead,
 * either as the bare code ("en") or the name ("English"), so fall back to
 * that.
 *
 * @param track The track to check.
 * @return true if the track is English, false otherwise.
 */
static bool isEnglishTrack(const MpvTrack *track)
{
    static const QRegularExpression englishCode(
        "^eng?([-_].*)?$", QRegularExpression::CaseInsensitiveOption
    );
    const QString &lang = track->language();
    if (!lang.isEmpty() && lang.compare("und", Qt::CaseInsensitive) != 0)
    {
        return englishCode.match(lang).hasMatch();
    }
    const QString title = track->title().trimmed();
    return englishCode.match(title).hasMatch() ||
        title.contains("english", Qt::CaseInsensitive);
}

void PlayerManager::selectDefaultSecondarySubtitle()
{
    MpvState *state = m_context->player()->state();
    for (const MpvTrack *track : state->subtitleTracks())
    {
        if (!isEnglishTrack(track))
        {
            continue;
        }
        /* mpv refuses to select one track twice; leave a file whose only
         * English track is already the primary subtitle alone. */
        if (track->id() != state->sid())
        {
            m_context->player()->controller()->setSecondarySid(track->id());
        }
        return;
    }
}

void PlayerManager::resetAutoPause()
{
    m_autoPauseData.reset = true;
}

void PlayerManager::handleAutoPausePosition(double position)
{
    constexpr double SEEK_DELTA{1};

    if (m_autoPauseData.previousPosition < 0)
    {
        /* noop */
    }
    else if (m_autoPauseData.startTime <= position &&
        position <= m_autoPauseData.endTime)
    {
        /* noop */
    }
    else if (std::abs(m_autoPauseData.previousPosition - position) > SEEK_DELTA)
    {
        resetAutoPause();
    }
    m_autoPauseData.previousPosition = position;
}


void PlayerManager::handleAutoPause()
{
    if (!m_context->settings()->behaviorSubtitlePause())
    {
        return;
    }

    if (m_autoPauseData.reset)
    {
        m_autoPauseData = {};
    }

    double startTime{m_context->player()->state()->subtitle()->startTime()};
    double endTime{m_context->player()->state()->subtitle()->endTime()};

    if (m_autoPauseData.lastEndTime == endTime)
    {
        return;
    }

    if (endTime == 0)
    {
        if (m_autoPauseData.endTime == 0)
        {
            return;
        }
    }
    else if (m_autoPauseData.endTime == 0)
    {
        m_autoPauseData.startTime = startTime;
        m_autoPauseData.endTime = endTime;
        m_autoPauseData.alreadyPaused = false;
        return;
    }
    else if (m_autoPauseData.endTime > endTime)
    {
        m_autoPauseData.startTime = startTime;
        m_autoPauseData.endTime = endTime;
        m_autoPauseData.alreadyPaused = false;
        return;
    }

    if (m_context->player()->state()->pause())
    {
        return;
    }

    if (m_autoPauseData.alreadyPaused)
    {
        m_autoPauseData.alreadyPaused = false;
        return;
    }

    m_context->player()->controller()->pause();
    double idealSeekTime = std::clamp(
        m_autoPauseData.endTime +
            m_context->player()->state()->subtitle()->delay() -
            0.1,
        0.0,
        m_context->player()->state()->duration()
    );
    m_context->player()->controller()->seek(idealSeekTime);

    m_autoPauseData.lastEndTime = m_autoPauseData.endTime;
    m_autoPauseData.startTime = startTime;
    m_autoPauseData.endTime = endTime;
    m_autoPauseData.alreadyPaused = true;
}
