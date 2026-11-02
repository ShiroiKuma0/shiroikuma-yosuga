import QtQuick
import QtQuick.Controls
import Ripose.Memento

MpvPlayer {
    id: root

    readonly property bool oscVisible:
        !root.ocrMode && (
            controls.visible ||
            (!Features.isMacos && menu.visible)
        )
    readonly property bool oscHovered:
        !root.ocrMode && (
            subtitleHover.hovered ||
            (!Features.isMacos && menu.anyHovered) ||
            controlsHover.hovered
        )

    readonly property bool pause: root.state.pause

    property point cursorPosition: Qt.point(0, 0)

    property bool ocrMode: false

    /* Fork: true while the player reopens a file after a subtitle edit —
     * the window must not autofit and playback must not auto-start */
    readonly property bool subtitleReloading: subtitleEditor.reloading

    /* Fork: correction mode (shiroikuma-yosuga --review=…) */
    readonly property alias reviewSession: reviewSession

    signal auxiliarySearchRequested(string text)

    enum OscVisibility
    {
        OscAuto,
        OscVisible,
        OscHidden
    }

    property int oscVisibility: Player.OscAuto

    /**
     * Shows the OSC with fade in.
     */
    function showOsc() {
        if (root.ocrMode)
        {
            return;
        }

        if (root.oscVisibility === Player.OscHidden)
        {
            return;
        }

        if (!Features.isMacos)
        {
            menuFadeOut.stop();
            menuFadeIn.start();
        }
        controlsFadeOut.stop();
        controlsFadeIn.start();
    }

    /**
     * Hides the OSC with fade out.
     *
     * @param force Unconditionally hide the OSC if true.
     */
    function hideOsc(force) {
        if (!force && root.oscVisibility === Player.OscVisible)
        {
            return;
        }

        if (!Features.isMacos)
        {
            menuFadeIn.stop();
            menuFadeOut.start();
        }
        controlsFadeIn.stop();
        controlsFadeOut.start();
    }

    /**
     * Put the player into OCR mode.
     */
    function startOcrMode() {
        ocrOverlay.start();
    }

    /**
     * Get the player out of OCR mode.
     */
    function cancelOcrMode() {
        ocrOverlay.cancel();
    }

    /**
     * Handles mouse movement.
     */
    function mouseMoved(x, y) {
        root.controller.sendMouse(x, y);
        cursorTimer.restart();
    }

    onFileLoaded: {
        if (MementoSettings.searchHideMpvSubs)
        {
            root.controller.setSubtitleVisibility(false);
        }
        root.applySecondarySubtitleOffset();
    }

    /* Fork: keep mpv's secondary subtitle position in sync with the top
     * offset setting. */
    function applySecondarySubtitleOffset() {
        root.controller.setSecondarySubtitlePos(
            MementoSettings.interfaceSubtitleSecondaryOffset * 100);
    }

    Connections {
        target: MementoSettings
        function onInterfaceSubtitleSecondaryOffsetChanged() {
            root.applySecondarySubtitleOffset();
        }
    }

    Keys.onPressed: function(event) {
        if (root.ocrMode && event.key === Qt.Key_Escape)
        {
            root.cancelOcrMode();
            event.accepted = true;
            return;
        }
        /* Direct player input means the user is done with any held OCR
         * frame */
        if (!root.ocrMode)
        {
            OcrController.releaseFrame();
        }
        root.controller.sendKeyPress(event.key, event.modifiers);
    }

    onCursorPositionChanged: root.mouseMoved(root.cursorPosition.x, root.cursorPosition.y)

    onOscVisibilityChanged: {
        switch (root.oscVisibility)
        {
        case Player.OscAuto:
            interactiveTimer.restart();
            break;

        case Player.OscVisible:
            root.showOsc();
            break;

        case Player.OscHidden:
            root.hideOsc();
            break;
        }
    }

    Action {
        id: cycleOscVisibilityAction
        shortcut: MementoSettings.keybinds.profile?.oscVisibility
        onTriggered: {
            const oscVisibilityText = qsTr("OSC Visibility: %1");

            switch (root.oscVisibility)
            {
            case Player.OscAuto:
                root.oscVisibility = Player.OscVisible;
                root.controller.showText(oscVisibilityText.arg(qsTr("Visible")));
                break;

            case Player.OscVisible:
                root.oscVisibility = Player.OscHidden;
                root.controller.showText(oscVisibilityText.arg(qsTr("Hidden")));
                break;

            case Player.OscHidden:
                root.oscVisibility = Player.OscAuto;
                root.controller.showText(oscVisibilityText.arg(qsTr("Auto")));
                break;
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        propagateComposedEvents: true
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        cursorShape: root.oscHovered ? Qt.ArrowCursor : cursorTimer.cursorShape
        enabled: !root.ocrMode

        onPositionChanged: function(event) {
            root.cursorPosition = Qt.point(event.x, event.y);
            event.accepted = false;
        }

        onClicked: function(event) {
            /* This hack makes it so keys are still handled and the player has focus */
            root.forceActiveFocus();
            root.focus = false;
            root.forceActiveFocus();

            /* Fork: the mouse forward button (BTN_EXTRA) starts OCR */
            if (event.button === Qt.ForwardButton)
            {
                root.startOcrMode();
                event.accepted = true;
                return;
            }

            definitionPopup.clearResults();
            OcrController.releaseFrame();
            root.controller.sendMouseButton(event.x, event.y, event.button, true);
            event.accepted = false;
        }

        onDoubleClicked: function(event) {
            root.controller.sendMouseButton(event.x, event.y, event.button, false);
            event.accepted = false;
        }
    }

    /* This handler is needed because the itemCursor Items block
     * onPositionChanged in MouseArea */
    HoverHandler {
        id: hoverHandler

        readonly property point position: hoverHandler.point.position

        onPositionChanged: root.cursorPosition = Qt.point(position.x, position.y)
    }

    WheelHandler {
        enabled: !root.ocrMode
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            root.controller.sendWheel(event.x, event.y, event.angleDelta);
        }
    }

    Timer {
        id: interactiveTimer
        interval: MementoSettings.behaviorOscDuration
        repeat: false
        running: false
        onTriggered: {
            if (!root.oscHovered && !definitionPopup.visible)
            {
                root.hideOsc();
            }
        }
    }

    MoveTimer {
        id: minMouseMoveTimer
        running: !root.ocrMode
        minMovement: MementoSettings.behaviorOscMinMove
        cursorPosition: root.cursorPosition
        onMouseMoved: {
            interactiveTimer.restart();
            if (!root.oscVisible)
            {
                root.showOsc();
            }
        }
    }

    CursorTimer {
        id: cursorTimer
        player: root
    }

    onOscHoveredChanged: {
        interactiveTimer.restart();
        cursorTimer.restart();
    }

    /* Inhibit the screensaver during playback */
    Screensaver {
        id: screensaver
    }
    onPauseChanged: {
        if (root.state.pause)
        {
            screensaver.uninhibit();
        }
        else
        {
            screensaver.inhibit(qsTr("Playing media"));
        }
    }

    /* Implements subtitle cursor show */
    Item {
        id: itemCursorSubtitleShow

        readonly property bool show: hoverCursorSubtitleShow.hovered ||
                                     subtitleHover.hovered ||
                                     subtitleText.hoverIndex !== -1 || // This prevents flashing on edges
                                     controlsHover.hovered

        anchors {
            left: root.left
            right: root.right
            bottom: root.bottom
        }
        height: root.height * 0.25
        focusPolicy: Qt.NoFocus
        visible: MementoSettings.behaviorSubtitleCursorShow

        HoverHandler {
            id: hoverCursorSubtitleShow
        }
    }

    /* Implements secondary subtitle cursor show */
    Item {
        id: itemCursorSecondarySubtitleShow

        readonly property bool show:
            hoverCursorSecondarySubtitleShow.hovered ||
            (!Features.isMacos && menu.anyHovered)

        anchors {
            left: root.left
            right: root.right
            top: root.top
        }
        height: root.height * 0.25
        focusPolicy: Qt.NoFocus
        visible: MementoSettings.behaviorSecondarySubtitleCursorShow

        HoverHandler {
            id: hoverCursorSecondarySubtitleShow
        }

        /**
         * Toggles secondary subtitle visibility.
         */
        function updateSeconarySubtitleVisibility() {
            if (itemCursorSecondarySubtitleShow.visible)
            {
                root.controller.setSecondarySubtitleVisibility(show);
            }
        }

        onShowChanged: updateSeconarySubtitleVisibility()
        onVisibleChanged: updateSeconarySubtitleVisibility()
    }

    /* Fork: sync the secondary subtitle's end with the primary one. mpv only
     * renders the secondary (e.g. English) line inside its own timing window,
     * so when it ends before the primary (e.g. Japanese) line — typical with
     * pause-at-subtitle-end — hovering the top shows nothing. Cache the last
     * secondary line and render it ourselves while the primary line it
     * overlapped is still on screen and mpv has nothing to draw. */
    Text {
        id: heldSecondarySubtitle

        property string cachedText: ""
        property real cachedStart: 0
        property real cachedEnd: 0

        /* mpv's sub-* style options — the same ones mpv itself renders the
         * secondary subtitle with (sub-font, sub-color, mpv.conf included). */
        property var mpvStyle: ({})

        readonly property bool overlapsPrimary:
            cachedText !== "" &&
            root.state.subtitle.text !== "" &&
            cachedStart < root.state.subtitle.endTime &&
            cachedEnd > root.state.subtitle.startTime

        anchors {
            horizontalCenter: root.horizontalCenter
            top: root.top

            /* Like the primary subtitle's bottomMargin: the offset is
             * absolute, only clamped so the menu never obscures the text —
             * an offset that already clears the menu never moves. */
            topMargin: {
                let minValue =
                    !Features.isMacos && menu.visible ? menu.height : 0;
                let margin = root.height *
                    MementoSettings.interfaceSubtitleSecondaryOffset;
                return Math.max(margin, minValue);
            }
        }
        width: Math.min(implicitWidth, root.width * 0.9)

        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        color: mpvColor(mpvStyle.color, "white")
        style: Text.Outline
        styleColor: mpvColor(mpvStyle.borderColor, "black")
        font.family: mpvStyle.font ? mpvStyle.font : "sans-serif"
        font.bold: mpvStyle.bold ?? false
        font.italic: mpvStyle.italic ?? false
        /* mpv sizes subtitles as sub-font-size * sub-scale relative to a
         * 720px-tall window */
        font.pixelSize: Math.max(
            1,
            root.height * ((mpvStyle.fontSize ?? 55) * (mpvStyle.scale ?? 1)) / 720)
        padding: backgroundRect.visible ? font.pixelSize * 0.15 : 0

        text: cachedText
        visible: MementoSettings.behaviorSecondarySubtitleCursorShow &&
                 itemCursorSecondarySubtitleShow.show &&
                 root.state.secondarySid !== 0 &&
                 root.state.secondarySubtitle.text === "" &&
                 overlapsPrimary &&
                 !root.ocrMode
        onVisibleChanged: {
            if (visible)
            {
                heldSecondarySubtitle.mpvStyle = root.controller.subtitleStyle();
            }
        }

        /* mpv color strings come as #RRGGBB / #AARRGGBB or r/g/b[/a] floats */
        function mpvColor(value, fallback) {
            if (!value)
            {
                return fallback;
            }
            if (value.startsWith("#"))
            {
                return value;
            }
            const parts = value.split("/").map(Number);
            if (parts.length >= 3 && !parts.some(isNaN))
            {
                return Qt.rgba(
                    parts[0], parts[1], parts[2],
                    parts.length > 3 ? parts[3] : 1);
            }
            return fallback;
        }

        function cacheSubtitle() {
            const sub = root.state.secondarySubtitle;
            if (sub.text !== "")
            {
                heldSecondarySubtitle.cachedText = sub.text;
                heldSecondarySubtitle.cachedStart = sub.startTime;
                heldSecondarySubtitle.cachedEnd = sub.endTime;
            }
        }

        function clearCache() {
            heldSecondarySubtitle.cachedText = "";
        }

        Rectangle {
            id: backgroundRect

            /* mpv only draws a box behind the text in the box border
             * styles — with the default outline-and-shadow the (opaque
             * black by default) sub-back-color is never painted, so
             * neither do we. background-box boxes use sub-back-color,
             * opaque-box boxes the outline color. */
            readonly property color backColor: {
                const style = heldSecondarySubtitle.mpvStyle;
                if (style.borderStyle === "background-box")
                {
                    return heldSecondarySubtitle.mpvColor(
                        style.backColor, "transparent");
                }
                if (style.borderStyle === "opaque-box")
                {
                    return heldSecondarySubtitle.mpvColor(
                        style.borderColor, "transparent");
                }
                return "transparent";
            }

            anchors.fill: parent
            z: -1
            color: backColor
            visible: backColor.a > 0
        }

        Connections {
            target: root.state.secondarySubtitle
            function onTextChanged() { heldSecondarySubtitle.cacheSubtitle(); }
        }

        Connections {
            target: root.state
            function onPathChanged() { heldSecondarySubtitle.clearCache(); }
            function onSecondarySidChanged() { heldSecondarySubtitle.clearCache(); }
        }
    }

    Popup {
        id: definitionPopup

        property point cursorAtSearch: Qt.point(0, 0)
        property int lastHoverIndex: -1
        /* True when the current results came from OCR rather than the
         * subtitle line; anchors the popup at the OCR selection instead */
        property bool ocrSearch: false
        /* The OCR selection rect the popup is anchored to */
        property rect ocrSelection: Qt.rect(0, 0, 0, 0)

        readonly property int playerWidth: root.width
        readonly property int playerHeight: root.height
        readonly property bool paused: root.state.pause
        readonly property real position: controls.position

        readonly property bool shouldOpen: dictionarySearch.terms.length > 0 || dictionarySearch.kanji

        x: {
            let idealPosition = cursorAtSearch.x - (width / 2);
            idealPosition = Math.max(idealPosition, 0);
            idealPosition = Math.min(idealPosition, root.width - width);
            return idealPosition;
        }
        y: {
            if (ocrSearch)
            {
                /* Above the selection so the scanned text stays readable;
                 * below it only when there is no room */
                let idealPosition = ocrSelection.y - height - 8;
                if (idealPosition < 0)
                {
                    idealPosition = ocrSelection.y + ocrSelection.height + 8;
                }
                idealPosition = Math.min(idealPosition, root.height - height);
                return Math.max(idealPosition, 0);
            }
            let idealPosition = subtitleText.y - height;
            if (idealPosition < 0)
            {
                idealPosition = subtitleText.y + subtitleText.height;
            }
            return idealPosition;
        }
        width: MementoSettings.interfacePopupWidth
        height: MementoSettings.interfacePopupHeight
        closePolicy: Popup.NoAutoClose

        onShouldOpenChanged: definitionPopup.shouldOpen ? definitionPopup.open() : definitionPopup.close()
        onOpened: {
            const popupFits = x >= 0 &&
                            y >= 0 &&
                            x + width <= parent.width &&
                            y + height <= parent.height;
            if (!popupFits)
            {
                definitionPopup.close();
            }
        }
        onClosed: {
            definitionPopup.clearResults();
            interactiveTimer.restart();
        }

        onPlayerWidthChanged: definitionPopup.clearResults()
        onPlayerHeightChanged: definitionPopup.clearResults()
        /* OCR results come from a held frame, so playback noise from mpv
         * scripts (auto-pause, sub skipping) must not clear them */
        onPausedChanged: {
            if (!definitionPopup.ocrSearch)
            {
                definitionPopup.clearResults();
            }
        }
        onPositionChanged: {
            if (!definitionPopup.ocrSearch)
            {
                definitionPopup.clearResults();
            }
        }

        Rectangle {
            id: dictionaryBorderRectangle
            anchors.fill: parent
            color: "transparent"
            border.color: MementoPalette.border
            border.width: Features.isUnix ? 1 : 0

            DefinitionPage {
                id: definitionPage
                anchors.fill: parent
                anchors.margins: dictionaryBorderRectangle.border.width
                search: dictionarySearch

                /**
                 * Selects the longest cloze match or clears the selection on clear.
                 */
                function updateSelection() {
                    if (definitionPopup.ocrSearch ||
                        (dictionarySearch.terms.length === 0 &&
                         dictionarySearch.kanji === null))
                    {
                        subtitleText.clearSelection();
                        return;
                    }
                    let selectionLength = 0;
                    if (dictionarySearch.terms.length > 0)
                    {
                        selectionLength =
                            dictionarySearch.terms[0].clozeBody.length;
                    }
                    else if (dictionarySearch.kanji !== null)
                    {
                        selectionLength = 1;
                    }
                    subtitleText.select(
                                subtitleText.hoverIndex,
                                subtitleText.hoverIndex + selectionLength);
                }

                onClosePressed: definitionPopup.clearResults()

                Connections {
                    target: dictionarySearch

                    function onKanjiChanged() {
                        definitionPage.updateSelection();
                    }

                    function onTermsChanged() {
                        definitionPage.updateSelection();
                    }
                }
            }
        }

        DictionarySearch {
            id: dictionarySearch
        }

        Timer {
            id: definitionPopupTimer
            interval: MementoSettings.searchDelay
            running: false
            repeat: false
            onTriggered: {
                if (subtitleText.hoverIndex !== definitionPopup.lastHoverIndex)
                {
                    return;
                }
                else if (!root.state.pause)
                {
                    return;
                }

                Qt.callLater(definitionPopup.search, subtitleText.hoverIndex);
            }
        }

        /**
         * Starts the search timer and sets start state.
         */
        function startSearchTimer() {
            if (subtitleText.hoverIndex === definitionPopup.lastHoverIndex)
            {
                return;
            }
            definitionPopup.lastHoverIndex = subtitleText.hoverIndex;
            if (subtitleText.hoverIndex < 0)
            {
                return;
            }
            else if (!root.state.pause)
            {
                return;
            }
            definitionPopupTimer.restart();
        }

        /**
         * Executes a search using the hover index of the subtitle text.
         * @param index The index into the subtitle text to search.
         */
        function search(index) {
            if (index < 0 || index >= subtitleText.text.length)
            {
                return;
            }

            definitionPopup.ocrSearch = false;
            definitionPopup.cursorAtSearch = root.cursorPosition;
            definitionPage.resetStack();

            const text = subtitleText.text;
            const query = text.substring(index);
            dictionarySearch.searchTerms(query, text, index);
            dictionarySearch.searchKanji(text.charAt(index), text, index);
        }

        /**
         * Executes a search using text recognized by OCR. The popup is
         * anchored above the OCR selection rather than the subtitle line.
         * @param text The recognized text to search.
         * @param selection The OCR selection in player coordinates.
         */
        function searchOcrText(text, selection) {
            if (text.length === 0)
            {
                return;
            }

            definitionPopup.ocrSearch = true;
            definitionPopup.ocrSelection = selection;
            definitionPopup.cursorAtSearch = Qt.point(
                selection.x + selection.width / 2, selection.y);
            definitionPage.resetStack();

            dictionarySearch.searchTerms(text, text, 0);
            dictionarySearch.searchKanji(text.charAt(0), text, 0);
        }

        /**
         * Clears search results.
         */
        function clearResults() {
            definitionPopup.lastHoverIndex = -1;
            definitionPage.resetStack();
            dictionarySearch.clearResults();
        }
    }

    SubtitleText {
        id: subtitleText

        readonly property var regexFilter: Utils.safeRegex(MementoSettings.searchRemoveRegex, "g")

        /**
         * Toggles mpv subtitles if searchHideMpvSubs is enabled.
         */
        function toggleMpvSubs() {
            if (!MementoSettings.searchHideMpvSubs)
            {
                return;
            }
            root.controller.setSubtitleVisibility(!subtitleText.visible);
        }

        anchors {
            horizontalCenter: root.horizontalCenter
            bottom: root.bottom

            /* Makes sure UI elements don't obscure the subtitles or that they go offscreen */
            bottomMargin: {
                let minValue = controls.visible ? controls.height : 0;
                let maxValue = root.height - subtitleText.height;
                if (!Features.isMacos && menu.visible)
                {
                    maxValue -= menu.height;
                }
                let margin = root.height * MementoSettings.interfaceSubtitleOffset;
                margin = Math.max(margin, minValue);
                margin = Math.min(margin, maxValue);
                return margin;
            }
        }

        /* Prevents text from being wider than the window */
        transformOrigin: Item.Bottom
        scale: subtitleText.width > root.width ? (root.width / subtitleText.width) : 1.0

        font.family: MementoSettings.interfaceSubtitleFont.family
        font.bold: MementoSettings.interfaceSubtitleFont.bold
        font.italic: MementoSettings.interfaceSubtitleFont.italic
        font.underline: MementoSettings.interfaceSubtitleFont.underline
        font.pixelSize: root.height * MementoSettings.interfaceSubtitleScale
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
        furiganaRatio: MementoSettings.interfaceSubtitleFuriganaRatio

        text: {
            /* Implements regex filtering */
            let text = root.state.subtitle.text.replace(subtitleText.regexFilter, "");
            /* Implements replace new lines */
            if (MementoSettings.searchReplaceNewlines)
            {
                text = text.replace(/\n/g, MementoSettings.searchReplaceNewlinesWith);
            }
            return text;
        }

        visible: {
            if (root.ocrMode)
            {
                return false;
            }

            /* Implement unconditional hiding of subtitles */
            if (!menu.showSubtitles)
            {
                return false;
            }

            /* Implement hide Memento subtitles while playing media */
            if (MementoSettings.searchHideSubs && !root.state.pause)
            {
                return false;
            }

            /* Implements subtitle cursor show */
            if (MementoSettings.behaviorSubtitleCursorShow)
            {
                return itemCursorSubtitleShow.show;
            }

            return true;
        }

        /* Implements hide mpv subtitles */
        onVisibleChanged: subtitleText.toggleMpvSubs()
        Connections {
            target: MementoSettings
            function onSearchHideMpvSubsChanged() {
                subtitleText.toggleMpvSubs();
            }
        }

        Clipboard {
            id: clipboard
        }
        onDoubleClicked: clipboard.setText(text)

        /* Fork: right-click edits the subtitle inline */
        opacity: subtitleEditBox.editing ? 0 : 1
        enabled: !subtitleEditBox.editing
        onRightClicked: subtitleEditBox.begin()

        HoverHandler {
            id: subtitleHover

            /* Implements auto pause on hover */
            onHoveredChanged: {
                if (subtitleHover.hovered && MementoSettings.searchPauseOnHover)
                {
                    root.controller.pause()
                }
            }
        }

        /* Implement searching */
        onHoverIndexChanged: {
            switch (MementoSettings.searchMethod)
            {
            case MementoSetting.SearchMethodHover:
                definitionPopup.startSearchTimer();
                break;

            case MementoSetting.SearchMethodModifier:
                if (KeyTracker.modifierHeld(MementoSettings.searchModifier))
                {
                    Qt.callLater(definitionPopup.search, subtitleText.hoverIndex);
                }
                break;
            }
        }
        onMiddleClicked: {
            if (MementoSettings.searchMiddleMouseScan)
            {
                Qt.callLater(definitionPopup.search, subtitleText.hoverIndex);
            }
        }

        Connections {
            target: KeyTracker
            function onModifiersChanged() {
                if (MementoSettings.searchMethod === MementoSetting.SearchMethodModifier &&
                        subtitleHover.hovered &&
                        KeyTracker.modifierHeld(MementoSettings.searchModifier))
                {
                    Qt.callLater(definitionPopup.search, subtitleText.hoverIndex);
                }
            }
        }
    }

    /* Fork: inline subtitle editor. Right-click the subtitle, edit, Enter
     * saves (Shift+Enter breaks the line), Escape or clicking elsewhere
     * cancels. The edit is written back to the external subtitle file or
     * muxed back into the Matroska file the track lives in. */
    SubtitleEditor {
        id: subtitleEditor
        player: root
        lists: SubtitleLists
        requiredPath: reviewSession.active ? reviewSession.workingPath : ""

        onFailed: function(message) {
            subtitleSaveDialog.error = message;
            subtitleSaveDialog.open();
        }
    }

    /* Fork: progress of a subtitle save and the reload after it */
    Popup {
        id: subtitleSaveDialog

        property string error: ""

        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(parent ? parent.width - 32 : 460, 460)
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose
        padding: 20

        onClosed: {
            subtitleSaveDialog.error = "";
            root.forceActiveFocus();
        }

        /* A save that ends at once (a plain subtitle file) shows no dialog */
        Timer {
            id: subtitleSaveDialogDelay
            interval: 250
            running: subtitleEditor.busy
            onTriggered: {
                if (subtitleEditor.busy)
                {
                    subtitleSaveDialog.open();
                }
            }
        }
        Connections {
            target: subtitleEditor
            function onBusyChanged() {
                if (!subtitleEditor.busy && subtitleSaveDialog.error === "")
                {
                    subtitleSaveDialog.close();
                }
            }
        }

        background: Rectangle {
            color: MementoPalette.window
            border.color: MementoPalette.border
            border.width: 1
        }

        contentItem: Item {
            implicitWidth: saveDialogColumn.implicitWidth
            implicitHeight: saveDialogColumn.implicitHeight
            focus: true

            /* Nothing reaches the player while the file is being rewritten */
            Keys.onShortcutOverride: function(event) {
                event.accepted = true;
            }
            Keys.onPressed: function(event) {
                if (subtitleSaveDialog.error !== "" &&
                        (event.key === Qt.Key_Return || event.key === Qt.Key_Enter ||
                         event.key === Qt.Key_Escape))
                {
                    subtitleSaveDialog.close();
                }
                event.accepted = true;
            }

            Column {
                id: saveDialogColumn
                width: parent.width
                spacing: 12

                Label {
                    width: parent.width
                    text: subtitleSaveDialog.error !== "" ?
                        qsTr("Subtitle not saved") : qsTr("Saving subtitle")
                    font.bold: true
                    color: MementoPalette.windowText
                }

                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: subtitleSaveDialog.error !== "" ?
                        subtitleSaveDialog.error : subtitleEditor.stage
                    color: MementoPalette.windowText
                }

                ProgressBar {
                    id: subtitleSaveProgress
                    width: parent.width
                    visible: subtitleSaveDialog.error === ""
                    from: 0
                    to: 1
                    value: Math.max(0, subtitleEditor.progress)
                    indeterminate: subtitleEditor.progress < 0

                    background: Rectangle {
                        implicitHeight: 10
                        color: MementoPalette.base
                        border.color: MementoPalette.windowText
                        border.width: 1
                    }

                    contentItem: Item {
                        implicitHeight: 10
                        clip: true

                        Rectangle {
                            id: subtitleSaveProgressFill
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 2
                            x: subtitleSaveProgress.indeterminate ? 0 : 2
                            width: subtitleSaveProgress.indeterminate ?
                                parent.width * 0.25 :
                                Math.max(0, subtitleSaveProgress.visualPosition * (parent.width - 4))
                            color: MementoPalette.windowText

                            NumberAnimation on x {
                                running: subtitleSaveProgress.indeterminate &&
                                         subtitleSaveDialog.visible
                                from: -subtitleSaveProgressFill.width
                                to: subtitleSaveProgress.width
                                duration: 1200
                                loops: Animation.Infinite
                            }
                        }
                    }
                }

                Button {
                    anchors.right: parent.right
                    visible: subtitleSaveDialog.error !== ""
                    text: qsTr("OK")
                    onClicked: subtitleSaveDialog.close()
                }
            }
        }
    }

    Rectangle {
        id: subtitleEditBox

        property bool editing: false
        property bool resumeAfter: false
        property string originalText: ""
        property real originalStart: 0
        property real originalEnd: 0
        property real originalDelay: 0

        /**
         * Opens the editor on the current primary subtitle and pauses.
         */
        function begin() {
            if (root.state.subtitle.text === "" || subtitleEditor.busy)
            {
                return;
            }
            subtitleEditBox.originalText = root.state.subtitle.text;
            subtitleEditBox.originalStart = root.state.subtitle.startTime;
            subtitleEditBox.originalEnd = root.state.subtitle.endTime;
            subtitleEditBox.originalDelay = root.state.subtitle.delay;
            subtitleEditBox.resumeAfter = !root.state.pause;
            root.controller.pause();

            definitionPopup.clearResults();
            definitionPopup.close();

            subtitleEditArea.text = subtitleEditBox.originalText;
            subtitleEditBox.editing = true;
            subtitleEditArea.forceActiveFocus();
            subtitleEditArea.cursorPosition = subtitleEditArea.length;
        }

        /**
         * Closes the editor, saving the text if commit is true.
         * @param commit true to save the edit, false to discard it.
         */
        function finish(commit) {
            if (!subtitleEditBox.editing)
            {
                return;
            }
            subtitleEditBox.editing = false;
            root.forceActiveFocus();
            if (commit)
            {
                /* The editor resumes playback itself once the file has been
                 * saved and reloaded (or the save refused) */
                subtitleEditor.save(
                    subtitleEditBox.originalText,
                    subtitleEditBox.originalStart,
                    subtitleEditBox.originalEnd,
                    subtitleEditBox.originalDelay,
                    subtitleEditArea.text,
                    subtitleEditBox.resumeAfter
                );
            }
            else if (subtitleEditBox.resumeAfter)
            {
                root.controller.play();
            }
        }

        visible: editing
        anchors {
            horizontalCenter: root.horizontalCenter
            bottom: subtitleText.bottom
        }
        width: Math.min(
            root.width - 32,
            Math.max(subtitleText.width * subtitleText.scale + 48, root.width * 0.4)
        )
        height: subtitleEditArea.implicitHeight
        color: Qt.rgba(0, 0, 0, 0.75)
        border.color: "#FFFF00"
        border.width: 2
        radius: 6

        TextArea {
            id: subtitleEditArea

            anchors.fill: parent
            padding: 8
            background: null
            wrapMode: TextEdit.Wrap
            horizontalAlignment: TextEdit.AlignHCenter
            selectByMouse: true
            persistentSelection: true
            color: MementoSettings.interfaceSubtitleColor
            selectionColor: MementoPalette.highlight
            font.family: subtitleText.font.family
            font.bold: subtitleText.font.bold
            font.italic: subtitleText.font.italic
            font.weight: subtitleText.font.weight
            font.pixelSize: Math.max(12, subtitleText.font.pixelSize * subtitleText.scale)

            /* Every key belongs to the editor while it is open — no
             * player shortcut fires mid-edit */
            Keys.onShortcutOverride: function(event) {
                event.accepted = true;
            }
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape)
                {
                    subtitleEditBox.finish(false);
                    event.accepted = true;
                }
                else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) &&
                         !(event.modifiers & Qt.ShiftModifier))
                {
                    subtitleEditBox.finish(true);
                    event.accepted = true;
                }
            }
            onActiveFocusChanged: {
                if (!activeFocus)
                {
                    subtitleEditBox.finish(false);
                }
            }
        }
    }

    /* Fork: correction mode. Steps through the review cues the subtitles
     * tool left beside the film; the working copy of its 日本語 track is the
     * primary subtitle, so edits land there; Fix MKV writes it back. */
    ReviewSession {
        id: reviewSession
        player: root

        onLoadRequested: function(film) {
            root.controller.loadFile([film]);
        }
        onConfirmRequested: function(message) {
            reviewDialog.show("confirm", qsTr("The 日本語 track has changed"), message);
        }
        onFailed: function(message) {
            reviewDialog.show("error", qsTr("Correction mode"), message);
        }
        onFixed: function(message) {
            reviewDialog.show("info", qsTr("Fix MKV"), message);
        }
    }

    Connections {
        target: root
        function onFileLoaded(w, h, path) {
            if (reviewSession.active && !subtitleEditor.reloading)
            {
                reviewSession.handleFileLoaded(path);
            }
        }
    }

    Rectangle {
        id: reviewPanel

        visible: reviewSession.active && !root.ocrMode
        x: 12
        y: (menu.visible ? menu.height : 0) + 12
        z: 1
        width: Math.min(root.width * 0.38, 520)
        height: reviewPanelColumn.implicitHeight + 20
        color: Qt.rgba(0, 0, 0, 0.75)
        border.color: "#FFFF00"
        border.width: 2
        radius: 6

        /* Clicks on the panel stay off the player */
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
        }

        Column {
            id: reviewPanelColumn
            x: 10
            y: 10
            width: parent.width - 20
            spacing: 8

            Row {
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (reviewSession.current + 1) + "/" + reviewSession.count
                    color: "#FFFF00"
                    font.pixelSize: 28
                    font.bold: true
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("%1 of %2 checked")
                        .arg(reviewSession.checkedCount).arg(reviewSession.count)
                    color: "#FFFF00"
                    font.pixelSize: 13
                }
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: reviewSession.note
                color: "white"
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                font.pixelSize: 16
            }

            Row {
                spacing: 8

                Button {
                    text: "◀"
                    focusPolicy: Qt.NoFocus
                    enabled: reviewSession.current > 0 && !reviewSession.busy
                    onClicked: reviewSession.previous()
                }

                Button {
                    text: "▶"
                    focusPolicy: Qt.NoFocus
                    enabled: reviewSession.current + 1 < reviewSession.count &&
                             !reviewSession.busy
                    onClicked: reviewSession.next()
                }

                Button {
                    text: qsTr("Fix MKV")
                    focusPolicy: Qt.NoFocus
                    visible: reviewSession.allChecked
                    enabled: !reviewSession.busy && !subtitleEditor.busy
                    onClicked: reviewSession.fixMkv()
                }
            }
        }
    }

    /* Fork: progress, questions and results of correction mode */
    Popup {
        id: reviewDialog

        /* "progress", "error", "confirm" or "info" */
        property string kind: "progress"
        property string title: ""
        property string message: ""

        function show(kind, title, message) {
            reviewDialog.kind = kind;
            reviewDialog.title = title;
            reviewDialog.message = message;
            reviewDialog.open();
        }

        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(parent ? parent.width - 32 : 520, 520)
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose
        padding: 20

        onClosed: root.forceActiveFocus()

        Connections {
            target: reviewSession
            function onBusyChanged() {
                if (reviewSession.busy)
                {
                    reviewDialog.show(
                        "progress",
                        qsTr("Correction mode"),
                        ""
                    );
                }
                else if (reviewDialog.kind === "progress")
                {
                    reviewDialog.close();
                }
            }
        }

        background: Rectangle {
            color: MementoPalette.window
            border.color: "#FFFF00"
            border.width: 2
        }

        contentItem: Item {
            implicitWidth: reviewDialogColumn.implicitWidth
            implicitHeight: reviewDialogColumn.implicitHeight
            focus: true

            Keys.onShortcutOverride: function(event) {
                event.accepted = true;
            }
            Keys.onPressed: function(event) {
                if ((reviewDialog.kind === "error" || reviewDialog.kind === "info") &&
                        (event.key === Qt.Key_Return || event.key === Qt.Key_Enter ||
                         event.key === Qt.Key_Escape))
                {
                    reviewDialog.close();
                }
                event.accepted = true;
            }

            Column {
                id: reviewDialogColumn
                width: parent.width
                spacing: 12

                Label {
                    width: parent.width
                    text: reviewDialog.title
                    font.bold: true
                    color: MementoPalette.windowText
                }

                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: reviewDialog.kind === "progress" ?
                        reviewSession.stage : reviewDialog.message
                    color: MementoPalette.windowText
                }

                ProgressBar {
                    id: reviewProgress
                    width: parent.width
                    visible: reviewDialog.kind === "progress"
                    from: 0
                    to: 1
                    value: Math.max(0, reviewSession.progress)
                    indeterminate: reviewSession.progress < 0

                    background: Rectangle {
                        implicitHeight: 10
                        color: MementoPalette.base
                        border.color: MementoPalette.windowText
                        border.width: 1
                    }

                    contentItem: Item {
                        implicitHeight: 10
                        clip: true

                        Rectangle {
                            id: reviewProgressFill
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 2
                            x: reviewProgress.indeterminate ? 0 : 2
                            width: reviewProgress.indeterminate ?
                                parent.width * 0.25 :
                                Math.max(0, reviewProgress.visualPosition * (parent.width - 4))
                            color: MementoPalette.windowText

                            NumberAnimation on x {
                                running: reviewProgress.indeterminate &&
                                         reviewDialog.visible
                                from: -reviewProgressFill.width
                                to: reviewProgress.width
                                duration: 1200
                                loops: Animation.Infinite
                            }
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    spacing: 8
                    visible: reviewDialog.kind === "confirm"

                    Button {
                        text: qsTr("Re-extract")
                        onClicked: {
                            reviewDialog.close();
                            reviewSession.reextract();
                        }
                    }

                    Button {
                        text: qsTr("Abort")
                        onClicked: {
                            reviewDialog.close();
                            reviewSession.abort();
                        }
                    }
                }

                Button {
                    anchors.right: parent.right
                    visible: reviewDialog.kind === "error" || reviewDialog.kind === "info"
                    text: qsTr("OK")
                    onClicked: reviewDialog.close()
                }
            }
        }
    }

    PlayerMenu {
        id: menu
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        visible: Features.isMacos
        player: root

        OpacityAnimator on opacity {
            id: menuFadeIn
            to: 1
            duration: Math.max(MementoSettings.behaviorOscFadeDuration, 1)
            running: false
            onStarted: menu.visible = true
        }

        OpacityAnimator on opacity {
            id: menuFadeOut
            to: 0
            duration: Math.max(MementoSettings.behaviorOscFadeDuration, 1)
            running: false
            onFinished: menu.visible = false
        }

        onOcrModeRequested: root.startOcrMode()
    }

    PlayerControls {
        id: controls
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        visible: false
        player: root

        OpacityAnimator on opacity {
            id: controlsFadeIn
            to: 1
            duration: Math.max(MementoSettings.behaviorOscFadeDuration, 1)
            running: false
            onStarted: controls.visible = true
        }

        OpacityAnimator on opacity {
            id: controlsFadeOut
            to: 0
            duration: Math.max(MementoSettings.behaviorOscFadeDuration, 1)
            running: false
            onFinished: controls.visible = false
        }

        HoverHandler {
            id: controlsHover
        }
    }

    PlayerOcrOverlay {
        id: ocrOverlay
        player: root
        onHideOscRequested: {
            definitionPopup.clearResults();
            interactiveTimer.stop();
            root.hideOsc(true);
        }
        onModeChanged: (enabled) => root.ocrMode = enabled
        onRestoreOscRequested: {
            if (root.oscVisibility === Player.OscVisible)
            {
                root.showOsc();
            }
            else
            {
                interactiveTimer.restart();
            }
        }
        onShowTextRequested: (text) => root.controller.showText(text)
        onTextRecognized: (text, selection) => definitionPopup.searchOcrText(text, selection)
    }
}
