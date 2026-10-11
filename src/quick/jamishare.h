////////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2026 白い熊
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

#pragma once

#include <QObject>

/**
 * Fork: hand dictionary entries over to the desktop Jami client.
 *
 * Jami's desktop client (jami-all) runs its daemon in-process and offers no
 * API for sending messages, so sharing is "copy, raise Jami, paste": the
 * text goes to the clipboard and Jami is brought to the front, where the
 * chat is picked by hand.
 */
class JamiShare : public QObject
{
    Q_OBJECT

public:
    JamiShare(QObject *parent = nullptr);
    virtual ~JamiShare() = default;

    /**
     * @brief Bring Jami to the front, starting it only if it is not running.
     *
     * A running Jami is woken through its single-instance socket, exactly as
     * a second `jami` launch would do it, so no second process is spawned.
     *
     * @return true if Jami was woken or started, false otherwise.
     */
    Q_INVOKABLE bool raise() const;
};
