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

#include "quick/jamishare.h"

#include <QCryptographicHash>
#include <QLocalSocket>
#include <QProcess>

JamiShare::JamiShare(QObject *parent) : QObject(parent)
{

}

bool JamiShare::raise() const
{
    /* jami-client-qt's InstanceManager listens on a local server named by
     * the raw SHA-256 of its application name and organization domain; any
     * connection to it makes the primary instance restore its window. */
    QCryptographicHash key(QCryptographicHash::Sha256);
    key.addData(QByteArrayLiteral("Jami"));
    key.addData(QByteArrayLiteral("jami.net"));

    QLocalSocket socket;
    socket.connectToServer(QString::fromUtf8(key.result()));
    if (socket.waitForConnected(1000))
    {
        socket.disconnectFromServer();
        return true;
    }
    return QProcess::startDetached("jami", {});
}
