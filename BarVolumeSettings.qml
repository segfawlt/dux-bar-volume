import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Plugins
import "./InputBinding.js" as InputBinding

PluginSettings {
    id: root
    pluginId: "barVolume"

    property string recordingKey: ""

    component SectionHeader: Column {
        id: secHeader

        property string title: ""
        property string subtitle: ""
        property bool showDivider: true

        width: parent ? parent.width : 0
        spacing: Theme.spacingXS

        Rectangle {
            visible: secHeader.showDivider
            width: secHeader.width
            height: 1
            color: Theme.outline
            opacity: 0.25
        }

        Item {
            visible: secHeader.showDivider
            width: 1
            height: Theme.spacingXS
        }

        StyledText {
            width: secHeader.width
            text: secHeader.title
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceText
        }

        StyledText {
            visible: secHeader.subtitle !== ""
            width: secHeader.width
            text: secHeader.subtitle
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }
    }

    component BindingRow: Rectangle {
        id: bindRow

        required property string settingKey
        required property string label
        property string description: ""
        required property var defaultBinding

        property var currentBinding: defaultBinding
        readonly property bool isRecording: root.recordingKey === settingKey

        width: parent ? parent.width : 0
        implicitHeight: innerCol.implicitHeight + Theme.spacingM * 2
        height: implicitHeight
        radius: Theme.cornerRadius
        color: isRecording ? Theme.withAlpha(Theme.primary, 0.14) : Theme.chipSurface
        border.width: isRecording ? 1.5 : 0
        border.color: isRecording ? Theme.primary : "transparent"

        function loadValue() {
            const raw = root.loadValue(settingKey, defaultBinding);
            currentBinding = InputBinding.normalizeBinding(raw, defaultBinding);
        }

        function applyBinding(newBinding) {
            const normalized = InputBinding.normalizeBinding(newBinding, defaultBinding);
            currentBinding = normalized;
            root.saveValue(settingKey, normalized);
            if (root.recordingKey === settingKey)
                root.recordingKey = "";
        }

        Component.onCompleted: {
            Qt.callLater(loadValue);
        }

        Column {
            id: innerCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            Row {
                width: parent.width
                spacing: Theme.spacingM

                Column {
                    width: Math.max(80, parent.width - badgeRect.width - Theme.spacingM)
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        width: parent.width
                        text: bindRow.label
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Theme.fontWeightMedium
                        color: Theme.surfaceText
                    }

                    StyledText {
                        visible: bindRow.description !== ""
                        width: parent.width
                        text: bindRow.description
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }
                }

                Rectangle {
                    id: badgeRect
                    anchors.verticalCenter: parent.verticalCenter
                    radius: Theme.cornerRadius
                    color: bindRow.isRecording ? Theme.primary : Theme.surfaceContainerHigh
                    implicitWidth: badgeLabel.implicitWidth + Theme.spacingM * 2
                    implicitHeight: 28
                    width: implicitWidth
                    height: implicitHeight

                    StyledText {
                        id: badgeLabel
                        anchors.centerIn: parent
                        text: bindRow.isRecording ? "Listening..." : InputBinding.formatBinding(bindRow.currentBinding)
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightMedium
                        color: bindRow.isRecording ? Theme.onPrimary : Theme.surfaceText
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingS

                Rectangle {
                    id: captureBox
                    width: Math.max(120, parent.width - clearBtn.width - resetBtn.width - Theme.spacingS * 2)
                    height: 34
                    radius: Theme.cornerRadius
                    color: bindRow.isRecording
                        ? Theme.withAlpha(Theme.primary, 0.22)
                        : (captureArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer)
                    border.width: 1
                    border.color: bindRow.isRecording ? Theme.primary : Theme.withAlpha(Theme.outline, 0.35)

                    StyledText {
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingM * 2
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: bindRow.isRecording
                            ? "Scroll or press mouse button here (Left-click cancels)"
                            : "Click to bind mouse / scroll input"
                        font.pixelSize: Theme.fontSizeSmall
                        color: bindRow.isRecording ? Theme.primary : Theme.surfaceText
                    }

                    MouseArea {
                        id: captureArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.AllButtons
                        preventStealing: bindRow.isRecording
                        cursorShape: Qt.PointingHandCursor

                        onPressed: mouse => {
                            if (!bindRow.isRecording) {
                                if (mouse.button === Qt.LeftButton) {
                                    root.recordingKey = bindRow.settingKey;
                                    mouse.accepted = true;
                                }
                                return;
                            }

                            mouse.accepted = true;
                            const mods = InputBinding.cleanModifiers(mouse.modifiers);

                            // Plain Left Click cancels capture so users never accidentally lock out bar clicks
                            if (mouse.button === Qt.LeftButton && mods === 0) {
                                root.recordingKey = "";
                                return;
                            }

                            bindRow.applyBinding({
                                kind: "button",
                                button: mouse.button,
                                modifiers: mods
                            });
                        }

                        onWheel: wheel => {
                            if (!bindRow.isRecording) {
                                wheel.accepted = false;
                                return;
                            }
                            wheel.accepted = true;
                            const info = InputBinding.wheelDirectionAndDelta(wheel);
                            if (!info)
                                return;

                            let capturedDir = info.dir;
                            if ((info.modifiers & Qt.ShiftModifier) !== 0 && info.rawAngleY === 0 && info.rawAngleX !== 0) {
                                capturedDir = info.rawAngleX > 0 ? "up" : "down";
                            }

                            bindRow.applyBinding({
                                kind: "wheel",
                                dir: capturedDir,
                                modifiers: info.modifiers
                            });
                        }
                    }
                }

                DButton {
                    id: clearBtn
                    text: "None"
                    tooltipText: "Disable this action"
                    onClicked: {
                        bindRow.applyBinding(InputBinding.NONE_BINDING);
                    }
                }

                DButton {
                    id: resetBtn
                    text: "Reset"
                    tooltipText: "Restore default binding"
                    onClicked: {
                        bindRow.applyBinding(bindRow.defaultBinding);
                    }
                }
            }
        }
    }

    // =========================================================================
    // 1. Volume Step & Limits
    // =========================================================================
    SectionHeader {
        title: "Volume Step & Limits"
        subtitle: "Configure how much system audio changes per scroll notch or button press"
        showDivider: false
    }

    SliderSetting {
        settingKey: "volumeStep"
        label: "Volume Step"
        description: "Percentage adjusted per scroll wheel notch or mouse button click"
        defaultValue: Math.max(1, AudioService.wheelVolumeStep || 5)
        minimum: 1
        maximum: 25
        unit: "%"
        startIcon: "volume_down"
        endIcon: "volume_up"
    }

    SliderSetting {
        settingKey: "touchpadStep"
        label: "Touchpad Smooth Scroll Step"
        description: "Fine-grained percentage adjusted during two-finger touchpad scrolling"
        defaultValue: 1
        minimum: 1
        maximum: 15
        unit: "%"
        startIcon: "touch_app"
    }

    ToggleSetting {
        id: overrideMaxToggle
        settingKey: "overrideMaxVolume"
        label: "Custom Max Volume Cap"
        description: "Override Dux Shell's device max volume limit (supports overdrive up to 150%)"
        defaultValue: false
    }

    SliderSetting {
        visible: overrideMaxToggle.value
        settingKey: "customMaxVolume"
        label: "Maximum Volume Limit"
        description: "Upper limit when increasing volume via the bar"
        defaultValue: 100
        minimum: 50
        maximum: 150
        unit: "%"
        endIcon: "graphic_eq"
    }

    ToggleSetting {
        settingKey: "reverseScroll"
        label: "Reverse Scroll Direction"
        description: "Invert scroll up and scroll down directions"
        defaultValue: false
    }

    // =========================================================================
    // 2. Input Bindings
    // =========================================================================
    SectionHeader {
        title: "Input Bindings"
        subtitle: "Bind Scroll Up/Down/Left/Right, Middle Click (M3), Side Buttons (M4/M5), Extra Buttons, or Ctrl/Alt/Shift + Mouse without stealing keyboard focus"
    }

    BindingRow {
        settingKey: "volumeUpBinding"
        label: "Volume Up"
        description: "Increase system volume while hovering over the bar"
        defaultBinding: InputBinding.DEFAULT_VOLUME_UP
    }

    BindingRow {
        settingKey: "volumeDownBinding"
        label: "Volume Down"
        description: "Decrease system volume while hovering over the bar"
        defaultBinding: InputBinding.DEFAULT_VOLUME_DOWN
    }

    BindingRow {
        settingKey: "toggleMuteBinding"
        label: "Toggle Mute"
        description: "Mute or unmute system audio while hovering over the bar"
        defaultBinding: InputBinding.DEFAULT_TOGGLE_MUTE
    }

    // =========================================================================
    // 3. Mouse Button Hold-to-Repeat
    // =========================================================================
    SectionHeader {
        title: "Button Press & Hold"
        subtitle: "Customize click and rapid-hold timing when Volume Up/Down is bound to mouse buttons like M4 or M5"
    }

    SelectionSetting {
        id: holdModeSetting
        settingKey: "holdRepeatMode"
        label: "Button Hold Mode"
        description: "Choose single-step click, rapid adjustment while held, or both"
        options: [
            {
                label: "Step on click + rapid repeat when held",
                value: "both"
            },
            {
                label: "Step click only (no repeat when held)",
                value: "stepOnly"
            },
            {
                label: "Rapid repeat when held only",
                value: "holdOnly"
            }
        ]
        defaultValue: "both"
    }

    SliderSetting {
        visible: holdModeSetting.value !== "stepOnly"
        settingKey: "holdInitialDelayMs"
        label: "Hold Detection Delay"
        description: "How long a mouse button must be held before rapid adjustment begins"
        defaultValue: 350
        minimum: 100
        maximum: 1000
        unit: "ms"
        startIcon: "timer"
    }

    SliderSetting {
        visible: holdModeSetting.value !== "stepOnly"
        settingKey: "holdRepeatIntervalMs"
        label: "Hold Repeat Interval"
        description: "Time between each volume step while the button stays held down"
        defaultValue: 80
        minimum: 20
        maximum: 400
        unit: "ms"
        startIcon: "speed"
    }

    // =========================================================================
    // 4. Bars & Displays
    // =========================================================================
    SectionHeader {
        title: "Bars & Displays"
        subtitle: "Enable across all bars automatically or pick specific bar and monitor combinations"
    }

    ToggleSetting {
        id: targetAllToggle
        settingKey: "targetAllBars"
        label: "Enable on All Bars & Displays"
        description: "Active on every bar across all connected displays"
        defaultValue: true
    }

    Column {
        id: barTargetsList
        visible: !targetAllToggle.value
        width: parent ? parent.width : 0
        spacing: Theme.spacingS

        property var disabledKeys: []

        readonly property var availableTargets: {
            const list = [];
            const seen = {};

            const addTarget = (barId, barName, screenName, screenModel) => {
                const key = barId + "@" + screenName;
                if (seen[key])
                    return;
                seen[key] = true;
                const cleanModel = (screenModel || "").trim();
                const displayLabel = screenName + (cleanModel ? " (" + cleanModel + ")" : "");
                list.push({
                    key: key,
                    title: (barName || barId) + " — " + displayLabel,
                    subtitle: "Bar ID: " + barId + " • Display: " + screenName
                });
            };

            const wins = KeyboardFocus.barWindows || [];
            for (let i = 0; i < wins.length; i++) {
                const w = wins[i];
                if (!w || !w.barConfig)
                    continue;
                const bId = w.barConfig.id || "default";
                const bName = w.barConfig.name || bId;
                const sName = w.screen?.name ?? "";
                const sModel = w.screen?.model ?? "";
                if (sName)
                    addTarget(bId, bName, sName, sModel);
            }

            const frameMap = BarWidgetService.frameHostedBars || {};
            const screenNames = Object.keys(frameMap);
            for (let s = 0; s < screenNames.length; s++) {
                const sName = screenNames[s];
                const perBar = frameMap[sName] || {};
                const bIds = Object.keys(perBar);
                for (let b = 0; b < bIds.length; b++) {
                    const body = perBar[bIds[b]];
                    const cfg = body?.barConfig;
                    if (cfg)
                        addTarget(cfg.id || bIds[b], cfg.name || bIds[b], sName, body?.screen?.model ?? "");
                }
            }

            if (list.length === 0) {
                const configs = SettingsData.barConfigs || [];
                const screens = Quickshell.screens || [];
                for (let c = 0; c < configs.length; c++) {
                    const cfg = configs[c];
                    if (!cfg || cfg.enabled === false)
                        continue;
                    for (let s = 0; s < screens.length; s++) {
                        const scr = screens[s];
                        if (scr?.name)
                            addTarget(cfg.id || "default", cfg.name || "Bar", scr.name, scr.model || "");
                    }
                }
            }

            return list;
        }

        function loadValue() {
            const loaded = root.loadValue("disabledBarTargets", []);
            disabledKeys = Array.isArray(loaded) ? loaded.slice() : [];
        }

        function setTargetEnabled(targetKey, isEnabled) {
            const next = disabledKeys.slice();
            const idx = next.indexOf(targetKey);
            if (isEnabled && idx !== -1) {
                next.splice(idx, 1);
            } else if (!isEnabled && idx === -1) {
                next.push(targetKey);
            }
            disabledKeys = next;
            root.saveValue("disabledBarTargets", next);
        }

        Component.onCompleted: {
            Qt.callLater(loadValue);
        }

        Repeater {
            model: barTargetsList.availableTargets

            Rectangle {
                required property var modelData

                width: barTargetsList.width
                implicitHeight: targetToggle.height + Theme.spacingS * 2
                height: implicitHeight
                radius: Theme.cornerRadius
                color: Theme.chipSurface

                DToggle {
                    id: targetToggle
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingM
                    width: parent.width - Theme.spacingM * 2
                    text: modelData.title
                    description: modelData.subtitle
                    checked: barTargetsList.disabledKeys.indexOf(modelData.key) === -1
                    onToggled: isChecked => {
                        barTargetsList.setTargetEnabled(modelData.key, isChecked);
                    }
                }
            }
        }
    }

    // =========================================================================
    // 5. Coverage & Widget Exceptions
    // =========================================================================
    SectionHeader {
        title: "Coverage & Widget Exceptions"
        subtitle: "Control where on the bar volume actions trigger and which widgets keep their native scroll"
    }

    SelectionSetting {
        id: coverageSetting
        settingKey: "coverageMode"
        label: "Bar Coverage Zone"
        description: "Trigger anywhere over the bar, or restrict only to the Control Center & Media widgets"
        options: [
            {
                label: "Entire Bar (override widgets & empty space)",
                value: "entireBar"
            },
            {
                label: "Control Center & Media Widgets Only",
                value: "audioWidgetsOnly"
            }
        ]
        defaultValue: "entireBar"
    }

    ToggleSetting {
        visible: coverageSetting.value === "entireBar"
        settingKey: "passThroughWorkspaceSwitcher"
        label: "Keep Workspace Switcher Scroll"
        description: "Let scrolling directly over Workspace Switcher switch workspaces instead of volume"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "passThroughControlCenterSubIcons"
        label: "Keep Control Center Mic & Brightness Scroll"
        description: "Let scrolling directly over the Mic or Brightness icons in Control Center adjust mic/brightness"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "passThroughMediaWidget"
        label: "Keep Media Widget Per-Player Scroll"
        description: "When off (default), scrolling over the Media bar widget changes system-wide volume instead of player-only volume"
        defaultValue: false
    }

    // =========================================================================
    // 6. Mute & Feedback
    // =========================================================================
    SectionHeader {
        title: "Mute & Feedback"
        subtitle: "Configure mute behavior and Dux Shell OSD / sound feedback"
    }

    SelectionSetting {
        settingKey: "muteOnVolumeChange"
        label: "Scrolling While Muted"
        description: "How mute state responds when volume is adjusted"
        options: [
            {
                label: "Auto-unmute when increasing volume (stay muted on down)",
                value: "unmuteOnUp"
            },
            {
                label: "Auto-unmute on any volume adjustment",
                value: "unmuteAlways"
            },
            {
                label: "Keep muted (only adjust level)",
                value: "keepMuted"
            }
        ]
        defaultValue: "unmuteOnUp"
    }

    ToggleSetting {
        settingKey: "showOsd"
        label: "Show Volume OSD Popup"
        description: "Display Dux Shell's native on-screen volume popup when adjusting volume on the bar"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "playFeedbackSound"
        label: "Play Volume Feedback Sound"
        description: "Play Dux Shell's volume-change sound effect when enabled in system audio settings"
        defaultValue: true
    }
}
