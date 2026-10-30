import QtQuick
import qs.Common
import qs.Services
import "./InputBinding.js" as InputBinding

MouseArea {
    id: root

    objectName: "__duxBarVolumeOverlay"

    required property var daemon
    required property var barBody
    property var barUnitInset: null

    readonly property string barId: barBody?.barConfig?.id ?? ""
    readonly property string screenName: barBody?.screen?.name ?? barBody?.screenName ?? ""
    readonly property bool barRevealed: barBody?.barRevealed ?? true
    readonly property bool isIsland: barBody?.isIsland === true
    readonly property bool isVertical: barBody?.isVertical === true
    readonly property int barPos: barBody?.barPos ?? 0
    readonly property var islandHost: barBody?.islandHost ?? null
    readonly property bool islandExpanded: islandHost?.expanded === true
    readonly property bool targetEnabled: daemon ? daemon.isBarTargetEnabled(barId, screenName) : false

    readonly property real islandBandThickness: {
        const baseBand = barUnitInset
            ? (isVertical ? barUnitInset.width : barUnitInset.height)
            : (barBody?.effectiveBarThickness ?? 48);
        if (!islandHost || islandExpanded)
            return Math.max(24, baseBand);
        if (isVertical) {
            const pillSpan = barPos === 3
                ? (parent ? parent.width - islandHost.currentVisualX : baseBand)
                : (islandHost.currentVisualX + islandHost.currentVisualWidth);
            return Math.max(baseBand, pillSpan);
        }
        const pillSpan = barPos === 1
            ? (parent ? parent.height - islandHost.currentVisualY : baseBand)
            : (islandHost.currentVisualY + islandHost.currentVisualHeight);
        return Math.max(baseBand, pillSpan);
    }

    x: {
        if (!parent)
            return 0;
        if (isIsland && isVertical && barPos === 3)
            return Math.max(0, parent.width - islandBandThickness);
        return 0;
    }
    y: {
        if (!parent)
            return 0;
        if (isIsland && !isVertical && barPos === 1)
            return Math.max(0, parent.height - islandBandThickness);
        return 0;
    }
    width: {
        if (!parent)
            return 0;
        if (isIsland && isVertical)
            return Math.min(parent.width, islandBandThickness);
        return parent.width;
    }
    height: {
        if (!parent)
            return 0;
        if (isIsland && !isVertical)
            return Math.min(parent.height, islandBandThickness);
        return parent.height;
    }

    z: 9999
    hoverEnabled: false
    preventStealing: true

    enabled: targetEnabled && barRevealed
    visible: enabled
    acceptedButtons: daemon ? daemon.acceptedButtonsMask : Qt.MiddleButton

    property real touchpadAccum: 0
    property real highResAccum: 0
    property double lastWheelEventMs: 0
    property int activeHoldDirection: 0
    property int activeHoldButton: 0
    property double lastWheelMuteMs: 0

    Timer {
        id: holdInitialTimer
        repeat: false
        interval: root.daemon ? Math.max(50, root.daemon.holdInitialDelayMs) : 350
        onTriggered: {
            if (!root.pressed || root.activeHoldDirection === 0 || !root.daemon) {
                root.stopHoldRepeat();
                return;
            }
            root.daemon.performVolumeStep(root.activeHoldDirection, root.daemon.volumeStep);
            holdRepeatTimer.interval = Math.max(15, root.daemon.holdRepeatIntervalMs);
            holdRepeatTimer.restart();
        }
    }

    Timer {
        id: holdRepeatTimer
        repeat: true
        interval: root.daemon ? Math.max(15, root.daemon.holdRepeatIntervalMs) : 80
        onTriggered: {
            if (!root.pressed || root.activeHoldDirection === 0 || !root.daemon) {
                root.stopHoldRepeat();
                return;
            }
            root.daemon.performVolumeStep(root.activeHoldDirection, root.daemon.volumeStep);
        }
    }

    function stopHoldRepeat() {
        holdInitialTimer.stop();
        holdRepeatTimer.stop();
        activeHoldDirection = 0;
        activeHoldButton = 0;
    }

    onEnabledChanged: {
        if (!enabled)
            stopHoldRepeat();
    }

    onVisibleChanged: {
        if (!visible)
            stopHoldRepeat();
    }

    Component.onDestruction: {
        stopHoldRepeat();
    }

    function isOverSubItem(subItem, localX, localY) {
        if (!subItem || !subItem.visible || subItem.width <= 0 || subItem.height <= 0)
            return false;
        const p = root.mapToItem(subItem, localX, localY);
        return p.x >= 0 && p.y >= 0 && p.x <= subItem.width && p.y <= subItem.height;
    }

    function isOverControlCenterMicOrBrightness(ccItem, localX, localY) {
        if (!ccItem)
            return false;
        try {
            if (typeof ccItem.refreshInteractionRefs === "function")
                ccItem.refreshInteractionRefs();
            if (isOverSubItem(ccItem._hBrightness, localX, localY))
                return true;
            if (isOverSubItem(ccItem._hMic, localX, localY))
                return true;
            if (isOverSubItem(ccItem._vBrightness, localX, localY))
                return true;
            if (isOverSubItem(ccItem._vMic, localX, localY))
                return true;
        } catch (e) {
            return false;
        }
        return false;
    }

    function isPointAllowed(localX, localY) {
        if (!daemon)
            return false;

        // Never hijack scroll or middle-click inside an expanded Dux Island sheet/drawer
        if (isIsland && islandExpanded && islandHost?.inputMaskItem) {
            if (isOverSubItem(islandHost.inputMaskItem, localX, localY))
                return false;
        }

        const mode = daemon.coverageMode;
        const needCheck = mode === "audioWidgetsOnly"
            || daemon.passThroughWorkspaceSwitcher
            || daemon.passThroughMediaWidget
            || daemon.passThroughControlCenterSubIcons;

        if (!needCheck)
            return true;

        const registry = BarWidgetService.widgetRegistry || {};
        const keys = Object.keys(registry);
        let matchedAudioWidget = false;

        for (let i = 0; i < keys.length; i++) {
            const entry = registry[keys[i]];
            if (!entry || !entry.item || !entry.item.visible)
                continue;
            if (entry.context?.kind && entry.context.kind !== "bar")
                continue;
            if (entry.screenName && root.screenName && entry.screenName !== root.screenName)
                continue;
            const entryBarId = entry.context?.barId ?? "";
            if (entryBarId && root.barId && entryBarId !== root.barId)
                continue;

            const pt = root.mapToItem(entry.item, localX, localY);
            if (pt.x < 0 || pt.y < 0 || pt.x > entry.item.width || pt.y > entry.item.height)
                continue;

            const wid = entry.widgetId || "";
            const isMusic = wid === "music" || wid.indexOf("music:") === 0;
            const isControlCenter = wid === "controlCenterButton";
            const isWorkspace = wid === "workspaceSwitcher";

            if (isWorkspace && daemon.passThroughWorkspaceSwitcher)
                return false;

            if (isMusic && daemon.passThroughMediaWidget)
                return false;

            if (isControlCenter && daemon.passThroughControlCenterSubIcons) {
                if (isOverControlCenterMicOrBrightness(entry.item, localX, localY))
                    return false;
            }

            if (isMusic || isControlCenter)
                matchedAudioWidget = true;
        }

        if (mode === "audioWidgetsOnly")
            return matchedAudioWidget;

        return true;
    }

    onPressed: mouse => {
        if (!daemon || !isPointAllowed(mouse.x, mouse.y)) {
            mouse.accepted = false;
            return;
        }

        let action = "";
        if (InputBinding.matchesButton(daemon.toggleMuteBinding, mouse.button, mouse.modifiers)) {
            action = "mute";
        } else if (InputBinding.matchesButton(daemon.volumeUpBinding, mouse.button, mouse.modifiers)) {
            action = "up";
        } else if (InputBinding.matchesButton(daemon.volumeDownBinding, mouse.button, mouse.modifiers)) {
            action = "down";
        }

        if (!action) {
            mouse.accepted = false;
            return;
        }

        mouse.accepted = true;
        stopHoldRepeat();

        if (action === "mute") {
            daemon.performToggleMute();
            return;
        }

        const dirSign = action === "up" ? 1 : -1;
        const holdMode = daemon.holdRepeatMode;

        if (holdMode === "stepOnly") {
            daemon.performVolumeStep(dirSign, daemon.volumeStep);
            return;
        }

        if (holdMode === "both") {
            daemon.performVolumeStep(dirSign, daemon.volumeStep);
        }

        activeHoldDirection = dirSign;
        activeHoldButton = mouse.button;
        holdInitialTimer.interval = Math.max(50, daemon.holdInitialDelayMs);
        holdInitialTimer.restart();
    }

    onReleased: mouse => {
        if (activeHoldButton === 0 || mouse.button === activeHoldButton)
            stopHoldRepeat();
    }

    onCanceled: {
        stopHoldRepeat();
    }

    onWheel: wheel => {
        if (wheel.phase === Qt.ScrollEnd) {
            touchpadAccum = 0;
            highResAccum = 0;
            wheel.accepted = false;
            return;
        }

        if (!daemon || !isPointAllowed(wheel.x, wheel.y)) {
            wheel.accepted = false;
            return;
        }

        const info = InputBinding.wheelDirectionAndDelta(wheel);
        if (!info) {
            wheel.accepted = false;
            return;
        }

        let action = "";
        if (InputBinding.matchesWheel(daemon.volumeUpBinding, info)) {
            action = "up";
        } else if (InputBinding.matchesWheel(daemon.volumeDownBinding, info)) {
            action = "down";
        } else if (InputBinding.matchesWheel(daemon.toggleMuteBinding, info)) {
            action = "mute";
        }

        if (!action) {
            wheel.accepted = false;
            return;
        }

        wheel.accepted = true;

        if (action === "mute") {
            const now = Date.now();
            if (now - lastWheelMuteMs >= 200) {
                lastWheelMuteMs = now;
                daemon.performToggleMute();
            }
            return;
        }

        const dirSign = (action === "up" ? 1 : -1) * (daemon.reverseScroll ? -1 : 1);
        const now = Date.now();
        const isFreshGesture = (now - lastWheelEventMs) > 220;
        lastWheelEventMs = now;

        if (info.isTouchpad) {
            if (wheel.phase === Qt.ScrollBegin || isFreshGesture || (touchpadAccum !== 0 && (touchpadAccum * dirSign) < 0))
                touchpadAccum = 0;

            touchpadAccum += dirSign * info.delta;
            const threshold = 18;
            if (Math.abs(touchpadAccum) >= threshold) {
                const steps = Math.trunc(Math.abs(touchpadAccum) / threshold);
                const sign = touchpadAccum > 0 ? 1 : -1;
                touchpadAccum -= sign * steps * threshold;
                daemon.performVolumeStep(sign, daemon.touchpadStep * steps);
            }
            return;
        }

        // Physical mouse wheel: compositors (Niri/Hyprland/Mango) scale the 120-unit detent
        // by SettingsData.mouseScrollFactor (e.g. 120 * 0.7 = 84), so never hardcode >= 120.
        const rawFactor = (typeof SettingsData !== "undefined" && SettingsData.mouseScrollFactor > 0)
            ? SettingsData.mouseScrollFactor
            : 1.0;
        const expectedNotch = Math.max(15, 120 * rawFactor);
        const discreteMinDelta = Math.min(25, expectedNotch * 0.8);

        if (isFreshGesture || (highResAccum !== 0 && (highResAccum * dirSign) < 0))
            highResAccum = 0;

        if (info.delta >= discreteMinDelta) {
            highResAccum = 0;
            const unit = Math.max(discreteMinDelta, expectedNotch);
            const notches = Math.max(1, Math.round(info.delta / unit));
            daemon.performVolumeStep(dirSign, daemon.volumeStep * notches);
            return;
        }

        // Ultra-fine high-resolution free-spin wheels (< discreteMinDelta per micro-pulse):
        // fire immediately on the leading edge of a fresh gesture, then accumulate smoothly.
        if (isFreshGesture) {
            highResAccum = 0;
            daemon.performVolumeStep(dirSign, daemon.volumeStep);
            return;
        }

        highResAccum += dirSign * info.delta;
        if (Math.abs(highResAccum) >= expectedNotch) {
            const notches = Math.trunc(Math.abs(highResAccum) / expectedNotch);
            const sign = highResAccum > 0 ? 1 : -1;
            highResAccum -= sign * notches * expectedNotch;
            daemon.performVolumeStep(sign, daemon.volumeStep * notches);
        }
    }
}
