import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "./InputBinding.js" as InputBinding

Scope {
    id: root

    property string pluginId: ""
    property var pluginService: null
    property var popoutService: null
    property var pluginData: ({})

    function loadPluginData() {
        if (!pluginId) {
            pluginData = {};
            return;
        }
        pluginData = SettingsData.getPluginSettingsForPlugin(pluginId) || {};
    }

    onPluginIdChanged: loadPluginData()
    onPluginServiceChanged: loadPluginData()

    Connections {
        target: root.pluginService
        enabled: root.pluginService !== null
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId)
                root.loadPluginData();
        }
    }

    // Bar & Display targeting
    readonly property bool targetAllBars: pluginData.targetAllBars !== false
    readonly property var disabledBarTargets: Array.isArray(pluginData.disabledBarTargets) ? pluginData.disabledBarTargets : []

    // Zone coverage & per-widget exceptions
    readonly property string coverageMode: pluginData.coverageMode || "entireBar"
    readonly property bool passThroughWorkspaceSwitcher: pluginData.passThroughWorkspaceSwitcher === true
    readonly property bool passThroughMediaWidget: pluginData.passThroughMediaWidget === true
    readonly property bool passThroughControlCenterSubIcons: pluginData.passThroughControlCenterSubIcons === true

    // Volume step, cap & direction
    readonly property int volumeStep: {
        if (pluginData.volumeStep !== undefined && pluginData.volumeStep !== null) {
            const parsed = Number(pluginData.volumeStep);
            if (!isNaN(parsed) && parsed >= 1)
                return Math.min(50, Math.round(parsed));
        }
        return Math.max(1, AudioService.wheelVolumeStep || 5);
    }
    readonly property int touchpadStep: {
        if (pluginData.touchpadStep !== undefined && pluginData.touchpadStep !== null) {
            const parsed = Number(pluginData.touchpadStep);
            if (!isNaN(parsed) && parsed >= 1)
                return Math.min(25, Math.round(parsed));
        }
        return 1;
    }
    readonly property bool overrideMaxVolume: pluginData.overrideMaxVolume === true
    readonly property int customMaxVolume: {
        if (pluginData.customMaxVolume !== undefined && pluginData.customMaxVolume !== null) {
            const parsed = Number(pluginData.customMaxVolume);
            if (!isNaN(parsed) && parsed >= 10)
                return Math.min(150, Math.round(parsed));
        }
        return 100;
    }
    readonly property bool reverseScroll: pluginData.reverseScroll === true

    // Input bindings
    readonly property var volumeUpBinding: InputBinding.normalizeBinding(pluginData.volumeUpBinding, InputBinding.DEFAULT_VOLUME_UP)
    readonly property var volumeDownBinding: InputBinding.normalizeBinding(pluginData.volumeDownBinding, InputBinding.DEFAULT_VOLUME_DOWN)
    readonly property var toggleMuteBinding: InputBinding.normalizeBinding(pluginData.toggleMuteBinding, InputBinding.DEFAULT_TOGGLE_MUTE)
    readonly property int acceptedButtonsMask: InputBinding.acceptedButtonsMask([volumeUpBinding, volumeDownBinding, toggleMuteBinding])

    // Button hold-to-repeat configuration
    readonly property string holdRepeatMode: pluginData.holdRepeatMode || "both"
    readonly property int holdInitialDelayMs: {
        if (pluginData.holdInitialDelayMs !== undefined && pluginData.holdInitialDelayMs !== null) {
            const parsed = Number(pluginData.holdInitialDelayMs);
            if (!isNaN(parsed) && parsed >= 50)
                return Math.min(2000, Math.round(parsed));
        }
        return 350;
    }
    readonly property int holdRepeatIntervalMs: {
        if (pluginData.holdRepeatIntervalMs !== undefined && pluginData.holdRepeatIntervalMs !== null) {
            const parsed = Number(pluginData.holdRepeatIntervalMs);
            if (!isNaN(parsed) && parsed >= 15)
                return Math.min(1000, Math.round(parsed));
        }
        return 80;
    }

    // Mute & Feedback behavior
    readonly property string muteOnVolumeChange: pluginData.muteOnVolumeChange || "unmuteOnUp"
    readonly property bool showOsd: pluginData.showOsd !== false
    readonly property bool playFeedbackSound: pluginData.playFeedbackSound !== false

    // Pending PipeWire volume write tracking (prevents dropped scroll detents)
    property var pendingVolumeWrites: []
    property bool writingVolume: false
    property double lastWriteTimeMs: 0

    // Managed overlay instances across active bar surfaces
    property var activeOverlays: []
    readonly property string cacheBustQuery: "?rev=" + Date.now()
    property var overlayComp: null

    Timer {
        id: resyncTimer
        interval: 250
        repeat: false
        onTriggered: root.syncOverlays()
    }

    Connections {
        target: KeyboardFocus
        function onBarWindowsChanged() {
            root.syncOverlays();
            resyncTimer.restart();
        }
    }

    Connections {
        target: BarWidgetService
        function onFrameHostedBarsChanged() {
            root.syncOverlays();
            resyncTimer.restart();
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            resyncTimer.restart();
        }
    }

    Connections {
        target: AudioService
        function onSinkChanged() {
            root.pendingVolumeWrites = [];
        }
    }

    Connections {
        target: AudioService.sink?.audio ?? null
        ignoreUnknownSignals: true
        function onVolumeChanged() {
            if (root.writingVolume || root.pendingVolumeWrites.length === 0)
                return;
            const currentPct = Math.round((AudioService.sink?.audio?.volume ?? 0) * 100);
            const idx = root.pendingVolumeWrites.indexOf(currentPct);
            root.pendingVolumeWrites = idx < 0 ? [] : root.pendingVolumeWrites.slice(idx + 1);
        }
    }

    IpcHandler {
        target: "barVolume"

        function status(): string {
            const attached = [];
            for (let i = 0; i < root.activeOverlays.length; i++) {
                const entry = root.activeOverlays[i];
                const ov = entry?.overlay;
                if (ov)
                    attached.push(`${ov.barId}@${ov.screenName}(targetEnabled=${ov.targetEnabled},revealed=${ov.barRevealed},buttons=${ov.acceptedButtons},w=${Math.round(ov.width)}x${Math.round(ov.height)})`);
            }
            return `step=${root.volumeStep}% coverage=${root.coverageMode} overlays=${attached.length} [${attached.join(", ")}]`;
        }

        function volumeUp(): string {
            root.performVolumeStep(1, root.volumeStep);
            return "ok";
        }

        function volumeDown(): string {
            root.performVolumeStep(-1, root.volumeStep);
            return "ok";
        }

        function toggleMute(): string {
            root.performToggleMute();
            return "ok";
        }
    }

    function isBarTargetEnabled(barId, screenName) {
        if (targetAllBars)
            return true;
        const key = (barId || "default") + "@" + (screenName || "");
        return disabledBarTargets.indexOf(key) === -1;
    }

    function performVolumeStep(dirSign, stepAmount) {
        const audio = AudioService.sink?.audio;
        if (!audio || dirSign === 0)
            return;

        const now = Date.now();
        if (now - lastWriteTimeMs > 600)
            pendingVolumeWrites = [];

        const maxVol = overrideMaxVolume ? customMaxVolume : AudioService.sinkMaxVolume;
        const stepVal = Math.max(1, Math.round(stepAmount));
        const currentVol = pendingVolumeWrites.length > 0
            ? pendingVolumeWrites[pendingVolumeWrites.length - 1]
            : Math.round((audio.volume ?? 0) * 100);
        const nextVol = Math.max(0, Math.min(maxVol, currentVol + dirSign * stepVal));

        if (!showOsd)
            SessionData.suppressOSDTemporarily();

        if (audio.muted) {
            if (muteOnVolumeChange === "unmuteAlways" || (muteOnVolumeChange === "unmuteOnUp" && dirSign > 0))
                audio.muted = false;
        }

        if (nextVol === currentVol)
            return;

        writingVolume = true;
        audio.volume = nextVol / 100;
        writingVolume = false;
        lastWriteTimeMs = now;
        pendingVolumeWrites = pendingVolumeWrites.concat([nextVol]).slice(-10);

        if (playFeedbackSound)
            AudioService.playVolumeChangeSoundIfEnabled();
    }

    function performToggleMute() {
        const audio = AudioService.sink?.audio;
        if (!audio)
            return;
        if (!showOsd)
            SessionData.suppressOSDTemporarily();
        AudioService.toggleMute();
    }

    function findOverlayTarget(barBody) {
        if (!barBody || !barBody.children)
            return { parentItem: barBody, unitInset: null };

        // Locate topBarContainer (the Item inside topBarMouseArea whose direct child is barUnitInset with spacingPx)
        // so the overlay moves with autoHide animations and keeps topBarMouseArea.containsMouse active.
        const stack = [{ node: barBody, depth: 0 }];
        while (stack.length > 0) {
            const current = stack.shift();
            const children = current.node?.children;
            if (!children)
                continue;
            for (let i = 0; i < children.length; i++) {
                const ch = children[i];
                if (!ch)
                    continue;
                if (ch.spacingPx !== undefined && current.node !== barBody)
                    return { parentItem: current.node, unitInset: ch };
                if (current.depth < 3 && ch.children && ch.children.length > 0)
                    stack.push({ node: ch, depth: current.depth + 1 });
            }
        }
        return { parentItem: barBody, unitInset: null };
    }

    function collectBarBodies() {
        const bodies = [];
        const winList = KeyboardFocus.barWindows || [];
        for (let i = 0; i < winList.length; i++) {
            const win = winList[i];
            const kids = win?.contentItem?.children;
            if (!kids)
                continue;
            for (let j = 0; j < kids.length; j++) {
                const candidate = kids[j];
                if (candidate && candidate.barConfig !== undefined && candidate.barRevealed !== undefined) {
                    if (bodies.indexOf(candidate) === -1)
                        bodies.push(candidate);
                }
            }
        }

        const frameMap = BarWidgetService.frameHostedBars || {};
        const screenKeys = Object.keys(frameMap);
        for (let s = 0; s < screenKeys.length; s++) {
            const perScreen = frameMap[screenKeys[s]] || {};
            const barIds = Object.keys(perScreen);
            for (let b = 0; b < barIds.length; b++) {
                const body = perScreen[barIds[b]];
                if (body && bodies.indexOf(body) === -1)
                    bodies.push(body);
            }
        }
        return bodies;
    }

    function syncOverlays() {
        const bodies = collectBarBodies();
        const kept = [];

        for (let i = 0; i < activeOverlays.length; i++) {
            const entry = activeOverlays[i];
            if (entry && entry.body && bodies.indexOf(entry.body) !== -1 && entry.overlay) {
                kept.push(entry);
            } else if (entry && entry.overlay) {
                try {
                    entry.overlay.destroy();
                } catch (e) {}
            }
        }

        if (!overlayComp) {
            const url = Qt.resolvedUrl("./BarOverlay.qml") + cacheBustQuery;
            const comp = Qt.createComponent(url);
            if (comp.status !== Component.Ready) {
                console.error("BarVolume: failed to compile BarOverlay.qml:", comp.errorString());
                return;
            }
            overlayComp = comp;
        }

        for (let i = 0; i < bodies.length; i++) {
            const body = bodies[i];
            let alreadyAttached = false;
            for (let k = 0; k < kept.length; k++) {
                if (kept[k].body === body) {
                    alreadyAttached = true;
                    break;
                }
            }
            if (alreadyAttached)
                continue;

            const target = findOverlayTarget(body);
            const parentItem = target.parentItem;
            if (!parentItem)
                continue;

            // Clean up any stale overlay left over on parentItem
            const existingChildren = parentItem.children || [];
            for (let c = existingChildren.length - 1; c >= 0; c--) {
                const child = existingChildren[c];
                if (child && child.objectName === "__duxBarVolumeOverlay") {
                    try {
                        child.destroy();
                    } catch (e) {}
                }
            }

            const overlay = overlayComp.createObject(parentItem, {
                daemon: root,
                barBody: body,
                barUnitInset: target.unitInset
            });
            if (overlay) {
                kept.push({
                    body: body,
                    parentItem: parentItem,
                    overlay: overlay
                });
            }
        }

        activeOverlays = kept;
    }

    function destroyAllOverlays() {
        for (let i = 0; i < activeOverlays.length; i++) {
            const entry = activeOverlays[i];
            if (entry && entry.overlay) {
                try {
                    entry.overlay.destroy();
                } catch (e) {}
            }
        }
        activeOverlays = [];
    }

    Component.onCompleted: {
        loadPluginData();
        AudioService.addRef();
        syncOverlays();
        resyncTimer.restart();
    }

    Component.onDestruction: {
        resyncTimer.stop();
        destroyAllOverlays();
        AudioService.removeRef();
    }
}
