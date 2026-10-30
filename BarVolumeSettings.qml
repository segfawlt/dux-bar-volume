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

    function normalizeWidgetZoneId(rawId) {
        if (!rawId || typeof rawId !== "string")
            return "";
        const trimmed = rawId.trim();
        if (!trimmed || trimmed === "spacer" || trimmed === "separator")
            return "";
        if (trimmed === "__empty__" || trimmed === "island")
            return trimmed;
        if (trimmed === "music" || trimmed.indexOf("music:") === 0)
            return "music";
        const colonIdx = trimmed.indexOf(":");
        return colonIdx > 0 ? trimmed.slice(0, colonIdx) : trimmed;
    }

    function isBarConfigEligible(cfg) {
        if (!cfg || cfg.enabled === false)
            return false;
        const id = String(cfg.id || "");
        return id.indexOf("dot") !== 0;
    }

    function nativeScrollHintForZone(zoneId, ccBrightnessEnabled) {
        switch (zoneId) {
        case "__empty__":
            return "Empty background, gaps, and spacers — uncheck for bar workspace scroll";
        case "island":
            return "Compact Dux Island pill (expanded Island sheets always scroll normally)";
        case "music":
            return "Uncheck to keep separate per-player media volume scroll";
        case "workspaceSwitcher":
            return "Uncheck to keep workspace switching when scrolling on workspaces";
        case "controlCenterButton":
            return ccBrightnessEnabled
                ? "Scrolls display brightness on hover while checked (uncheck for native Dux behavior)"
                : "Uncheck to keep native Control Center audio/mic/brightness sub-icon scroll";
        case "runningApps":
        case "appsDock":
        case "focusedWindow":
            return "Uncheck to keep native window/app scroll behavior";
        case "keyboard_layout_name":
            return "Uncheck to keep keyboard layout scroll switching";
        default:
            return "";
        }
    }

    function resolveZoneMeta(zoneId, availPlugins, ccBrightnessEnabled) {
        if (zoneId === "__empty__") {
            return {
                id: "__empty__",
                title: "Empty Bar Space",
                icon: "space_bar",
                description: nativeScrollHintForZone("__empty__", ccBrightnessEnabled)
            };
        }

        const catEntry = (typeof BarWidgetCatalog !== "undefined" && typeof BarWidgetCatalog.get === "function")
            ? BarWidgetCatalog.get(zoneId)
            : null;

        if (zoneId === "island") {
            return {
                id: "island",
                title: catEntry?.text || "Dux Island",
                icon: catEntry?.icon || "blur_on",
                description: nativeScrollHintForZone("island", ccBrightnessEnabled)
            };
        }

        if (catEntry) {
            const hint = nativeScrollHintForZone(zoneId, ccBrightnessEnabled);
            return {
                id: zoneId,
                title: catEntry.text || zoneId,
                icon: catEntry.icon || "widgets",
                description: hint || catEntry.description || ""
            };
        }

        const plug = availPlugins ? availPlugins[zoneId] : null;
        if (plug) {
            return {
                id: zoneId,
                title: plug.name || zoneId,
                icon: plug.icon || "extension",
                description: plug.description || "Plugin bar widget"
            };
        }

        return {
            id: zoneId,
            title: zoneId,
            icon: "widgets",
            description: nativeScrollHintForZone(zoneId, ccBrightnessEnabled)
        };
    }

    function extractBarZones(barConfig, availPlugins, liveRegistry, satellitesEnabled, ccBrightnessEnabled) {
        const result = [];
        const byId = {};

        const addZone = (zoneId, sectionLabel) => {
            if (!zoneId)
                return;
            if (byId[zoneId]) {
                if (sectionLabel && byId[zoneId].sections.indexOf(sectionLabel) === -1) {
                    byId[zoneId].sections.push(sectionLabel);
                    byId[zoneId].sectionLabel = byId[zoneId].sections.join(" • ");
                }
                return;
            }
            const meta = resolveZoneMeta(zoneId, availPlugins, ccBrightnessEnabled);
            const item = {
                id: meta.id,
                title: meta.title,
                icon: meta.icon,
                description: meta.description,
                sections: sectionLabel ? [sectionLabel] : [],
                sectionLabel: sectionLabel || ""
            };
            byId[zoneId] = item;
            result.push(item);
        };

        addZone("__empty__", "Surface");

        if (!barConfig)
            return result;

        const isIsland = barConfig.island === true;
        if (byId["__empty__"]) {
            if (isIsland) {
                byId["__empty__"].description = "Empty space inside satellite widget clusters (gaps outside clusters pass through to windows)";
            } else if (barConfig.clickThrough === true) {
                byId["__empty__"].description = "Empty space inside widget sections (Click-through is enabled on this bar, so open gaps pass through)";
            }
        }
        const allowSatellites = !isIsland || satellitesEnabled !== false;

        const scanList = (rawList, sectionLabel) => {
            const arr = Array.isArray(rawList) ? rawList : [];
            for (let i = 0; i < arr.length; i++) {
                const w = arr[i];
                if (!w)
                    continue;
                if (typeof w === "object" && w.enabled === false)
                    continue;
                const rawId = typeof w === "string" ? w : (w.widgetId || w.id || "");
                const norm = normalizeWidgetZoneId(rawId);
                if (norm)
                    addZone(norm, sectionLabel);
            }
        };

        if (allowSatellites)
            scanList(barConfig.leftWidgets, "Left");

        if (isIsland) {
            addZone("island", "Center");
        } else {
            scanList(barConfig.centerWidgets, "Center");
        }

        if (allowSatellites)
            scanList(barConfig.rightWidgets, "Right");

        const barId = barConfig.id || "default";
        const reg = liveRegistry || {};
        const keys = Object.keys(reg);
        for (let k = 0; k < keys.length; k++) {
            const entry = reg[keys[k]];
            if (!entry || !entry.item || !entry.item.visible)
                continue;
            if (entry.context?.kind && entry.context.kind !== "bar")
                continue;
            if ((entry.context?.barId || "default") !== barId)
                continue;
            const norm = normalizeWidgetZoneId(entry.widgetId || "");
            if (norm)
                addZone(norm, entry.context?.section ? String(entry.context.section) : "Live");
        }

        return result;
    }

    function extractSharedZones(barConfigs, availPlugins, liveRegistry, getSatellitesFn, ccBrightnessEnabled) {
        const merged = [];
        const byId = {};

        const configs = Array.isArray(barConfigs) ? barConfigs : [];
        for (let c = 0; c < configs.length; c++) {
            const cfg = configs[c];
            if (!isBarConfigEligible(cfg))
                continue;
            const satOk = typeof getSatellitesFn === "function" ? getSatellitesFn(cfg) : true;
            const barZones = extractBarZones(cfg, availPlugins, liveRegistry, satOk, ccBrightnessEnabled);
            for (let z = 0; z < barZones.length; z++) {
                const bz = barZones[z];
                if (!byId[bz.id]) {
                    const clone = {
                        id: bz.id,
                        title: bz.title,
                        icon: bz.icon,
                        description: bz.description,
                        sections: bz.sections.slice(),
                        sectionLabel: bz.sectionLabel
                    };
                    byId[bz.id] = clone;
                    merged.push(clone);
                } else {
                    for (let s = 0; s < bz.sections.length; s++) {
                        const sec = bz.sections[s];
                        if (byId[bz.id].sections.indexOf(sec) === -1)
                            byId[bz.id].sections.push(sec);
                    }
                    byId[bz.id].sectionLabel = byId[bz.id].sections.join(" • ");
                }
            }
        }

        if (merged.length === 0) {
            const fallback = resolveZoneMeta("__empty__", availPlugins, ccBrightnessEnabled);
            merged.push({
                id: fallback.id,
                title: fallback.title,
                icon: fallback.icon,
                description: fallback.description,
                sections: ["Surface"],
                sectionLabel: "Surface"
            });
        }

        return merged;
    }

    function resolveBarDisplaySummary(barConfig, barWindows, frameHostedBars) {
        const barId = barConfig?.id || "default";
        const displays = [];
        const seen = {};

        const addDisplay = (name, model) => {
            if (!name || seen[name])
                return;
            seen[name] = true;
            const cleanModel = String(model || "").trim();
            displays.push(cleanModel ? (name + " (" + cleanModel + ")") : name);
        };

        const wins = Array.isArray(barWindows) ? barWindows : [];
        for (let i = 0; i < wins.length; i++) {
            const w = wins[i];
            if (!w || w.dot === true || w.free === true || (w.barConfig?.id || "default") !== barId)
                continue;
            addDisplay(w.screen?.name || "", w.screen?.model || "");
        }

        const fMap = frameHostedBars || {};
        const sNames = Object.keys(fMap);
        for (let s = 0; s < sNames.length; s++) {
            const sName = sNames[s];
            const body = fMap[sName]?.[barId];
            if (body)
                addDisplay(sName, body.screen?.model || "");
        }

        if (displays.length === 0) {
            const prefs = Array.isArray(barConfig?.screenPreferences) ? barConfig.screenPreferences : [];
            for (let p = 0; p < prefs.length; p++) {
                const pref = prefs[p];
                if (pref === "all")
                    return "All Displays";
                if (typeof pref === "string")
                    addDisplay(pref, "");
                else if (pref && typeof pref === "object")
                    addDisplay(pref.name || "", pref.model || "");
            }
        }

        return displays.length > 0 ? displays.join(", ") : "Active Display";
    }

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

    component SteppedSlider: Column {
        id: steppedRoot

        required property string settingKey
        required property string label
        property string description: ""
        property int defaultValue: 0
        property int minimum: 0
        property int maximum: 100
        property int stepSize: 1
        property string startIcon: ""
        property string endIcon: ""
        property string unit: ""

        property int value: defaultValue
        property bool _loaded: false

        width: parent ? parent.width : 0
        spacing: Theme.spacingS

        function snapValue(raw) {
            const st = Math.max(1, stepSize);
            let num = Number(raw);
            if (isNaN(num))
                num = Number(defaultValue);
            if (isNaN(num))
                num = minimum;
            const snapped = st > 1 ? (minimum + Math.round((num - minimum) / st) * st) : Math.round(num);
            return Math.max(minimum, Math.min(maximum, snapped));
        }

        function loadValue() {
            if (!root.pluginService || sliderControl.isDragging)
                return;
            const raw = root.loadValue(settingKey, defaultValue);
            const clean = snapValue(raw);
            value = clean;
            _loaded = true;
            if (raw !== undefined && raw !== null && Number(raw) !== clean)
                root.saveValue(settingKey, clean);
        }

        Component.onCompleted: {
            Qt.callLater(loadValue);
        }

        StyledText {
            text: steppedRoot.label
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceText
        }

        StyledText {
            text: steppedRoot.description
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: parent.width
            wrapMode: Text.WordWrap
            visible: steppedRoot.description !== ""
        }

        DSlider {
            id: sliderControl
            upDownKeysStep: false
            width: parent.width
            value: steppedRoot.value
            minimum: steppedRoot.minimum
            maximum: steppedRoot.maximum
            step: Math.max(1, steppedRoot.stepSize)
            startIcon: steppedRoot.startIcon
            endIcon: steppedRoot.endIcon
            unit: steppedRoot.unit
            wheelEnabled: false
            onSliderValueChanged: newValue => {
                const clean = steppedRoot.snapValue(newValue);
                if (steppedRoot.value !== clean)
                    steppedRoot.value = clean;
                root.saveValue(steppedRoot.settingKey, clean);
            }
        }
    }

    component ZoneChecklistRow: Rectangle {
        id: checkRow

        required property var zoneData
        required property bool checked

        signal toggled(bool nextChecked)

        width: parent ? parent.width : 0
        implicitHeight: rowBody.implicitHeight + Theme.spacingS * 2
        height: implicitHeight
        radius: Theme.cornerRadius
        color: rowHover.containsMouse
            ? Theme.surfaceContainerHigh
            : (checked ? Theme.chipSurface : Theme.withAlpha(Theme.surfaceContainer, 0.55))
        border.width: 1
        border.color: checked
            ? Theme.withAlpha(Theme.primary, 0.25)
            : Theme.withAlpha(Theme.outline, 0.2)

        Row {
            id: rowBody
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            spacing: Theme.spacingM

            Rectangle {
                id: checkIndicator
                width: Theme.iconSizeMedium
                height: Theme.iconSizeMedium
                radius: Theme.cornerRadiusXS
                anchors.verticalCenter: parent.verticalCenter
                color: checkRow.checked ? Theme.primary : "transparent"
                border.width: checkRow.checked ? 0 : 1
                border.color: Theme.outline

                DIcon {
                    visible: checkRow.checked
                    anchors.centerIn: parent
                    name: "check"
                    size: Theme.iconSizeSmall
                    color: Theme.onPrimary
                }
            }

            DIcon {
                id: zoneIcon
                anchors.verticalCenter: parent.verticalCenter
                name: checkRow.zoneData?.icon || "widgets"
                size: Theme.iconSizeMedium
                color: checkRow.checked ? Theme.primary : Theme.surfaceVariantText
            }

            Column {
                width: Math.max(Theme.spacingXL * 2, parent.width - checkIndicator.width - zoneIcon.width - (sectionBadge.visible ? sectionBadge.width + Theme.spacingM : 0) - Theme.spacingM * 2)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXXS

                StyledText {
                    width: parent.width
                    text: checkRow.zoneData?.title || ""
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Theme.fontWeightMedium
                    color: checkRow.checked ? Theme.surfaceText : Theme.surfaceVariantText
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: (checkRow.zoneData?.description || "") !== ""
                    width: parent.width
                    text: checkRow.zoneData?.description || ""
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                id: sectionBadge
                visible: (checkRow.zoneData?.sectionLabel || "") !== ""
                anchors.verticalCenter: parent.verticalCenter
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHighest
                implicitWidth: visible ? (secText.implicitWidth + Theme.spacingS * 2) : 0
                implicitHeight: secText.implicitHeight + Theme.spacingXS * 2
                width: implicitWidth
                height: implicitHeight

                StyledText {
                    id: secText
                    anchors.centerIn: parent
                    text: checkRow.zoneData?.sectionLabel || ""
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }

        MouseArea {
            id: rowHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                checkRow.toggled(!checkRow.checked);
            }
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
        border.width: isRecording ? 1 : 0
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

        onVisibleChanged: {
            if (!visible && isRecording)
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
                    width: Math.max(Theme.spacingXL * 2, parent.width - badgeRect.width - Theme.spacingM)
                    spacing: Theme.spacingXXS
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
                    implicitHeight: badgeLabel.implicitHeight + Theme.spacingXS * 2
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
                    width: Math.max(Theme.spacingXL * 4, parent.width - clearBtn.width - resetBtn.width - Theme.spacingS * 2)
                    height: captureLabel.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadius
                    color: bindRow.isRecording
                        ? Theme.withAlpha(Theme.primary, 0.22)
                        : (captureArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer)
                    border.width: 1
                    border.color: bindRow.isRecording ? Theme.primary : Theme.withAlpha(Theme.outline, 0.35)

                    StyledText {
                        id: captureLabel
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
    // 1. Volume Step, Touchpad & Limits
    // =========================================================================
    SectionHeader {
        title: "Volume Step & Limits"
        subtitle: "Configure volume step size, touchpad scrolling, and maximum volume cap"
        showDivider: false
    }

    ToggleSetting {
        id: useSystemStepToggle
        settingKey: "useSystemVolumeStep"
        label: "Use Dux Shell Volume Step"
        description: "Follow Dux Shell's global audio scroll step (" + (AudioService.wheelVolumeStep || 5) + "%). Turn off to set a custom step."
        defaultValue: true
    }

    SteppedSlider {
        visible: !useSystemStepToggle.value
        settingKey: "volumeStep"
        label: "Custom Volume Step"
        description: "Percentage adjusted per scroll wheel notch or mouse button click"
        defaultValue: Math.max(1, AudioService.wheelVolumeStep || 5)
        minimum: 1
        maximum: 25
        stepSize: 1
        unit: "%"
        startIcon: "volume_down"
        endIcon: "volume_up"
    }

    ToggleSetting {
        id: touchpadToggle
        settingKey: "touchpadEnabled"
        label: "Enable Touchpad Scrolling"
        description: "Allow two-finger touchpad scrolling on the bar to change volume"
        defaultValue: false
    }

    SteppedSlider {
        visible: touchpadToggle.value
        settingKey: "touchpadStep"
        label: "Touchpad Volume Step"
        description: "Fine-grained percentage adjusted during two-finger touchpad scrolling"
        defaultValue: 1
        minimum: 1
        maximum: 15
        stepSize: 1
        unit: "%"
        startIcon: "touch_app"
    }

    SteppedSlider {
        visible: touchpadToggle.value
        settingKey: "touchpadThreshold"
        label: "Touchpad Scroll Distance"
        description: "Pixels of two-finger scroll required per step (lower = faster)"
        defaultValue: 18
        minimum: 6
        maximum: 60
        stepSize: 2
        unit: "px"
        startIcon: "swipe_vertical"
    }

    ToggleSetting {
        id: overrideMaxToggle
        settingKey: "overrideMaxVolume"
        label: "Custom Max Volume Cap"
        description: "Override Dux Shell's device max volume limit (supports overdrive up to 150%)"
        defaultValue: false
    }

    SteppedSlider {
        visible: overrideMaxToggle.value
        settingKey: "customMaxVolume"
        label: "Maximum Volume Limit"
        description: "Upper limit when increasing volume via the bar"
        defaultValue: 100
        minimum: 50
        maximum: 150
        stepSize: 5
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
    // 2. Control Center Hover Brightness
    // =========================================================================
    SectionHeader {
        title: "Control Center Hover Brightness"
        subtitle: "Scroll over the Control Center widget on the bar to adjust monitor brightness"
    }

    ToggleSetting {
        id: ccBrightnessToggle
        settingKey: "controlCenterBrightnessEnabled"
        label: "Scroll Brightness on Control Center"
        description: BrightnessService.brightnessAvailable
            ? "Hovering the Control Center widget adjusts display brightness for that monitor instead of volume"
            : "Hovering the Control Center widget adjusts display brightness (no controllable brightness device detected)"
        defaultValue: true
    }

    SelectionSetting {
        visible: ccBrightnessToggle.value
        settingKey: "controlCenterBrightnessZone"
        label: "Control Center Brightness Target"
        description: "Choose whether the entire Control Center pill or only its Brightness sub-icon adjusts brightness"
        options: [
            {
                label: "Entire Control Center widget",
                value: "entireWidget"
            },
            {
                label: "Entire Control Center (keep Mic icon for mic volume)",
                value: "entireExceptMic"
            },
            {
                label: "Brightness icon only (when visible in Control Center)",
                value: "brightnessIconOnly"
            }
        ]
        defaultValue: "entireWidget"
    }

    SteppedSlider {
        visible: ccBrightnessToggle.value
        settingKey: "brightnessStep"
        label: "Brightness Step"
        description: "Display brightness percentage adjusted per scroll wheel notch"
        defaultValue: 5
        minimum: 1
        maximum: 25
        stepSize: 1
        unit: "%"
        startIcon: "brightness_low"
        endIcon: "brightness_high"
    }

    // =========================================================================
    // 3. Bar Coverage & Per-Bar Widget Checklist
    // =========================================================================
    SectionHeader {
        title: "Bar Coverage & Widget Checklist"
        subtitle: "Live-fetched from your active bars — uncheck any widget to preserve its native scroll (such as Media player audio or Workspace switching)"
    }

    ToggleSetting {
        id: perBarCoverageToggle
        settingKey: "perBarCoverageEnabled"
        label: "Customize Checklist Per Bar"
        description: "Configure active widgets separately for each bar instead of sharing one checklist across all bars"
        defaultValue: false
    }

    Column {
        id: coverageManager
        width: parent ? parent.width : 0
        spacing: Theme.spacingM

        property var disabledZones: []
        property var perBarDisabledZones: ({})
        property var collapsedBars: ({})

        function checkSatellitesEnabled(cfg) {
            if (!cfg || cfg.island !== true)
                return true;
            if (typeof SettingsData.islandSetting === "function")
                return SettingsData.islandSetting(cfg, "islandSatellitesEnabled") !== false;
            return cfg.islandSatellitesEnabled !== false;
        }

        readonly property var liveSharedZones: {
            const configs = SettingsData.barConfigs || [];
            const avail = root.pluginService?.availablePlugins ?? PluginService.availablePlugins ?? {};
            const reg = BarWidgetService.widgetRegistry || {};
            return root.extractSharedZones(
                configs,
                avail,
                reg,
                coverageManager.checkSatellitesEnabled,
                ccBrightnessToggle.value
            );
        }

        readonly property var liveBarModels: {
            const configs = SettingsData.barConfigs || [];
            const avail = root.pluginService?.availablePlugins ?? PluginService.availablePlugins ?? {};
            const reg = BarWidgetService.widgetRegistry || {};
            const barWins = KeyboardFocus.barWindows || [];
            const frameMap = BarWidgetService.frameHostedBars || {};
            const out = [];

            for (let i = 0; i < configs.length; i++) {
                const cfg = configs[i];
                if (!root.isBarConfigEligible(cfg))
                    continue;
                const bId = cfg.id || "default";
                const bName = cfg.name || bId;
                const isIsland = cfg.island === true;
                const displaySummary = root.resolveBarDisplaySummary(cfg, barWins, frameMap);
                const zones = root.extractBarZones(
                    cfg,
                    avail,
                    reg,
                    coverageManager.checkSatellitesEnabled(cfg),
                    ccBrightnessToggle.value
                );
                out.push({
                    barId: bId,
                    title: bName + (isIsland ? " (Island)" : ""),
                    subtitle: displaySummary + " • " + zones.length + " zones",
                    zones: zones
                });
            }
            return out;
        }

        function loadValue() {
            if (!root.pluginService)
                return;
            const rawShared = root.loadValue("disabledZones", null);
            if (Array.isArray(rawShared)) {
                disabledZones = rawShared.slice();
            } else {
                const migrated = [];
                if (root.loadValue("passThroughWorkspaceSwitcher", false) === true)
                    migrated.push("workspaceSwitcher");
                if (root.loadValue("passThroughMediaWidget", false) === true)
                    migrated.push("music");
                disabledZones = migrated;
            }

            const rawPerBar = root.loadValue("perBarDisabledZones", {});
            if (rawPerBar && typeof rawPerBar === "object" && !Array.isArray(rawPerBar)) {
                perBarDisabledZones = JSON.parse(JSON.stringify(rawPerBar));
            } else {
                perBarDisabledZones = {};
            }
        }

        function isSharedChecked(zoneId) {
            return disabledZones.indexOf(zoneId) === -1;
        }

        function setSharedChecked(zoneId, isChecked) {
            const next = disabledZones.slice();
            const idx = next.indexOf(zoneId);
            if (isChecked && idx !== -1)
                next.splice(idx, 1);
            else if (!isChecked && idx === -1)
                next.push(zoneId);
            disabledZones = next;
            root.saveValue("disabledZones", next);
        }

        function applySharedPreset(preset) {
            let next = [];
            if (preset === "exceptMediaWorkspace") {
                next = ["music", "workspaceSwitcher"];
            } else if (preset === "clear") {
                next = liveSharedZones.map(z => z.id);
            }
            disabledZones = next;
            root.saveValue("disabledZones", next);
        }

        function getBarDisabledList(barId) {
            if (Array.isArray(perBarDisabledZones[barId]))
                return perBarDisabledZones[barId];
            return disabledZones;
        }

        function isBarZoneChecked(barId, zoneId) {
            return getBarDisabledList(barId).indexOf(zoneId) === -1;
        }

        function setBarZoneChecked(barId, zoneId, isChecked) {
            const nextList = getBarDisabledList(barId).slice();
            const idx = nextList.indexOf(zoneId);
            if (isChecked && idx !== -1)
                nextList.splice(idx, 1);
            else if (!isChecked && idx === -1)
                nextList.push(zoneId);

            const nextMap = JSON.parse(JSON.stringify(perBarDisabledZones || {}));
            nextMap[barId] = nextList;
            perBarDisabledZones = nextMap;
            root.saveValue("perBarDisabledZones", nextMap);
        }

        function applyBarPreset(barId, barZones, preset) {
            let nextList = [];
            if (preset === "exceptMediaWorkspace") {
                nextList = ["music", "workspaceSwitcher"];
            } else if (preset === "clear") {
                nextList = (barZones || []).map(z => z.id);
            }
            const nextMap = JSON.parse(JSON.stringify(perBarDisabledZones || {}));
            nextMap[barId] = nextList;
            perBarDisabledZones = nextMap;
            root.saveValue("perBarDisabledZones", nextMap);
        }

        function isBarCollapsed(barId) {
            return collapsedBars[barId] === true;
        }

        function toggleBarCollapsed(barId) {
            const next = Object.assign({}, collapsedBars);
            next[barId] = !isBarCollapsed(barId);
            collapsedBars = next;
        }

        Component.onCompleted: {
            Qt.callLater(loadValue);
        }

        // --- Shared Checklist Mode ---
        Column {
            visible: !perBarCoverageToggle.value
            width: parent.width
            spacing: Theme.spacingS

            Flow {
                width: parent.width
                spacing: Theme.spacingS

                DButton {
                    text: "Enable All"
                    tooltipText: "Activate volume scroll across the entire bar"
                    onClicked: coverageManager.applySharedPreset("all")
                }

                DButton {
                    text: "Keep Media & Workspaces Native"
                    tooltipText: "Uncheck Media and Workspace Switcher so they keep their native scroll"
                    onClicked: coverageManager.applySharedPreset("exceptMediaWorkspace")
                }

                DButton {
                    text: "Uncheck All"
                    tooltipText: "Disable all zones"
                    onClicked: coverageManager.applySharedPreset("clear")
                }
            }

            Repeater {
                model: coverageManager.liveSharedZones

                ZoneChecklistRow {
                    required property var modelData

                    width: coverageManager.width
                    zoneData: modelData
                    checked: coverageManager.isSharedChecked(modelData.id)
                    onToggled: nextChecked => {
                        coverageManager.setSharedChecked(modelData.id, nextChecked);
                    }
                }
            }
        }

        // --- Per-Bar Checklist Mode ---
        Column {
            visible: perBarCoverageToggle.value
            width: parent.width
            spacing: Theme.spacingM

            Repeater {
                model: coverageManager.liveBarModels

                Rectangle {
                    id: barCard
                    required property var modelData

                    readonly property bool collapsed: coverageManager.isBarCollapsed(modelData.barId)

                    width: coverageManager.width
                    implicitHeight: barCardCol.implicitHeight + Theme.spacingM * 2
                    height: implicitHeight
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerLow, 0.7)
                    border.width: 1
                    border.color: Theme.withAlpha(Theme.outline, 0.25)

                    Column {
                        id: barCardCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        Rectangle {
                            width: parent.width
                            height: Math.max(Theme.iconSizeMedium + Theme.spacingM, headerTextCol.implicitHeight + Theme.spacingXS * 2)
                            radius: Theme.cornerRadius
                            color: cardHeaderMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingXS
                                anchors.rightMargin: Theme.spacingXS
                                spacing: Theme.spacingS

                                DIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "web_asset"
                                    size: Theme.iconSizeMedium
                                    color: Theme.primary
                                }

                                Column {
                                    id: headerTextCol
                                    width: Math.max(Theme.spacingXL * 2, parent.width - Theme.iconSizeMedium * 2 - Theme.spacingS * 2)
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingXXS

                                    StyledText {
                                        width: parent.width
                                        text: barCard.modelData.title
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Theme.fontWeightMedium
                                        color: Theme.surfaceText
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        width: parent.width
                                        text: barCard.modelData.subtitle
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                    }
                                }

                                DIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: barCard.collapsed ? "expand_more" : "expand_less"
                                    size: Theme.iconSizeMedium
                                    color: Theme.surfaceVariantText
                                }
                            }

                            MouseArea {
                                id: cardHeaderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: coverageManager.toggleBarCollapsed(barCard.modelData.barId)
                            }
                        }

                        Flow {
                            visible: !barCard.collapsed
                            width: parent.width
                            spacing: Theme.spacingS

                            DButton {
                                text: "Enable All"
                                onClicked: coverageManager.applyBarPreset(barCard.modelData.barId, barCard.modelData.zones, "all")
                            }

                            DButton {
                                text: "Keep Media & Workspaces"
                                onClicked: coverageManager.applyBarPreset(barCard.modelData.barId, barCard.modelData.zones, "exceptMediaWorkspace")
                            }

                            DButton {
                                text: "Uncheck All"
                                onClicked: coverageManager.applyBarPreset(barCard.modelData.barId, barCard.modelData.zones, "clear")
                            }
                        }

                        Column {
                            visible: !barCard.collapsed
                            width: parent.width
                            spacing: Theme.spacingXS

                            Repeater {
                                model: barCard.modelData.zones

                                ZoneChecklistRow {
                                    required property var modelData

                                    width: parent.width
                                    zoneData: modelData
                                    checked: coverageManager.isBarZoneChecked(barCard.modelData.barId, modelData.id)
                                    onToggled: nextChecked => {
                                        coverageManager.setBarZoneChecked(barCard.modelData.barId, modelData.id, nextChecked);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 4. Bars & Displays
    // =========================================================================
    SectionHeader {
        title: "Bars & Displays"
        subtitle: "Enable across all bars automatically or toggle specific bar and monitor combinations"
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
                if (!w || w.dot === true || w.free === true || !root.isBarConfigEligible(w.barConfig))
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
                    if (cfg && root.isBarConfigEligible(cfg))
                        addTarget(cfg.id || bIds[b], cfg.name || bIds[b], sName, body?.screen?.model ?? "");
                }
            }

            if (list.length === 0) {
                const configs = SettingsData.barConfigs || [];
                const screens = Quickshell.screens || [];
                for (let c = 0; c < configs.length; c++) {
                    const cfg = configs[c];
                    if (!root.isBarConfigEligible(cfg))
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
    // 5. Input Bindings & Button Hold
    // =========================================================================
    SectionHeader {
        title: "Input Bindings"
        subtitle: "Use the standard scroll + middle-click bindings, or customize mouse buttons and modifier combos"
    }

    ToggleSetting {
        id: useDefaultBindingsToggle
        settingKey: "useDefaultBindings"
        label: "Use Default Bindings"
        description: "Scroll Up/Down for volume and Middle Click (M3) to toggle mute. Turn off to customize bindings."
        defaultValue: true
    }

    BindingRow {
        visible: !useDefaultBindingsToggle.value
        settingKey: "volumeUpBinding"
        label: "Volume Up"
        description: "Increase level while hovering over the bar"
        defaultBinding: InputBinding.DEFAULT_VOLUME_UP
    }

    BindingRow {
        visible: !useDefaultBindingsToggle.value
        settingKey: "volumeDownBinding"
        label: "Volume Down"
        description: "Decrease level while hovering over the bar"
        defaultBinding: InputBinding.DEFAULT_VOLUME_DOWN
    }

    BindingRow {
        visible: !useDefaultBindingsToggle.value
        settingKey: "toggleMuteBinding"
        label: "Toggle Mute"
        description: "Mute or unmute system audio while hovering over the bar"
        defaultBinding: InputBinding.DEFAULT_TOGGLE_MUTE
    }

    SectionHeader {
        visible: !useDefaultBindingsToggle.value
        title: "Button Press & Hold"
        subtitle: "Customize click and rapid-hold timing when actions are bound to mouse buttons like M4 or M5"
    }

    SelectionSetting {
        id: holdModeSetting
        visible: !useDefaultBindingsToggle.value
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

    SteppedSlider {
        visible: !useDefaultBindingsToggle.value && holdModeSetting.value !== "stepOnly"
        settingKey: "holdInitialDelayMs"
        label: "Hold Detection Delay"
        description: "How long a mouse button must be held before rapid adjustment begins (50 ms increments)"
        defaultValue: 350
        minimum: 100
        maximum: 1000
        stepSize: 50
        unit: "ms"
        startIcon: "timer"
    }

    SteppedSlider {
        visible: !useDefaultBindingsToggle.value && holdModeSetting.value !== "stepOnly"
        settingKey: "holdRepeatIntervalMs"
        label: "Hold Repeat Interval"
        description: "Time between each step while the button stays held down (25 ms increments)"
        defaultValue: 75
        minimum: 25
        maximum: 500
        stepSize: 25
        unit: "ms"
        startIcon: "speed"
    }

    // =========================================================================
    // 6. Mute & Feedback
    // =========================================================================
    SectionHeader {
        title: "Mute & Feedback"
        subtitle: "Configure mute behavior and Dux Shell OSD popup duration"
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
        id: showOsdToggle
        settingKey: "showOsd"
        label: "Show Volume OSD Popup"
        description: "Display Dux Shell's native on-screen popup when adjusting volume or brightness on the bar"
        defaultValue: true
    }

    SteppedSlider {
        visible: showOsdToggle.value
        settingKey: "customOsdDurationMs"
        label: "OSD Display Time"
        description: "Milliseconds before the popup disappears (snaps to 50 ms steps)"
        defaultValue: 2000
        minimum: 300
        maximum: 6000
        stepSize: 50
        unit: "ms"
        startIcon: "timer"
    }

    ToggleSetting {
        settingKey: "playFeedbackSound"
        label: "Play Volume Feedback Sound"
        description: "Play Dux Shell's volume-change sound effect when enabled in system audio settings"
        defaultValue: true
    }
}
