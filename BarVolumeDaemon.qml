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

    // Zone coverage (shared checklist + per-bar checklist)
    readonly property bool perBarCoverageEnabled: pluginData.perBarCoverageEnabled === true
    readonly property var disabledZones: {
        if (Array.isArray(pluginData.disabledZones))
            return pluginData.disabledZones;
        const migrated = [];
        if (pluginData.passThroughWorkspaceSwitcher === true)
            migrated.push("workspaceSwitcher");
        if (pluginData.passThroughMediaWidget === true)
            migrated.push("music");
        return migrated;
    }
    readonly property var perBarDisabledZones: (pluginData.perBarDisabledZones && typeof pluginData.perBarDisabledZones === "object" && !Array.isArray(pluginData.perBarDisabledZones))
        ? pluginData.perBarDisabledZones
        : ({})

    // Control Center hover brightness
    readonly property bool controlCenterBrightnessEnabled: pluginData.controlCenterBrightnessEnabled !== false
    readonly property string controlCenterBrightnessZone: pluginData.controlCenterBrightnessZone || "entireWidget"
    readonly property int brightnessStep: {
        if (pluginData.brightnessStep !== undefined && pluginData.brightnessStep !== null) {
            const parsed = Number(pluginData.brightnessStep);
            if (!isNaN(parsed) && parsed >= 1)
                return Math.min(25, Math.round(parsed));
        }
        return 5;
    }

    // Volume step, touchpad, cap & direction
    readonly property bool useSystemVolumeStep: pluginData.useSystemVolumeStep !== false
    readonly property int volumeStep: {
        if (useSystemVolumeStep)
            return Math.max(1, AudioService.wheelVolumeStep || 5);
        if (pluginData.volumeStep !== undefined && pluginData.volumeStep !== null) {
            const parsed = Number(pluginData.volumeStep);
            if (!isNaN(parsed) && parsed >= 1)
                return Math.min(50, Math.round(parsed));
        }
        return Math.max(1, AudioService.wheelVolumeStep || 5);
    }
    readonly property bool touchpadEnabled: pluginData.touchpadEnabled === true
    readonly property int touchpadStep: {
        if (pluginData.touchpadStep !== undefined && pluginData.touchpadStep !== null) {
            const parsed = Number(pluginData.touchpadStep);
            if (!isNaN(parsed) && parsed >= 1)
                return Math.min(25, Math.round(parsed));
        }
        return 1;
    }
    readonly property int touchpadThreshold: {
        if (pluginData.touchpadThreshold !== undefined && pluginData.touchpadThreshold !== null) {
            const parsed = Number(pluginData.touchpadThreshold);
            if (!isNaN(parsed) && parsed >= 6)
                return Math.min(100, Math.round(parsed));
        }
        return 18;
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
    readonly property bool useDefaultBindings: pluginData.useDefaultBindings !== false
    readonly property var volumeUpBinding: useDefaultBindings
        ? InputBinding.DEFAULT_VOLUME_UP
        : InputBinding.normalizeBinding(pluginData.volumeUpBinding, InputBinding.DEFAULT_VOLUME_UP)
    readonly property var volumeDownBinding: useDefaultBindings
        ? InputBinding.DEFAULT_VOLUME_DOWN
        : InputBinding.normalizeBinding(pluginData.volumeDownBinding, InputBinding.DEFAULT_VOLUME_DOWN)
    readonly property var toggleMuteBinding: useDefaultBindings
        ? InputBinding.DEFAULT_TOGGLE_MUTE
        : InputBinding.normalizeBinding(pluginData.toggleMuteBinding, InputBinding.DEFAULT_TOGGLE_MUTE)
    readonly property int acceptedButtonsMask: InputBinding.acceptedButtonsMask([volumeUpBinding, volumeDownBinding, toggleMuteBinding])

    // Button hold-to-repeat configuration (snapped to clean ms increments)
    readonly property string holdRepeatMode: pluginData.holdRepeatMode || "both"
    readonly property int holdInitialDelayMs: {
        if (pluginData.holdInitialDelayMs !== undefined && pluginData.holdInitialDelayMs !== null) {
            const parsed = Number(pluginData.holdInitialDelayMs);
            if (!isNaN(parsed) && parsed >= 100)
                return Math.max(100, Math.min(1000, Math.round(parsed / 50) * 50));
        }
        return 350;
    }
    readonly property int holdRepeatIntervalMs: {
        if (pluginData.holdRepeatIntervalMs !== undefined && pluginData.holdRepeatIntervalMs !== null) {
            const parsed = Number(pluginData.holdRepeatIntervalMs);
            if (!isNaN(parsed) && parsed >= 25)
                return Math.max(25, Math.min(500, Math.round(parsed / 25) * 25));
        }
        return 75;
    }

    // Mute & Feedback behavior (OSD duration always active when showOsd is enabled, snapped to 50ms)
    readonly property string muteOnVolumeChange: pluginData.muteOnVolumeChange || "unmuteOnUp"
    readonly property bool showOsd: pluginData.showOsd !== false
    readonly property int customOsdDurationMs: {
        if (pluginData.customOsdDurationMs !== undefined && pluginData.customOsdDurationMs !== null) {
            const parsed = Number(pluginData.customOsdDurationMs);
            if (!isNaN(parsed) && parsed >= 300)
                return Math.max(300, Math.min(6000, Math.round(parsed / 50) * 50));
        }
        return 2000;
    }
    readonly property bool playFeedbackSound: pluginData.playFeedbackSound !== false

    // Pending PipeWire volume write tracking & overdrive max-volume sync
    property var pendingVolumeWrites: []
    property bool writingVolume: false
    property double lastWriteTimeMs: 0
    property double lastPluginOsdActionMs: 0
    property string lastPluginOsdKind: "volume"
    property var savedSinkMaxVolumes: ({})

    // Managed overlay instances across active bar surfaces
    property var activeOverlays: []
    readonly property string cacheBustQuery: "?rev=" + Date.now()
    property var overlayComp: null

    function syncOverdriveMaxVolume() {
        const sinkName = AudioService.sink?.name ?? "";
        if (!sinkName || typeof SessionData.setDeviceMaxVolume !== "function" || typeof SessionData.getDeviceMaxVolume !== "function")
            return;

        if (overrideMaxVolume && customMaxVolume > 100) {
            if (savedSinkMaxVolumes[sinkName] === undefined) {
                const nextSaved = Object.assign({}, savedSinkMaxVolumes);
                nextSaved[sinkName] = SessionData.getDeviceMaxVolume(sinkName);
                savedSinkMaxVolumes = nextSaved;
            }
            if (SessionData.getDeviceMaxVolume(sinkName) < customMaxVolume)
                SessionData.setDeviceMaxVolume(sinkName, customMaxVolume);
        } else if (savedSinkMaxVolumes[sinkName] !== undefined) {
            const prevMax = savedSinkMaxVolumes[sinkName];
            const nextSaved = Object.assign({}, savedSinkMaxVolumes);
            delete nextSaved[sinkName];
            savedSinkMaxVolumes = nextSaved;
            SessionData.setDeviceMaxVolume(sinkName, prevMax);
        }
    }

    function restoreAllSavedSinkMaxVolumes() {
        if (typeof SessionData.setDeviceMaxVolume !== "function")
            return;
        const names = Object.keys(savedSinkMaxVolumes || {});
        for (let i = 0; i < names.length; i++) {
            const name = names[i];
            if (savedSinkMaxVolumes[name] !== undefined)
                SessionData.setDeviceMaxVolume(name, savedSinkMaxVolumes[name]);
        }
        savedSinkMaxVolumes = {};
    }

    onOverrideMaxVolumeChanged: syncOverdriveMaxVolume()
    onCustomMaxVolumeChanged: syncOverdriveMaxVolume()

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
        target: SettingsData
        function onBarConfigsChanged() {
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
            root.syncOverdriveMaxVolume();
        }
    }

    Timer {
        id: osdDurationSyncTimer
        interval: 25
        repeat: false
        onTriggered: root.applyActiveOsdDuration(root.lastPluginOsdKind)
    }

    Connections {
        target: AudioService.sink?.audio ?? null
        ignoreUnknownSignals: true
        function onVolumeChanged() {
            if (root.showOsd && (Date.now() - root.lastPluginOsdActionMs) < 800) {
                Qt.callLater(() => root.applyActiveOsdDuration("volume"));
                osdDurationSyncTimer.restart();
            } else if ((Date.now() - root.lastPluginOsdActionMs) >= 800) {
                root.restoreDefaultOsdDuration("volume");
            }

            if (root.writingVolume || root.pendingVolumeWrites.length === 0)
                return;
            const currentPct = Math.round((AudioService.sink?.audio?.volume ?? 0) * 100);
            const idx = root.pendingVolumeWrites.indexOf(currentPct);
            root.pendingVolumeWrites = idx < 0 ? [] : root.pendingVolumeWrites.slice(idx + 1);
        }

        function onMutedChanged() {
            if (root.showOsd && (Date.now() - root.lastPluginOsdActionMs) < 800) {
                Qt.callLater(() => root.applyActiveOsdDuration("volume"));
                osdDurationSyncTimer.restart();
            } else if ((Date.now() - root.lastPluginOsdActionMs) >= 800) {
                root.restoreDefaultOsdDuration("volume");
            }
        }
    }

    Connections {
        target: BrightnessService
        function onBrightnessChanged(osdShown) {
            if (osdShown && root.showOsd && (Date.now() - root.lastPluginOsdActionMs) < 800) {
                Qt.callLater(() => root.applyActiveOsdDuration("brightness"));
                osdDurationSyncTimer.restart();
            } else if ((Date.now() - root.lastPluginOsdActionMs) >= 800) {
                root.restoreDefaultOsdDuration("brightness");
            }
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
            return `step=${root.volumeStep}% osdMs=${root.customOsdDurationMs} ccBright=${root.controlCenterBrightnessEnabled}(${root.controlCenterBrightnessZone},${root.brightnessStep}%) perBar=${root.perBarCoverageEnabled} overlays=${attached.length} [${attached.join(", ")}]`;
        }

        function volumeUp(): string {
            root.performVolumeStep(1, root.volumeStep, "");
            return "ok";
        }

        function volumeDown(): string {
            root.performVolumeStep(-1, root.volumeStep, "");
            return "ok";
        }

        function toggleMute(): string {
            root.performToggleMute("");
            return "ok";
        }
    }

    function normalizeZoneId(rawId) {
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

    function isZoneEnabledForBar(barId, zoneId) {
        const norm = normalizeZoneId(zoneId);
        if (!norm)
            return true;
        const bKey = barId || "default";
        if (perBarCoverageEnabled && Array.isArray(perBarDisabledZones[bKey]))
            return perBarDisabledZones[bKey].indexOf(norm) === -1;
        return disabledZones.indexOf(norm) === -1;
    }

    function isBarTargetEnabled(barId, screenName) {
        if (targetAllBars)
            return true;
        const key = (barId || "default") + "@" + (screenName || "");
        return disabledBarTargets.indexOf(key) === -1;
    }

    function applyActiveOsdDuration(expectedKind) {
        if (!showOsd)
            return;
        const map = OSDManager.currentOSDsByScreen || {};
        const screens = Object.keys(map);
        for (let i = 0; i < screens.length; i++) {
            const osd = map[screens[i]];
            if (!osd)
                continue;
            const kindMatch = expectedKind
                ? osd.osdKind === expectedKind
                : (osd.osdKind === "volume" || osd.osdKind === "brightness");
            if (kindMatch) {
                osd.autoHideInterval = customOsdDurationMs;
                if (osd.shouldBeVisible && typeof osd.resetHideTimer === "function")
                    osd.resetHideTimer();
            }
        }
    }

    function showLimitVolumeOsd(screenName) {
        if (!showOsd || !SettingsData.osdVolumeEnabled)
            return;
        const map = OSDManager.currentOSDsByScreen || {};
        const keys = screenName && map[screenName] ? [screenName] : Object.keys(map);
        for (let i = 0; i < keys.length; i++) {
            const osd = map[keys[i]];
            if (osd && osd.osdKind === "volume") {
                osd.autoHideInterval = customOsdDurationMs;
                if (typeof osd.show === "function")
                    osd.show();
                else if (osd.shouldBeVisible && typeof osd.resetHideTimer === "function")
                    osd.resetHideTimer();
            }
        }
    }

    function restoreDefaultOsdDuration(onlyKind) {
        const map = OSDManager.currentOSDsByScreen || {};
        const screens = Object.keys(map);
        for (let i = 0; i < screens.length; i++) {
            const osd = map[screens[i]];
            if (!osd)
                continue;
            const kindMatch = onlyKind
                ? osd.osdKind === onlyKind
                : (osd.osdKind === "volume" || osd.osdKind === "brightness");
            if (kindMatch && osd.autoHideInterval !== 3000)
                osd.autoHideInterval = 3000;
        }
    }

    function resolveBrightnessDevice(screenName) {
        const devs = BrightnessService.devices || [];
        if (!BrightnessService.brightnessAvailable || devs.length === 0)
            return "";

        if (screenName) {
            const screens = Quickshell.screens || [];
            const scr = screens.find(s => s.name === screenName);
            const pinKey = scr ? SettingsData.getScreenDisplayName(scr) : screenName;
            const pinned = pinKey ? (CacheData.brightnessDevicePins || {})[pinKey] : "";
            if (pinned && devs.some(d => d.id === pinned))
                return pinned;

            if (BrightnessService.isInternalPanelName(screenName)) {
                const internal = devs.find(d => d.class === "backlight")
                    || devs.find(d => d.class === "software" && d.id.split(":").pop() === screenName);
                if (internal)
                    return internal.id;
            }

            const externalScreens = screens.filter(s => !BrightnessService.isInternalPanelName(s.name));
            const ddcDevs = devs.filter(d => d.class === "ddc");
            if (ddcDevs.length === 1 && externalScreens.length <= 1)
                return ddcDevs[0].id;

            const byScreen = devs.find(d => d.class !== "leds" && d.id.split(":").pop() === screenName);
            if (byScreen)
                return byScreen.id;

            if (ddcDevs.length > 0)
                return ddcDevs[0].id;
        }

        return BrightnessService.getPreferredDevice() || BrightnessService.getDefaultDevice();
    }

    function performBrightnessStep(dirSign, stepAmount, screenName) {
        if (!BrightnessService.brightnessAvailable || dirSign === 0)
            return;

        const deviceName = resolveBrightnessDevice(screenName);
        if (!deviceName)
            return;

        const deviceInfo = BrightnessService.getCurrentDeviceInfoByName(deviceName);
        const minVal = BrightnessService.brightnessMinimum(deviceInfo);
        const maxVal = BrightnessService.brightnessMaximum(deviceInfo);
        const currentVal = BrightnessService.getDeviceBrightness(deviceName);
        const stepVal = Math.max(1, Math.round(stepAmount));
        const nextVal = Math.max(minVal, Math.min(maxVal, currentVal + dirSign * stepVal));

        lastPluginOsdActionMs = Date.now();
        lastPluginOsdKind = "brightness";
        BrightnessService.lastIpcDevice = deviceName;
        if (deviceName !== BrightnessService.currentDevice)
            BrightnessService.setCurrentDevice(deviceName, false);

        BrightnessService.setBrightness(nextVal, deviceName, !showOsd);

        if (showOsd) {
            Qt.callLater(() => applyActiveOsdDuration("brightness"));
            osdDurationSyncTimer.restart();
        }
    }

    function performVolumeStep(dirSign, stepAmount, screenName) {
        const audio = AudioService.sink?.audio;
        if (!audio || dirSign === 0)
            return;

        syncOverdriveMaxVolume();

        const now = Date.now();
        lastPluginOsdActionMs = now;
        lastPluginOsdKind = "volume";
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

        if (nextVol === currentVol) {
            showLimitVolumeOsd(screenName);
            return;
        }

        writingVolume = true;
        audio.volume = nextVol / 100;
        writingVolume = false;
        lastWriteTimeMs = now;
        pendingVolumeWrites = pendingVolumeWrites.concat([nextVol]).slice(-10);

        if (showOsd) {
            Qt.callLater(() => applyActiveOsdDuration("volume"));
            osdDurationSyncTimer.restart();
        }

        if (playFeedbackSound)
            AudioService.playVolumeChangeSoundIfEnabled();
    }

    function performToggleMute(screenName) {
        const audio = AudioService.sink?.audio;
        if (!audio)
            return;
        lastPluginOsdActionMs = Date.now();
        lastPluginOsdKind = "volume";
        if (!showOsd)
            SessionData.suppressOSDTemporarily();
        AudioService.toggleMute();
        if (showOsd) {
            Qt.callLater(() => applyActiveOsdDuration("volume"));
            osdDurationSyncTimer.restart();
        }
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
            if (!win || win.dot === true || win.free === true)
                continue;
            const kids = win.contentItem?.children;
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
            if (entry && entry.body && bodies.indexOf(entry.body) !== -1 && entry.overlay && entry.overlay.parent) {
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
        syncOverdriveMaxVolume();
        syncOverlays();
        resyncTimer.restart();
    }

    Component.onDestruction: {
        resyncTimer.stop();
        osdDurationSyncTimer.stop();
        restoreDefaultOsdDuration("");
        restoreAllSavedSinkMaxVolumes();
        destroyAllOverlays();
        AudioService.removeRef();
    }
}
