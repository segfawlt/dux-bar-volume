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
    readonly property bool hostsIsland: isIsland || (barBody?.hostsIsland === true) || islandHost !== null
    readonly property bool islandExpanded: (islandHost?.expanded === true) || (islandHost?.sheetOut === true)
    readonly property bool targetEnabled: daemon ? daemon.isBarTargetEnabled(barId, screenName) : false

    // SettingsData.Position: Top=0, Bottom=1, Left=2, Right=3, TopCenter=4, BottomCenter=5, LeftCenter=6, RightCenter=7
    readonly property bool isFarCrossEdge: isVertical
        ? (barPos === 3 || barPos === 7)
        : (barPos === 1 || barPos === 5)
    readonly property bool clampToIslandBand: isIsland || (hostsIsland && parent === barBody)

    readonly property real islandBandThickness: {
        const baseBand = barUnitInset
            ? (isVertical ? barUnitInset.width : barUnitInset.height)
            : (barBody?.effectiveBarThickness ?? 48);
        if (!islandHost || islandExpanded)
            return Math.max(24, baseBand);
        if (isVertical) {
            const pillSpan = isFarCrossEdge
                ? (parent ? parent.width - islandHost.currentVisualX : baseBand)
                : (islandHost.currentVisualX + islandHost.currentVisualWidth);
            return Math.max(baseBand, pillSpan);
        }
        const pillSpan = isFarCrossEdge
            ? (parent ? parent.height - islandHost.currentVisualY : baseBand)
            : (islandHost.currentVisualY + islandHost.currentVisualHeight);
        return Math.max(baseBand, pillSpan);
    }

    x: {
        if (!parent)
            return 0;
        if (clampToIslandBand && isVertical && isFarCrossEdge)
            return Math.max(0, parent.width - islandBandThickness);
        return 0;
    }
    y: {
        if (!parent)
            return 0;
        if (clampToIslandBand && !isVertical && isFarCrossEdge)
            return Math.max(0, parent.height - islandBandThickness);
        return 0;
    }
    width: {
        if (!parent)
            return 0;
        if (clampToIslandBand && isVertical)
            return Math.min(parent.width, islandBandThickness);
        return parent.width;
    }
    height: {
        if (!parent)
            return 0;
        if (clampToIslandBand && !isVertical)
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
    property string lastScrollTargetKind: "volume"
    property double lastWheelEventMs: 0
    property int activeHoldDirection: 0
    property int activeHoldButton: 0
    property string activeHoldTargetKind: "volume"
    property double lastWheelMuteMs: 0

    function dispatchStep(targetKind, dirSign, notchesOrSteps, isTouchpad) {
        if (!daemon || dirSign === 0)
            return;
        if (targetKind === "brightness") {
            const perUnit = isTouchpad ? daemon.touchpadStep : daemon.brightnessStep;
            daemon.performBrightnessStep(dirSign, perUnit * notchesOrSteps, root.screenName);
        } else {
            const perUnit = isTouchpad ? daemon.touchpadStep : daemon.volumeStep;
            daemon.performVolumeStep(dirSign, perUnit * notchesOrSteps, root.screenName);
        }
    }

    Timer {
        id: holdInitialTimer
        repeat: false
        interval: root.daemon ? Math.max(50, root.daemon.holdInitialDelayMs) : 350
        onTriggered: {
            if (!root.pressed || root.activeHoldDirection === 0 || !root.daemon) {
                root.stopHoldRepeat();
                return;
            }
            root.dispatchStep(root.activeHoldTargetKind, root.activeHoldDirection, 1, false);
            holdRepeatTimer.interval = Math.max(25, root.daemon.holdRepeatIntervalMs);
            holdRepeatTimer.restart();
        }
    }

    Timer {
        id: holdRepeatTimer
        repeat: true
        interval: root.daemon ? Math.max(25, root.daemon.holdRepeatIntervalMs) : 75
        onTriggered: {
            if (!root.pressed || root.activeHoldDirection === 0 || !root.daemon) {
                root.stopHoldRepeat();
                return;
            }
            root.dispatchStep(root.activeHoldTargetKind, root.activeHoldDirection, 1, false);
        }
    }

    function stopHoldRepeat() {
        holdInitialTimer.stop();
        holdRepeatTimer.stop();
        activeHoldDirection = 0;
        activeHoldButton = 0;
        activeHoldTargetKind = "volume";
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

    function isOverControlCenterGroup(ccItem, groupKind, localX, localY) {
        if (!ccItem)
            return false;
        try {
            if (typeof ccItem.refreshInteractionRefs === "function")
                ccItem.refreshInteractionRefs();
            if (groupKind === "brightness") {
                return isOverSubItem(ccItem._hBrightness, localX, localY)
                    || isOverSubItem(ccItem._vBrightness, localX, localY);
            }
            if (groupKind === "mic") {
                return isOverSubItem(ccItem._hMic, localX, localY)
                    || isOverSubItem(ccItem._vMic, localX, localY);
            }
        } catch (e) {
            return false;
        }
        return false;
    }

    function isOverCompactIslandPill(localX, localY) {
        if (!islandHost || islandExpanded)
            return false;
        if (islandHost.inputMaskItem && isOverSubItem(islandHost.inputMaskItem, localX, localY))
            return true;
        if (islandHost.currentVisualWidth > 0 && islandHost.currentVisualHeight > 0) {
            const p = root.mapToItem(islandHost, localX, localY);
            return p.x >= islandHost.currentVisualX
                && p.y >= islandHost.currentVisualY
                && p.x <= (islandHost.currentVisualX + islandHost.currentVisualWidth)
                && p.y <= (islandHost.currentVisualY + islandHost.currentVisualHeight);
        }
        return false;
    }

    // Returns "passthrough" | "volume" | "brightness"
    function resolvePointAction(localX, localY) {
        if (!daemon)
            return "passthrough";

        // Never hijack scroll or middle-click inside an expanded Dux Island sheet/drawer
        if (islandHost && islandExpanded) {
            if (islandHost.inputMaskItem && isOverSubItem(islandHost.inputMaskItem, localX, localY))
                return "passthrough";
            if (islandHost.currentVisualWidth > 0 && islandHost.currentVisualHeight > 0) {
                const p = root.mapToItem(islandHost, localX, localY);
                if (p.x >= islandHost.currentVisualX
                    && p.y >= islandHost.currentVisualY
                    && p.x <= (islandHost.currentVisualX + islandHost.currentVisualWidth)
                    && p.y <= (islandHost.currentVisualY + islandHost.currentVisualHeight))
                    return "passthrough";
            }
        }

        const registry = BarWidgetService.widgetRegistry || {};
        const keys = Object.keys(registry);
        let matchedZoneId = "";
        let matchedItem = null;

        // Track outermost leading/trailing widgets along the bar axis for Fitts's Law corner/edge hits
        let leadingEntry = null;
        let leadingStart = Infinity;
        let trailingEntry = null;
        let trailingEnd = -Infinity;
        const barAlongExtent = isVertical ? root.height : root.width;

        for (let i = 0; i < keys.length; i++) {
            const entry = registry[keys[i]];
            if (!entry || !entry.item || !entry.item.visible || entry.item.width <= 0 || entry.item.height <= 0)
                continue;
            if (entry.context?.kind && entry.context.kind !== "bar")
                continue;
            if (entry.screenName && root.screenName && entry.screenName !== root.screenName)
                continue;
            const entryBarId = entry.context?.barId ?? "";
            if (entryBarId && root.barId && entryBarId !== root.barId)
                continue;

            const normId = daemon.normalizeZoneId(entry.widgetId || "");
            if (!normId)
                continue;

            const pt = root.mapToItem(entry.item, localX, localY);
            if (pt.x >= 0 && pt.y >= 0 && pt.x <= entry.item.width && pt.y <= entry.item.height) {
                matchedZoneId = normId;
                matchedItem = entry.item;
                break;
            }

            // Record along-bar bounds in overlay coordinates for screen-edge Fitts's Law matching
            const topLeft = entry.item.mapToItem(root, 0, 0);
            const itemStart = isVertical ? topLeft.y : topLeft.x;
            const itemEnd = itemStart + (isVertical ? entry.item.height : entry.item.width);
            if (itemStart < leadingStart) {
                leadingStart = itemStart;
                leadingEntry = { normId: normId, item: entry.item };
            }
            if (itemEnd > trailingEnd) {
                trailingEnd = itemEnd;
                trailingEntry = { normId: normId, item: entry.item };
            }
        }

        // Fitts's Law edge extension (matches DBarBody's edgeStrip behavior for corner cursor throws)
        if (!matchedZoneId && barAlongExtent > 0) {
            const alongCoord = isVertical ? localY : localX;
            const maxEdgeGap = 28;
            if (leadingEntry && leadingStart > 0 && leadingStart <= maxEdgeGap && alongCoord >= 0 && alongCoord < leadingStart) {
                matchedZoneId = leadingEntry.normId;
                matchedItem = leadingEntry.item;
            } else if (trailingEntry && trailingEnd < barAlongExtent && (barAlongExtent - trailingEnd) <= maxEdgeGap && alongCoord > trailingEnd && alongCoord <= barAlongExtent) {
                matchedZoneId = trailingEntry.normId;
                matchedItem = trailingEntry.item;
            }
        }

        if (!matchedZoneId) {
            matchedZoneId = isOverCompactIslandPill(localX, localY) ? "island" : "__empty__";
        }

        if (!daemon.isZoneEnabledForBar(root.barId, matchedZoneId))
            return "passthrough";

        if (matchedZoneId === "controlCenterButton"
            && daemon.controlCenterBrightnessEnabled
            && BrightnessService.brightnessAvailable) {
            const ccZone = daemon.controlCenterBrightnessZone;
            if (ccZone === "entireWidget")
                return "brightness";
            if (ccZone === "entireExceptMic") {
                if (isOverControlCenterGroup(matchedItem, "mic", localX, localY))
                    return "passthrough";
                return "brightness";
            }
            if (ccZone === "brightnessIconOnly") {
                if (isOverControlCenterGroup(matchedItem, "brightness", localX, localY))
                    return "brightness";
                if (isOverControlCenterGroup(matchedItem, "mic", localX, localY))
                    return "passthrough";
                return "volume";
            }
        }

        return "volume";
    }

    onPressed: mouse => {
        const targetKind = resolvePointAction(mouse.x, mouse.y);
        if (!daemon || targetKind === "passthrough") {
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
            daemon.performToggleMute(root.screenName);
            return;
        }

        const dirSign = action === "up" ? 1 : -1;
        const holdMode = daemon.holdRepeatMode;

        if (holdMode === "stepOnly") {
            dispatchStep(targetKind, dirSign, 1, false);
            return;
        }

        if (holdMode === "both") {
            dispatchStep(targetKind, dirSign, 1, false);
        }

        activeHoldDirection = dirSign;
        activeHoldButton = mouse.button;
        activeHoldTargetKind = targetKind;
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

        const targetKind = resolvePointAction(wheel.x, wheel.y);
        if (!daemon || targetKind === "passthrough") {
            wheel.accepted = false;
            return;
        }

        const info = InputBinding.wheelDirectionAndDelta(wheel);
        if (!info) {
            wheel.accepted = false;
            return;
        }

        if (info.isTouchpad && !daemon.touchpadEnabled) {
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
                daemon.performToggleMute(root.screenName);
            }
            return;
        }

        const dirSign = (action === "up" ? 1 : -1) * (daemon.reverseScroll ? -1 : 1);
        const now = Date.now();
        const targetChanged = lastScrollTargetKind !== targetKind;
        const isFreshGesture = (now - lastWheelEventMs) > 220 || targetChanged;
        lastWheelEventMs = now;
        lastScrollTargetKind = targetKind;

        if (info.isTouchpad) {
            if (wheel.phase === Qt.ScrollBegin || isFreshGesture || (touchpadAccum !== 0 && (touchpadAccum * dirSign) < 0))
                touchpadAccum = 0;

            touchpadAccum += dirSign * info.delta;
            const threshold = Math.max(6, daemon.touchpadThreshold || 18);
            if (Math.abs(touchpadAccum) >= threshold) {
                const steps = Math.trunc(Math.abs(touchpadAccum) / threshold);
                const sign = touchpadAccum > 0 ? 1 : -1;
                touchpadAccum -= sign * steps * threshold;
                dispatchStep(targetKind, sign, steps, true);
            }
            return;
        }

        // Only Niri, Hyprland, and MangoWC scale the 120-unit wheel detent by SettingsData.mouseScrollFactor
        const compositorScalesWheel = typeof CompositorService !== "undefined"
            && (CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango);
        const rawFactor = (compositorScalesWheel && typeof SettingsData !== "undefined" && SettingsData.mouseScrollFactor > 0)
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
            dispatchStep(targetKind, dirSign, notches, false);
            return;
        }

        if (isFreshGesture) {
            highResAccum = 0;
            dispatchStep(targetKind, dirSign, 1, false);
            return;
        }

        highResAccum += dirSign * info.delta;
        if (Math.abs(highResAccum) >= expectedNotch) {
            const notches = Math.trunc(Math.abs(highResAccum) / expectedNotch);
            const sign = highResAccum > 0 ? 1 : -1;
            highResAccum -= sign * notches * expectedNotch;
            dispatchStep(targetKind, sign, notches, false);
        }
    }
}
