import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ripose.Memento

Item {
    id: root

    required property Term term
    required property color canvasColor

    signal searchRequested(query: string)
    signal kanjiClicked(expression: string, index: int)

    implicitHeight: rootLayout.implicitHeight

    /**
     * Check Anki to see if a term is addable.
     * Will not recheck terms that have already been checked.
     */
    function checkTermAddable()
    {
        if (!AnkiConfig.enabled ||
                !root.term ||
                root.term.ankiChecked)
        {
            return;
        }

        AnkiClient.noteAddable(root.term).then(function(result) {
            if (!result.success || !root.term)
            {
                return;
            }
            root.term.addableExpression = result.expression;
            root.term.addableReading = result.reading;
            if (!root.term.addableExpression && root.term.addableReading)
            {
                root.term.readingAsExpression = true;
            }

            let id = -1;
            let selected = false;
            for (let i = 0; i < root.term.definitions.length; ++i)
            {
                if (root.term.definitions[i].dictionaryInfo.id !== id)
                {
                    id = root.term.definitions[i].dictionaryInfo.id;
                    selected = !AnkiConfig.profile.excludeGlossaries.includes(
                                root.term.definitions[i].dictionaryInfo.name);
                }
                root.term.definitions[i].selected = selected;
            }

            root.term.ankiChecked = true;
        });
    }

    /**
     * Add the term to Anki.
     */
    function addTerm()
    {
        if (!AnkiConfig.enabled ||
                !root.term ||
                !root.term.ankiChecked ||
                root.term.ankiAdding)
        {
            return;
        }

        let selection = [];
        for (let i = 0; i < glossaryRepeater.count; ++i)
        {
            let item = glossaryRepeater.itemAt(i);
            if (item && item.selectedText.length > 0)
            {
                selection.push(item.selectedText);
            }
        }
        root.term.selection = selection;

        root.term.ankiAdding = true;
        AnkiClient.addNote(root.term).then(function(result) {
            if (!result.success)
            {
                errorDialog.title = qsTr("Error Adding Anki Note");
                errorLabel.text = result.error;
                errorDialog.open();

                if (root.term)
                {
                    root.term.ankiAdding = false;
                }
                return;
            }

            if (!root.term)
            {
                return;
            }

            if (root.term.readingAsExpression)
            {
                root.term.addableReading = false;
            }
            else
            {
                root.term.addableExpression = false;
            }
            root.term.readingAsExpression = !root.term.readingAsExpression;

            root.term.ankiAdding = false;
        });
    }

    AudioFiles {
        id: audioFiles
        term: root.term
        onLoadStateChanged: {
            if (!root.term?.autoPlay ||
                    audioFiles.loadState !== AudioFiles.LoadState.Loaded ||
                    audioFiles.files.count === 0)
            {
                return;
            }
            audioButton.clicked();
            root.term.autoPlay = false;
        }
    }

    Connections {
        target: AnkiConfig
        function onEnabledChanged() {
            root.checkTermAddable();
        }
    }

    Connections {
        target: AnkiConfig
        function onProfileChanged() {
            if (root.term)
            {
                root.term.ankiChecked = false;
                root.checkTermAddable();
            }
        }
    }

    onTermChanged: root.checkTermAddable()

    /* Fork: plain-text copies of the entry for the copy menu */
    Clipboard {
        id: clipboard
    }

    JamiShare {
        id: jamiShare
    }

    /* The distinct texts the copy and share menus offer */
    function shareTexts() {
        const texts = [
            root.expressionText(),
            root.expressionReadingText(),
            root.expressionReadingTranslationText()
        ];
        return texts.filter((text, index) => texts.indexOf(text) === index);
    }

    /* Copy the text and bring Jami to the front for pasting */
    function shareText(text) {
        clipboard.setText(text);
        if (!jamiShare.raise())
        {
            errorDialog.title = qsTr("Could Not Open Jami");
            errorLabel.text = qsTr("The jami command could not be started.");
            errorDialog.open();
        }
    }

    /**
     * Flatten one glossary item (string, text object or structured content)
     * into plain-text lines, dropping ruby readings and images.
     */
    function glossaryLines(node) {
        const blockTags = ["div", "li", "p", "br", "tr", "ol", "ul", "table"];
        const walk = function(n) {
            if (n === null || n === undefined)
            {
                return "";
            }
            if (typeof n === "string")
            {
                return n;
            }
            if (Array.isArray(n))
            {
                return n.map(walk).join("");
            }
            if (n.type === "text")
            {
                return n.text ?? "";
            }
            if (n.type === "image" || n.tag === "img" ||
                    n.tag === "rt" || n.tag === "rp")
            {
                return "";
            }
            const inner = walk(n.content);
            return blockTags.includes(n.tag) ? "\n" + inner + "\n" : inner;
        };
        return walk(node).split("\n")
            .map(line => line.trim())
            .filter(line => line.length > 0);
    }

    /* The glosses of every definition, de-duplicated, joined by "; " */
    function translationText() {
        const seen = new Set();
        const glosses = [];
        for (const definition of root.term?.definitions ?? [])
        {
            for (const item of definition.glossary ?? [])
            {
                for (const line of root.glossaryLines(item))
                {
                    const key = line.toLowerCase();
                    if (!seen.has(key))
                    {
                        seen.add(key);
                        glosses.push(line);
                    }
                }
            }
        }
        return glosses.join("; ");
    }

    function expressionText() {
        return root.term?.expression ?? "";
    }

    /* 正面衝突【しょうめんしょうとつ】 — just the expression when it is kana-only */
    function expressionReadingText() {
        const expression = root.expressionText();
        const reading = root.term?.reading ?? "";
        if (reading.length === 0 || reading === expression)
        {
            return expression;
        }
        return `${expression}【${reading}】`;
    }

    function expressionReadingTranslationText() {
        const translation = root.translationText();
        return translation.length > 0 ?
            `${root.expressionReadingText()} — ${translation}` :
            root.expressionReadingText();
    }

    Dialog {
        id: errorDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Ok

        Label {
            id: errorLabel
            width: parent.width
            wrapMode: Label.WordWrap
        }
    }

    ColumnLayout {
        id: rootLayout
        anchors.fill: parent

        RowLayout {
            id: topLayout
            Layout.fillWidth: true

            ColumnLayout {
                Layout.alignment: Qt.AlignLeft
                spacing: 0

                SelectableLabel {
                    Layout.alignment: Qt.AlignHCenter
                    visible: text.length > 0

                    font.family: MementoSettings.interfaceSearchReadingFont.family
                    font.italic: MementoSettings.interfaceSearchReadingFont.italic
                    font.underline: MementoSettings.interfaceSearchReadingFont.underline
                    font.pointSize: MementoSettings.interfaceSearchReadingFont.pointSize
                    font.weight: MementoSettings.interfaceSearchReadingFont.weight
                    font.overline: MementoSettings.interfaceSearchReadingFont.overline
                    font.strikeout: MementoSettings.interfaceSearchReadingFont.strikeout
                    font.letterSpacing: MementoSettings.interfaceSearchReadingFont.letterSpacing
                    font.wordSpacing: MementoSettings.interfaceSearchReadingFont.wordSpacing
                    font.kerning: MementoSettings.interfaceSearchReadingFont.kerning
                    font.preferShaping: MementoSettings.interfaceSearchReadingFont.preferShaping
                    font.hintingPreference: MementoSettings.interfaceSearchReadingFont.hintingPreference
                    font.styleName: MementoSettings.interfaceSearchReadingFont.styleName

                    color: MementoSettings.interfaceSearchReadingColor.a > 0 ?
                               MementoSettings.interfaceSearchReadingColor :
                               MementoPalette.text
                    text: root.term?.reading ?? ""
                }

                ExpressionLabel {
                    Layout.alignment: Qt.AlignHCenter
                    visible: text.length > 0

                    font.family: MementoSettings.interfaceSearchExpressionFont.family
                    font.italic: MementoSettings.interfaceSearchExpressionFont.italic
                    font.underline: MementoSettings.interfaceSearchExpressionFont.underline
                    font.pointSize: MementoSettings.interfaceSearchExpressionFont.pointSize
                    font.weight: MementoSettings.interfaceSearchExpressionFont.weight
                    font.overline: MementoSettings.interfaceSearchExpressionFont.overline
                    font.strikeout: MementoSettings.interfaceSearchExpressionFont.strikeout
                    font.letterSpacing: MementoSettings.interfaceSearchExpressionFont.letterSpacing
                    font.wordSpacing: MementoSettings.interfaceSearchExpressionFont.wordSpacing
                    font.kerning: MementoSettings.interfaceSearchExpressionFont.kerning
                    font.preferShaping: MementoSettings.interfaceSearchExpressionFont.preferShaping
                    font.hintingPreference: MementoSettings.interfaceSearchExpressionFont.hintingPreference
                    font.styleName: MementoSettings.interfaceSearchExpressionFont.styleName

                    color: MementoSettings.interfaceSearchExpressionColor.a > 0 ?
                               MementoSettings.interfaceSearchExpressionColor :
                               MementoPalette.text
                    expression: root.term?.expression ?? ""
                    onKanjiClicked: (expression, index) => root.kanjiClicked(expression, index)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true

                RowLayout {
                    Layout.fillWidth: true

                    Item {
                        Layout.fillWidth: true
                    }

                    ToolButton {
                        id: openAnkiButton
                        focusPolicy: Qt.NoFocus
                        visible: {
                            if (!AnkiConfig.enabled || !root.term || !root.term.ankiChecked)
                            {
                                return false;
                            }
                            else if (root.term.reading.length === 0)
                            {
                                return !root.term.addableExpression;
                            }
                            return !root.term.addableExpression || !root.term.addableReading;
                        }
                        icon.name: "view-list-details"
                        icon.source: Utils.toImageProvider("note-stack", MementoPalette.text)
                        onClicked: AnkiClient.openDuplicates(root.term).then(function(result) {
                            if (result.success)
                            {
                                return;
                            }
                            errorDialog.title = qsTr("Could Not Open Anki");
                            errorLabel.text = result.error;
                            errorDialog.open();
                        })
                    }

                    ToolButton {
                        id: kanjiKanaButton
                        focusPolicy: Qt.NoFocus
                        visible: AnkiConfig.enabled &&
                                 root.term &&
                                 root.term.ankiChecked &&
                                 root.term.reading.length > 0 &&
                                 (root.term.addableExpression || root.term.addableReading)
                        enabled: root.term &&
                                 !root.term.ankiAdding &&
                                 root.term.addableExpression &&
                                 root.term.addableReading
                        text: root.term?.readingAsExpression ? "かな" : "漢字"
                        display: AbstractButton.TextOnly
                        onClicked: {
                            if (root.term)
                            {
                                root.term.readingAsExpression = !root.term.readingAsExpression
                            }
                        }
                    }

                    ToolButton {
                        id: addAnkiButton
                        focusPolicy: Qt.NoFocus
                        visible: AnkiConfig.enabled &&
                                 root.term &&
                                 root.term.ankiChecked &&
                                 (root.term.addableExpression || root.term.addableReading)
                        enabled: audioFiles.loadState === AudioFiles.LoadState.Loaded &&
                                 root.term &&
                                 !root.term.ankiAdding
                        icon.name: "list-add"
                        icon.source: Utils.toImageProvider("add", MementoPalette.text)

                        onClicked: {
                            const audioSource = audioFiles.files.get(0);
                            if (audioSource.exists)
                            {
                                root.term.audioSourceName = audioSource.name;
                                root.term.audioUrl = audioSource.url;
                                root.term.audioSkipHash = audioSource.skipHash;
                            }
                            root.addTerm();
                        }

                        ContextMenu.menu: Menu {
                            id: addAnkiMenu

                            Instantiator {
                                model: audioFiles.files
                                delegate: MenuItem {
                                    text: model.name
                                    enabled: model.exists
                                    icon.name: model.exists ? "audio-volume-high" : "audio-volume-muted"
                                    icon.source: Utils.toImageProvider(model.exists ? "volume-on" : "volume-off", MementoPalette.text)
                                    onTriggered: {
                                        root.term.audioSourceName = model.name;
                                        root.term.audioUrl = model.url;
                                        root.term.audioSkipHash = model.skipHash;
                                        root.addTerm();
                                    }
                                }
                                onObjectAdded: (index, object) => addAnkiMenu.insertItem(index, object)
                                onObjectRemoved: (index, object) => addAnkiMenu.removeItem(object)
                            }
                        }
                    }

                    ToolButton {
                        id: copyButton
                        focusPolicy: Qt.NoFocus
                        visible: !!root.term
                        icon.name: "edit-copy"
                        ToolTip.visible: hovered
                        ToolTip.delay: 500
                        ToolTip.text: qsTr("Copy")
                        onClicked: copyMenu.popup(copyButton, 0, copyButton.height)

                        Menu {
                            id: copyMenu

                            Instantiator {
                                model: root.term ? root.shareTexts() : []
                                delegate: MenuItem {
                                    required property string modelData
                                    text: modelData
                                    onTriggered: clipboard.setText(modelData)
                                }
                                onObjectAdded: (index, object) => copyMenu.insertItem(index, object)
                                onObjectRemoved: (index, object) => copyMenu.removeItem(object)
                            }
                        }
                    }

                    ToolButton {
                        id: shareButton
                        focusPolicy: Qt.NoFocus
                        visible: !!root.term
                        icon.name: "document-share"
                        ToolTip.visible: hovered
                        ToolTip.delay: 500
                        ToolTip.text: qsTr("Share via Jami")
                        onClicked: shareMenu.popup(shareButton, 0, shareButton.height)

                        Menu {
                            id: shareMenu

                            Instantiator {
                                model: root.term ? root.shareTexts() : []
                                delegate: MenuItem {
                                    required property string modelData
                                    text: modelData
                                    onTriggered: root.shareText(modelData)
                                }
                                onObjectAdded: (index, object) => shareMenu.insertItem(index, object)
                                onObjectRemoved: (index, object) => shareMenu.removeItem(object)
                            }
                        }
                    }

                    ToolButton {
                        id: audioButton

                        /* true when audio has been requested but not yet played */
                        property bool loading: false

                        focusPolicy: Qt.NoFocus

                        enabled: !audioButton.loading &&
                                 audioFiles.loadState === AudioFiles.LoadState.Loaded &&
                                 audioFiles.files.count > 0

                        readonly property bool audible:
                            audioFiles.loadState !== AudioFiles.LoadState.Loaded ||
                            (audioFiles.files.count > 0 && audioFiles.files.get(0).exists)

                        icon.name: audioButton.audible ? "audio-volume-high" : "audio-volume-muted"
                        icon.source: Utils.toImageProvider(audioButton.audible ? "volume-on" : "volume-off", MementoPalette.text)

                        onClicked: {
                            if (!audioFiles.files.get(0).exists)
                            {
                                return;
                            }
                            audioButton.loading = true;
                            AudioPlayer.play(audioFiles.files.get(0).url, audioFiles.files.get(0).skipHash)
                                .then(
                                    function(result)
                                    {
                                        if (audioFiles.files.get(0).exists !== result)
                                        {
                                            audioFiles.files.setProperty(0, "exists", result);
                                        }
                                        audioButton.loading = false;
                                    }
                                );
                        }

                        ContextMenu.menu: Menu {
                            id: audioButtonMenu

                            Instantiator {
                                model: audioFiles.files

                                delegate: MenuItem {
                                    text: model.name
                                    enabled: model.exists
                                    icon.name: model.exists ? "audio-volume-high" : "audio-volume-muted"
                                    icon.source: Utils.toImageProvider(model.exists ? "volume-on" : "volume-off", MementoPalette.text)
                                    onTriggered: {
                                        audioButton.loading = true;
                                        AudioPlayer.play(model.url, model.skipHash)
                                            .then(
                                                function(result)
                                                {
                                                    if (model.exists !== result)
                                                    {
                                                        audioFiles.files.setProperty(index, "exists", result);
                                                    }
                                                    audioButton.loading = false;
                                                }
                                            );
                                    }
                                }

                                onObjectAdded: (index, object) => audioButtonMenu.insertItem(index, object)
                                onObjectRemoved: (index, object) => audioButtonMenu.removeItem(object)
                            }
                        }
                    }

                    ToolButton {
                        id: collapseButton
                        focusPolicy: Qt.NoFocus
                        visible: !root.term?.collapsed ?? false
                        icon.name: MementoSettings.interfaceSystemIcons ? "go-down" : null
                        icon.source: Utils.toImageProvider("arrow-drop-down", MementoPalette.text)
                        onClicked: if (root.term) root.term.collapsed = true
                    }

                    ToolButton {
                        id: uncollapseButton
                        focusPolicy: Qt.NoFocus
                        visible: root.term?.collapsed ?? false
                        icon.name: MementoSettings.interfaceSystemIcons ? "go-up" : null
                        icon.source: Utils.toImageProvider("arrow-drop-up", MementoPalette.text)
                        onClicked: if (root.term) root.term.collapsed = false
                    }
                }

                SelectableLabel {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignLeft
                    wrapMode: TextEdit.WordWrap
                    visible: text.length > 0

                    font.family: MementoSettings.interfaceSearchConjFont.family
                    font.italic: MementoSettings.interfaceSearchConjFont.italic
                    font.underline: MementoSettings.interfaceSearchConjFont.underline
                    font.pointSize: MementoSettings.interfaceSearchConjFont.pointSize
                    font.weight: MementoSettings.interfaceSearchConjFont.weight
                    font.overline: MementoSettings.interfaceSearchConjFont.overline
                    font.strikeout: MementoSettings.interfaceSearchConjFont.strikeout
                    font.letterSpacing: MementoSettings.interfaceSearchConjFont.letterSpacing
                    font.wordSpacing: MementoSettings.interfaceSearchConjFont.wordSpacing
                    font.kerning: MementoSettings.interfaceSearchConjFont.kerning
                    font.preferShaping: MementoSettings.interfaceSearchConjFont.preferShaping
                    font.hintingPreference: MementoSettings.interfaceSearchConjFont.hintingPreference
                    font.styleName: MementoSettings.interfaceSearchConjFont.styleName

                    color: MementoSettings.interfaceSearchConjColor.a > 0 ?
                               MementoSettings.interfaceSearchConjColor :
                               MementoPalette.text
                    text: root.term?.conjugationExplanation ?? ""
                }
            }
        }

        CenteredFlow {
            id: tagsLayout
            Layout.fillWidth: true
            spacing: 5
            visible: !root.term?.collapsed && (root.term?.tags.length ?? false)

            Repeater {
                model: root.term?.tags ?? []
                delegate: TagLabel {
                    required property int index
                    tag: root.term?.tags[index]
                }
            }
        }

        CenteredFlow {
            id: frequencyLayout
            Layout.fillWidth: true
            spacing: 5
            visible: !root.term?.collapsed && frequencyRepeater.count > 0

            Repeater {
                id: frequencyRepeater
                model: Utils.foldFrequencies(root.term?.frequencies)
                delegate: FrequencyLabel {
                    name: modelData.name
                    value: modelData.value
                }
            }
        }

        CenteredFlow {
            id: pitchLayout
            Layout.fillWidth: true
            spacing: 5
            visible: !root.term?.collapsed && (root.term?.pitches.length ?? false)

            Repeater {
                model: root.term?.pitches ?? []
                delegate: TermPitch {
                    required property int index
                    pitch: root.term?.pitches[index]
                }
            }
        }

        Repeater {
            id: glossaryRepeater
            Layout.fillWidth: true

            model: root.term?.definitions ?? []
            delegate: TermGlossary {
                required property int index
                term: root.term
                definition: root.term?.definitions[index]
                canvasColor: root.canvasColor
                visible: !root.term?.collapsed

                onSearchRequested: (query) => root.searchRequested(query)
            }
        }
    }
}
