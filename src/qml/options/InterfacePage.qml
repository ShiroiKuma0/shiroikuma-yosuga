import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Ripose.Memento

Page {
    id: root

    property int preferredWidth: 600
    property int groupSpacing: 10

    footer: ColumnLayout {
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            visible: Features.isUnix && !scrollView.atBottom
            color: MementoPalette.border
            height: 1
        }

        DialogButtonBox {
            id: buttonBoxFooter
            Layout.fillWidth: true
            standardButtons: DialogButtonBox.Apply |
                             DialogButtonBox.RestoreDefaults |
                             DialogButtonBox.Reset

            onApplied: MementoSettings.writeInterfaceSettings()
            onClicked: function(button) {
                if (button === standardButton(DialogButtonBox.Reset))
                {
                    MementoSettings.loadInterfaceSettings();
                }
                else if (button === standardButton(DialogButtonBox.RestoreDefaults))
                {
                    MementoSettings.defaultInterfaceSettings();
                }
            }
        }
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        contentWidth: scrollView.contentWidth
        leftPadding: root.groupSpacing
        rightPadding: root.groupSpacing
        clip: true

        readonly property bool atBottom:
            (ScrollBar.vertical.position + ScrollBar.vertical.size) >= 0.99

        ColumnLayout {
            id: scrollViewLayout
            width: parent.width
            spacing: root.groupSpacing

            SettingsBox {
                id: themeBox
                Layout.preferredWidth: root.preferredWidth
                Layout.topMargin: root.groupSpacing
                Layout.alignment: Qt.AlignHCenter
                visible: Features.isUnix
                title: qsTr("Theme")

                ColumnLayout {
                    anchors.fill: parent
                    spacing: root.groupSpacing

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Use system icons")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSystemIcons
                            onClicked: MementoSettings.interfaceSystemIcons = checked
                        }
                    }
                }
            }

            SettingsBox {
                id: subtitleBox
                Layout.preferredWidth: root.preferredWidth
                Layout.topMargin: themeBox.visible ? 0 : root.groupSpacing
                Layout.alignment: Qt.AlignHCenter
                title: qsTr("Subtitle")

                ColumnLayout {
                    anchors.fill: parent
                    spacing: root.groupSpacing

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Font")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: MementoSettings.interfaceSubtitleFont.family
                            onClicked: subtitleFontDialog.open()
                        }
                        FontDialog {
                            id: subtitleFontDialog
                            title: qsTr("Select Subtitle Font")
                            currentFont: MementoSettings.interfaceSubtitleFont
                            onAccepted: MementoSettings.interfaceSubtitleFont = selectedFont
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Bold")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSubtitleFont.bold
                            onClicked: {
                                const f = MementoSettings.interfaceSubtitleFont;
                                f.bold = checked;
                                MementoSettings.interfaceSubtitleFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Italics")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSubtitleFont.italic
                            onClicked: {
                                const f = MementoSettings.interfaceSubtitleFont;
                                f.italic = checked;
                                MementoSettings.interfaceSubtitleFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Line spacing")
                        }
                        TextField {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 100
                            validator: DoubleValidator { }
                            placeholderText: qsTr("Pixels")
                            text: MementoSettings.interfaceSubtitleLineSpacing
                            onEditingFinished: MementoSettings.interfaceSubtitleLineSpacing = text
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Line height as a percentage of window height")
                        }
                        TextField {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 100
                            validator: DoubleValidator {
                                bottom: 0.001
                                top: 1.0
                            }
                            placeholderText: qsTr("Percent")
                            text: MementoSettings.interfaceSubtitleScale
                            onEditingFinished: MementoSettings.interfaceSubtitleScale = text
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Bottom offset as a percentage of window height")
                        }
                        TextField {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 100
                            validator: DoubleValidator {
                                bottom: 0.0
                                top: 1.0
                            }
                            placeholderText: qsTr("Percent")
                            text: MementoSettings.interfaceSubtitleOffset
                            onEditingFinished: MementoSettings.interfaceSubtitleOffset = text
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Secondary subtitle top offset as a percentage of window height")
                        }
                        TextField {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 100
                            validator: DoubleValidator {
                                bottom: 0.0
                                top: 1.0
                            }
                            placeholderText: qsTr("Percent")
                            text: MementoSettings.interfaceSubtitleSecondaryOffset
                            onEditingFinished: MementoSettings.interfaceSubtitleSecondaryOffset = text
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Stroke size")
                        }
                        TextField {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 100
                            validator: DoubleValidator {
                                bottom: 0.0
                                top: 1000.0
                            }
                            placeholderText: qsTr("Pixels")
                            text: MementoSettings.interfaceSubtitleStroke
                            onEditingFinished: MementoSettings.interfaceSubtitleStroke = text
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Text color")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSubtitleColor
                                radius: 10
                            }
                            onClicked: textColorDialog.open()
                        }
                        ColorDialog {
                            id: textColorDialog
                            title: qsTr("Select Subtitle Text Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSubtitleColor
                            onAccepted: MementoSettings.interfaceSubtitleColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Background color")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSubtitleBackground
                                radius: 10
                            }
                            onClicked: textBackgroundDialog.open()
                        }
                        ColorDialog {
                            id: textBackgroundDialog
                            title: qsTr("Select Subtitle Background Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSubtitleBackground
                            onAccepted: MementoSettings.interfaceSubtitleBackground = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Stroke color")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSubtitleStrokeColor
                                radius: 10
                            }
                            onClicked: textStrokeDialog.open()
                        }
                        ColorDialog {
                            id: textStrokeDialog
                            title: qsTr("Select Subtitle Stroke Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSubtitleStrokeColor
                            onAccepted: MementoSettings.interfaceSubtitleStrokeColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                        visible: Features.mecab
                    }

                    RowLayout {
                        visible: Features.mecab
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Target furigana to subtitle size ratio")
                        }
                        TextField {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 100
                            validator: DoubleValidator {
                                bottom: 0.0
                                top: 1.0
                            }
                            placeholderText: qsTr("Ratio")
                            text: MementoSettings.interfaceSubtitleFuriganaRatio
                            onEditingFinished: MementoSettings.interfaceSubtitleFuriganaRatio = text
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    StrokeLabel {
                        id: subtitleExampleLabel
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter

                        font.family: MementoSettings.interfaceSubtitleFont.family
                        font.bold: MementoSettings.interfaceSubtitleFont.bold
                        font.italic: MementoSettings.interfaceSubtitleFont.italic
                        font.underline: MementoSettings.interfaceSubtitleFont.underline
                        font.pointSize: 24
                        font.weight: MementoSettings.interfaceSubtitleFont.weight
                        font.overline: MementoSettings.interfaceSubtitleFont.overline
                        font.strikeout: MementoSettings.interfaceSubtitleFont.strikeout
                        font.letterSpacing: MementoSettings.interfaceSubtitleFont.letterSpacing
                        font.wordSpacing: MementoSettings.interfaceSubtitleFont.wordSpacing
                        font.kerning: MementoSettings.interfaceSubtitleFont.kerning
                        font.preferShaping: MementoSettings.interfaceSubtitleFont.preferShaping
                        font.hintingPreference: MementoSettings.interfaceSubtitleFont.hintingPreference
                        font.styleName: MementoSettings.interfaceSubtitleFont.styleName

                        color: MementoSettings.interfaceSubtitleColor
                        background: MementoSettings.interfaceSubtitleBackground
                        stroke: MementoSettings.interfaceSubtitleStrokeColor
                        strokeSize: MementoSettings.interfaceSubtitleStroke
                        lineSpacing: MementoSettings.interfaceSubtitleLineSpacing
                        text: "メメントを使って\nありがとうございます"
                    }
                }
            }

            SettingsBox {
                id: searchBox
                Layout.preferredWidth: root.preferredWidth
                Layout.alignment: Qt.AlignHCenter
                title: qsTr("Search")

                ColumnLayout {
                    anchors.fill: parent
                    spacing: root.groupSpacing

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Term Expression Font")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: MementoSettings.interfaceSearchExpressionFont.family
                            onClicked: searchExpressionFontDialog.open()
                        }
                        FontDialog {
                            id: searchExpressionFontDialog
                            title: qsTr("Select Term Expression Font")
                            currentFont: MementoSettings.interfaceSearchExpressionFont
                            onAccepted: MementoSettings.interfaceSearchExpressionFont = selectedFont
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Bold")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSearchExpressionFont.bold
                            onClicked: {
                                const f = MementoSettings.interfaceSearchExpressionFont;
                                f.bold = checked;
                                MementoSettings.interfaceSearchExpressionFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Italics")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSearchExpressionFont.italic
                            onClicked: {
                                const f = MementoSettings.interfaceSearchExpressionFont;
                                f.italic = checked;
                                MementoSettings.interfaceSearchExpressionFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Size")
                        }
                        SpinBox {
                            Layout.alignment: Qt.AlignRight
                            editable: true
                            from: 1
                            to: 512
                            value: MementoSettings.interfaceSearchExpressionFont.pointSize
                            onValueModified: {
                                const f = MementoSettings.interfaceSearchExpressionFont;
                                f.pointSize = value;
                                MementoSettings.interfaceSearchExpressionFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Color")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSearchExpressionColor
                                radius: 10
                            }
                            onClicked: searchExpressionColorDialog.open()
                        }
                        ColorDialog {
                            id: searchExpressionColorDialog
                            title: qsTr("Select Term Expression Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSearchExpressionColor
                            onAccepted: MementoSettings.interfaceSearchExpressionColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Term Reading Font")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: MementoSettings.interfaceSearchReadingFont.family
                            onClicked: searchReadingFontDialog.open()
                        }
                        FontDialog {
                            id: searchReadingFontDialog
                            title: qsTr("Select Term Reading Font")
                            currentFont: MementoSettings.interfaceSearchReadingFont
                            onAccepted: MementoSettings.interfaceSearchReadingFont = selectedFont
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Bold")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSearchReadingFont.bold
                            onClicked: {
                                const f = MementoSettings.interfaceSearchReadingFont;
                                f.bold = checked;
                                MementoSettings.interfaceSearchReadingFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Italics")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSearchReadingFont.italic
                            onClicked: {
                                const f = MementoSettings.interfaceSearchReadingFont;
                                f.italic = checked;
                                MementoSettings.interfaceSearchReadingFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Size")
                        }
                        SpinBox {
                            Layout.alignment: Qt.AlignRight
                            editable: true
                            from: 1
                            to: 512
                            value: MementoSettings.interfaceSearchReadingFont.pointSize
                            onValueModified: {
                                const f = MementoSettings.interfaceSearchReadingFont;
                                f.pointSize = value;
                                MementoSettings.interfaceSearchReadingFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Color")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSearchReadingColor
                                radius: 10
                            }
                            onClicked: searchReadingColorDialog.open()
                        }
                        ColorDialog {
                            id: searchReadingColorDialog
                            title: qsTr("Select Term Reading Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSearchReadingColor
                            onAccepted: MementoSettings.interfaceSearchReadingColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Term Conjugation Explanation Font")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: MementoSettings.interfaceSearchConjFont.family
                            onClicked: searchConjFontDialog.open()
                        }
                        FontDialog {
                            id: searchConjFontDialog
                            title: qsTr("Select Term Conjugation Explanation Font")
                            currentFont: MementoSettings.interfaceSearchConjFont
                            onAccepted: MementoSettings.interfaceSearchConjFont = selectedFont
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Bold")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSearchConjFont.bold
                            onClicked: {
                                const f = MementoSettings.interfaceSearchConjFont;
                                f.bold = checked;
                                MementoSettings.interfaceSearchConjFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Italics")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSearchConjFont.italic
                            onClicked: {
                                const f = MementoSettings.interfaceSearchConjFont;
                                f.italic = checked;
                                MementoSettings.interfaceSearchConjFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Size")
                        }
                        SpinBox {
                            Layout.alignment: Qt.AlignRight
                            editable: true
                            from: 1
                            to: 512
                            value: MementoSettings.interfaceSearchConjFont.pointSize
                            onValueModified: {
                                const f = MementoSettings.interfaceSearchConjFont;
                                f.pointSize = value;
                                MementoSettings.interfaceSearchConjFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Color")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSearchConjColor
                                radius: 10
                            }
                            onClicked: searchConjColorDialog.open()
                        }
                        ColorDialog {
                            id: searchConjColorDialog
                            title: qsTr("Select Term Conjugation Explanation Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSearchConjColor
                            onAccepted: MementoSettings.interfaceSearchConjColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Tag Font")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: MementoSettings.interfaceSearchTagFont.family
                            onClicked: searchTagFontDialog.open()
                        }
                        FontDialog {
                            id: searchTagFontDialog
                            title: qsTr("Select Tag Font")
                            currentFont: MementoSettings.interfaceSearchTagFont
                            onAccepted: MementoSettings.interfaceSearchTagFont = selectedFont
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Bold")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSearchTagFont.bold
                            onClicked: {
                                const f = MementoSettings.interfaceSearchTagFont;
                                f.bold = checked;
                                MementoSettings.interfaceSearchTagFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Italics")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSearchTagFont.italic
                            onClicked: {
                                const f = MementoSettings.interfaceSearchTagFont;
                                f.italic = checked;
                                MementoSettings.interfaceSearchTagFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Size")
                        }
                        SpinBox {
                            Layout.alignment: Qt.AlignRight
                            editable: true
                            from: 1
                            to: 512
                            value: MementoSettings.interfaceSearchTagFont.pointSize
                            onValueModified: {
                                const f = MementoSettings.interfaceSearchTagFont;
                                f.pointSize = value;
                                MementoSettings.interfaceSearchTagFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Color")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSearchTagColor
                                radius: 10
                            }
                            onClicked: searchTagColorDialog.open()
                        }
                        ColorDialog {
                            id: searchTagColorDialog
                            title: qsTr("Select Tag Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSearchTagColor
                            onAccepted: MementoSettings.interfaceSearchTagColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Glossary Font")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: MementoSettings.interfaceSearchGlossaryFont.family
                            onClicked: searchGlossaryFontDialog.open()
                        }
                        FontDialog {
                            id: searchGlossaryFontDialog
                            title: qsTr("Select Glossary Font")
                            currentFont: MementoSettings.interfaceSearchGlossaryFont
                            onAccepted: MementoSettings.interfaceSearchGlossaryFont = selectedFont
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Bold")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSearchGlossaryFont.bold
                            onClicked: {
                                const f = MementoSettings.interfaceSearchGlossaryFont;
                                f.bold = checked;
                                MementoSettings.interfaceSearchGlossaryFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Italics")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSearchGlossaryFont.italic
                            onClicked: {
                                const f = MementoSettings.interfaceSearchGlossaryFont;
                                f.italic = checked;
                                MementoSettings.interfaceSearchGlossaryFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Size")
                        }
                        SpinBox {
                            Layout.alignment: Qt.AlignRight
                            editable: true
                            from: 1
                            to: 512
                            value: MementoSettings.interfaceSearchGlossaryFont.pointSize
                            onValueModified: {
                                const f = MementoSettings.interfaceSearchGlossaryFont;
                                f.pointSize = value;
                                MementoSettings.interfaceSearchGlossaryFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Color")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSearchGlossaryColor
                                radius: 10
                            }
                            onClicked: searchGlossaryColorDialog.open()
                        }
                        ColorDialog {
                            id: searchGlossaryColorDialog
                            title: qsTr("Select Glossary Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSearchGlossaryColor
                            onAccepted: MementoSettings.interfaceSearchGlossaryColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Kanji Font")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: MementoSettings.interfaceSearchKanjiFont.family
                            onClicked: searchKanjiFontDialog.open()
                        }
                        FontDialog {
                            id: searchKanjiFontDialog
                            title: qsTr("Select Kanji Font")
                            currentFont: MementoSettings.interfaceSearchKanjiFont
                            onAccepted: MementoSettings.interfaceSearchKanjiFont = selectedFont
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Bold")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSearchKanjiFont.bold
                            onClicked: {
                                const f = MementoSettings.interfaceSearchKanjiFont;
                                f.bold = checked;
                                MementoSettings.interfaceSearchKanjiFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Italics")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSearchKanjiFont.italic
                            onClicked: {
                                const f = MementoSettings.interfaceSearchKanjiFont;
                                f.italic = checked;
                                MementoSettings.interfaceSearchKanjiFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Size")
                        }
                        SpinBox {
                            Layout.alignment: Qt.AlignRight
                            editable: true
                            from: 1
                            to: 512
                            value: MementoSettings.interfaceSearchKanjiFont.pointSize
                            onValueModified: {
                                const f = MementoSettings.interfaceSearchKanjiFont;
                                f.pointSize = value;
                                MementoSettings.interfaceSearchKanjiFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Color")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSearchKanjiColor
                                radius: 10
                            }
                            onClicked: searchKanjiColorDialog.open()
                        }
                        ColorDialog {
                            id: searchKanjiColorDialog
                            title: qsTr("Select Kanji Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSearchKanjiColor
                            onAccepted: MementoSettings.interfaceSearchKanjiColor = selectedColor
                        }
                    }
                }
            }

            SettingsBox {
                id: tagColorsBox
                Layout.preferredWidth: root.preferredWidth
                Layout.alignment: Qt.AlignHCenter
                title: qsTr("Tag Colors")

                ColumnLayout {
                    anchors.fill: parent
                    spacing: root.groupSpacing

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Name")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSearchTagNameColor
                                radius: 10
                            }
                            onClicked: tagNameColorDialog.open()
                        }
                        ColorDialog {
                            id: tagNameColorDialog
                            title: qsTr("Select Name Tag Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSearchTagNameColor
                            onAccepted: MementoSettings.interfaceSearchTagNameColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Expression")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSearchTagExpressionColor
                                radius: 10
                            }
                            onClicked: tagExpressionColorDialog.open()
                        }
                        ColorDialog {
                            id: tagExpressionColorDialog
                            title: qsTr("Select Expression Tag Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSearchTagExpressionColor
                            onAccepted: MementoSettings.interfaceSearchTagExpressionColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Popular")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSearchTagPopularColor
                                radius: 10
                            }
                            onClicked: tagPopularColorDialog.open()
                        }
                        ColorDialog {
                            id: tagPopularColorDialog
                            title: qsTr("Select Popular Tag Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSearchTagPopularColor
                            onAccepted: MementoSettings.interfaceSearchTagPopularColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Frequent")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSearchTagFrequentColor
                                radius: 10
                            }
                            onClicked: tagFrequentColorDialog.open()
                        }
                        ColorDialog {
                            id: tagFrequentColorDialog
                            title: qsTr("Select Frequent Tag Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSearchTagFrequentColor
                            onAccepted: MementoSettings.interfaceSearchTagFrequentColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Archaism")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSearchTagArchaismColor
                                radius: 10
                            }
                            onClicked: tagArchaismColorDialog.open()
                        }
                        ColorDialog {
                            id: tagArchaismColorDialog
                            title: qsTr("Select Archaism Tag Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSearchTagArchaismColor
                            onAccepted: MementoSettings.interfaceSearchTagArchaismColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Dictionary")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSearchTagDictionaryColor
                                radius: 10
                            }
                            onClicked: tagDictionaryColorDialog.open()
                        }
                        ColorDialog {
                            id: tagDictionaryColorDialog
                            title: qsTr("Select Dictionary Tag Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSearchTagDictionaryColor
                            onAccepted: MementoSettings.interfaceSearchTagDictionaryColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Frequency")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSearchTagFrequencyColor
                                radius: 10
                            }
                            onClicked: tagFrequencyColorDialog.open()
                        }
                        ColorDialog {
                            id: tagFrequencyColorDialog
                            title: qsTr("Select Frequency Tag Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSearchTagFrequencyColor
                            onAccepted: MementoSettings.interfaceSearchTagFrequencyColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Part of speech")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSearchTagPosColor
                                radius: 10
                            }
                            onClicked: tagPosColorDialog.open()
                        }
                        ColorDialog {
                            id: tagPosColorDialog
                            title: qsTr("Select Part of Speech Tag Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSearchTagPosColor
                            onAccepted: MementoSettings.interfaceSearchTagPosColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Search")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSearchTagSearchColor
                                radius: 10
                            }
                            onClicked: tagSearchColorDialog.open()
                        }
                        ColorDialog {
                            id: tagSearchColorDialog
                            title: qsTr("Select Search Tag Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSearchTagSearchColor
                            onAccepted: MementoSettings.interfaceSearchTagSearchColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Pitch accent dictionary")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSearchTagPitchAccentColor
                                radius: 10
                            }
                            onClicked: tagPitchAccentColorDialog.open()
                        }
                        ColorDialog {
                            id: tagPitchAccentColorDialog
                            title: qsTr("Select Pitch Accent Dictionary Tag Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSearchTagPitchAccentColor
                            onAccepted: MementoSettings.interfaceSearchTagPitchAccentColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Other")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSearchTagDefaultColor
                                radius: 10
                            }
                            onClicked: tagDefaultColorDialog.open()
                        }
                        ColorDialog {
                            id: tagDefaultColorDialog
                            title: qsTr("Select Other Tag Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSearchTagDefaultColor
                            onAccepted: MementoSettings.interfaceSearchTagDefaultColor = selectedColor
                        }
                    }
                }
            }

            SettingsBox {
                id: popupBox
                Layout.preferredWidth: root.preferredWidth
                Layout.alignment: Qt.AlignHCenter
                title: qsTr("Popup")

                ColumnLayout {
                    anchors.fill: parent
                    spacing: root.groupSpacing

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Popup width")
                        }
                        SpinBox {
                            Layout.alignment: Qt.AlignRight
                            editable: true
                            from: 1
                            to: 99999
                            value: MementoSettings.interfacePopupWidth
                            onValueModified: MementoSettings.interfacePopupWidth = value
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Popup height")
                        }
                        SpinBox {
                            Layout.alignment: Qt.AlignRight
                            editable: true
                            from: 1
                            to: 99999
                            value: MementoSettings.interfacePopupHeight
                            onValueModified: MementoSettings.interfacePopupHeight = value
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Background color (transparent for theme default)")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfacePopupBackgroundColor
                                radius: 10
                            }
                            onClicked: popupBackgroundColorDialog.open()
                        }
                        ColorDialog {
                            id: popupBackgroundColorDialog
                            title: qsTr("Select Popup Background Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfacePopupBackgroundColor
                            onAccepted: MementoSettings.interfacePopupBackgroundColor = selectedColor
                        }
                    }
                }
            }

            SettingsBox {
                id: subtitleListBox
                Layout.preferredWidth: root.preferredWidth
                Layout.alignment: Qt.AlignHCenter
                title: qsTr("Subtitle List")

                ColumnLayout {
                    anchors.fill: parent
                    spacing: root.groupSpacing

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Open in a separate window")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSubtitleListWindow
                            onClicked: MementoSettings.interfaceSubtitleListWindow = checked
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Show timestamps")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSubtitleListTimestamps
                            onClicked: MementoSettings.interfaceSubtitleListTimestamps = checked
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Primary subtitle font")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: MementoSettings.interfaceSubtitleListPrimaryFont.family
                            onClicked: subtitleListPrimaryFontDialog.open()
                        }
                        FontDialog {
                            id: subtitleListPrimaryFontDialog
                            title: qsTr("Select Subtitle List Primary Font")
                            currentFont: MementoSettings.interfaceSubtitleListPrimaryFont
                            onAccepted: MementoSettings.interfaceSubtitleListPrimaryFont = selectedFont
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Bold")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSubtitleListPrimaryFont.bold
                            onClicked: {
                                const f = MementoSettings.interfaceSubtitleListPrimaryFont;
                                f.bold = checked;
                                MementoSettings.interfaceSubtitleListPrimaryFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Italics")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSubtitleListPrimaryFont.italic
                            onClicked: {
                                const f = MementoSettings.interfaceSubtitleListPrimaryFont;
                                f.italic = checked;
                                MementoSettings.interfaceSubtitleListPrimaryFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Secondary subtitle font")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: MementoSettings.interfaceSubtitleListSecondaryFont.family
                            onClicked: subtitleListSecondaryFontDialog.open()
                        }
                        FontDialog {
                            id: subtitleListSecondaryFontDialog
                            title: qsTr("Select Subtitle List Secondary Font")
                            currentFont: MementoSettings.interfaceSubtitleListSecondaryFont
                            onAccepted: MementoSettings.interfaceSubtitleListSecondaryFont = selectedFont
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Bold")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSubtitleListSecondaryFont.bold
                            onClicked: {
                                const f = MementoSettings.interfaceSubtitleListSecondaryFont;
                                f.bold = checked;
                                MementoSettings.interfaceSubtitleListSecondaryFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Italics")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSubtitleListSecondaryFont.italic
                            onClicked: {
                                const f = MementoSettings.interfaceSubtitleListSecondaryFont;
                                f.italic = checked;
                                MementoSettings.interfaceSubtitleListSecondaryFont = f;
                            }
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Background color")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSubtitleListBackgroundColor
                                radius: 10
                            }
                            onClicked: subtitleListBackgroundColorDialog.open()
                        }
                        ColorDialog {
                            id: subtitleListBackgroundColorDialog
                            title: qsTr("Select Subtitle List Background Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSubtitleListBackgroundColor
                            onAccepted: MementoSettings.interfaceSubtitleListBackgroundColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Text color")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSubtitleListTextColor
                                radius: 10
                            }
                            onClicked: subtitleListTextColorDialog.open()
                        }
                        ColorDialog {
                            id: subtitleListTextColorDialog
                            title: qsTr("Select Subtitle List Text Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSubtitleListTextColor
                            onAccepted: MementoSettings.interfaceSubtitleListTextColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Hover color")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSubtitleListHoverColor
                                radius: 10
                            }
                            onClicked: subtitleListHoverColorDialog.open()
                        }
                        ColorDialog {
                            id: subtitleListHoverColorDialog
                            title: qsTr("Select Subtitle List Hover Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSubtitleListHoverColor
                            onAccepted: MementoSettings.interfaceSubtitleListHoverColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Selection color")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSubtitleListSelectedColor
                                radius: 10
                            }
                            onClicked: subtitleListSelectedColorDialog.open()
                        }
                        ColorDialog {
                            id: subtitleListSelectedColorDialog
                            title: qsTr("Select Subtitle List Selection Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSubtitleListSelectedColor
                            onAccepted: MementoSettings.interfaceSubtitleListSelectedColor = selectedColor
                        }
                    }

                    SettingsBoxSeparator {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Hovered selection color")
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 50
                            contentItem: Rectangle {
                                color: MementoSettings.interfaceSubtitleListSelectedHoverColor
                                radius: 10
                            }
                            onClicked: subtitleListSelectedHoverColorDialog.open()
                        }
                        ColorDialog {
                            id: subtitleListSelectedHoverColorDialog
                            title: qsTr("Select Subtitle List Hovered Selection Color")
                            options: ColorDialog.ShowAlphaChannel
                            selectedColor: MementoSettings.interfaceSubtitleListSelectedHoverColor
                            onAccepted: MementoSettings.interfaceSubtitleListSelectedHoverColor = selectedColor
                        }
                    }
                }
            }

            SettingsBox {
                id: auxiliarySearchBox
                Layout.preferredWidth: root.preferredWidth
                Layout.bottomMargin: root.groupSpacing
                Layout.alignment: Qt.AlignHCenter
                title: qsTr("Auxiliary Search")

                ColumnLayout {
                    anchors.fill: parent
                    spacing: root.groupSpacing

                    RowLayout {
                        Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft
                            text: qsTr("Open in a separate window")
                        }
                        Switch {
                            Layout.alignment: Qt.AlignRight
                            checked: MementoSettings.interfaceSearchWindow
                            onClicked: MementoSettings.interfaceSearchWindow = checked
                        }
                    }
                }
            }
        }
    }
}
