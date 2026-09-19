import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ripose.Memento

Window {
    id: root
    title: qsTr("About 白い熊 縁")
    height: rootLayout.implicitHeight + 20
    width: rootLayout.implicitWidth + 20
    color: MementoPalette.window

    ColumnLayout {
        id: rootLayout
        anchors.fill: parent
        anchors.margins: 10
        spacing: 5

        RowLayout {
            Image {
                source: "qrc:///memento.svg"
                height: mementoText.paintedHeight
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
            }

            Label {
                id: mementoText
                text: qsTr("白い熊 縁")
                font.pixelSize: 96
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: {
                /* Fork: the full <upstream>+<build> version, e.g. 2.0.2+032 */
                let version = Features.version;
                if (Features.buildNumber.length > 0)
                {
                    version += `+${Features.buildNumber}`;
                }
                if (Features.versionHash.length > 0)
                {
                    version += `-${Features.versionHash}`;
                }
                return qsTr("Version %1").arg(version);
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("GPLv2-Only")
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            textFormat: Text.RichText
            text: qsTr("<p><a href=\"https://github.com/ShiroiKuma0/shiroikuma-yosuga\">GitHub</a></p>")
            onLinkActivated: (link) => Qt.openUrlExternally(link)
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            textFormat: Text.RichText
            text: qsTr("<p><a href=\"https://github.com/ripose-jp/Memento\">Upstream project</a></p>")
            onLinkActivated: (link) => Qt.openUrlExternally(link)
        }
    }
}
