// Note: Wayland layer-shell bars use WlrKeyboardFocus.None, so wl_pointer events
// never carry live keyboard modifiers when another window is focused — and QtWayland
// (QWaylandInputDevice::Keyboard::handleFocusLost) leaves stale XKB modifiers stuck
// in mXkbState whenever a focused shell popup closes while Super/Alt/Ctrl/Shift is held.
// Bindings therefore match purely by scroll direction or mouse button, ignoring modifiers.

const DEFAULT_VOLUME_UP = Object.freeze({
    kind: "wheel",
    dir: "up",
    modifiers: 0
});

const DEFAULT_VOLUME_DOWN = Object.freeze({
    kind: "wheel",
    dir: "down",
    modifiers: 0
});

const DEFAULT_TOGGLE_MUTE = Object.freeze({
    kind: "button",
    button: 4, // Qt.MiddleButton
    modifiers: 0
});

const NONE_BINDING = Object.freeze({
    kind: "none",
    modifiers: 0
});

function normalizeBinding(raw, fallback) {
    if (!raw || typeof raw !== "object" || typeof raw.kind !== "string")
        return fallback;
    if (raw.kind === "none") {
        return {
            kind: "none",
            modifiers: 0
        };
    }
    if (raw.kind === "wheel") {
        const dir = (raw.dir === "up" || raw.dir === "down" || raw.dir === "left" || raw.dir === "right") ? raw.dir : "up";
        return {
            kind: "wheel",
            dir: dir,
            modifiers: 0
        };
    }
    if (raw.kind === "button") {
        const btn = Number(raw.button) || 0;
        if (btn <= 0 || btn === Qt.LeftButton)
            return fallback;
        return {
            kind: "button",
            button: btn,
            modifiers: 0
        };
    }
    return fallback;
}

function isTouchpadWheel(wheel) {
    if (!wheel || wheel.phase === Qt.NoScrollPhase)
        return false;
    return wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0;
}

function wheelDirectionAndDelta(wheel) {
    if (!wheel)
        return null;
    const usePixels = isTouchpadWheel(wheel);
    // QtWayland's Pointer::flushScrollEvent() swaps X and Y deltas whenever Qt.AltModifier
    // is set in mXkbState (including when Alt is stuck after a shortcut like Mod+Alt+L).
    // Unswap so hardware vertical/horizontal scroll axes stay consistent.
    const altSwapped = (wheel.modifiers & Qt.AltModifier) !== 0;
    const pixelX = altSwapped ? wheel.pixelDelta.y : wheel.pixelDelta.x;
    const pixelY = altSwapped ? wheel.pixelDelta.x : wheel.pixelDelta.y;
    const angleX = altSwapped ? wheel.angleDelta.y : wheel.angleDelta.x;
    const angleY = altSwapped ? wheel.angleDelta.x : wheel.angleDelta.y;

    const dx = usePixels && pixelX !== 0 ? pixelX : angleX;
    const dy = usePixels && pixelY !== 0 ? pixelY : angleY;
    if (dx === 0 && dy === 0)
        return null;

    let dir = "";
    let primaryDelta = 0;
    if (Math.abs(dy) >= Math.abs(dx)) {
        dir = dy > 0 ? "up" : "down";
        primaryDelta = Math.abs(dy);
    } else {
        dir = dx > 0 ? "left" : "right";
        primaryDelta = Math.abs(dx);
    }

    return {
        dir: dir,
        delta: primaryDelta,
        rawAngleX: angleX,
        rawAngleY: angleY,
        isTouchpad: usePixels
    };
}

function matchesWheel(binding, info) {
    if (!binding || binding.kind !== "wheel" || !info)
        return false;
    return binding.dir === info.dir;
}

function matchesButton(binding, button) {
    if (!binding || binding.kind !== "button")
        return false;
    return binding.button === button;
}

function acceptedButtonsMask(bindings) {
    let mask = 0;
    if (!Array.isArray(bindings))
        return mask;
    for (let i = 0; i < bindings.length; i++) {
        const b = bindings[i];
        if (b && b.kind === "button" && b.button > 0)
            mask |= b.button;
    }
    return mask;
}

function buttonLabel(button) {
    switch (button) {
    case Qt.LeftButton:
        return "Left Click (M1)";
    case Qt.RightButton:
        return "Right Click (M2)";
    case Qt.MiddleButton:
        return "Middle Click (M3)";
    case Qt.BackButton:
        return "Side Back (M4)";
    case Qt.ForwardButton:
        return "Side Forward (M5)";
    case 32:
        return "Extra Button (M6)";
    case 64:
        return "Extra Button (M7)";
    case 128:
        return "Extra Button (M8)";
    case 256:
        return "Extra Button (M9)";
    default:
        return "Mouse Button (" + button + ")";
    }
}

function wheelLabel(dir) {
    switch (dir) {
    case "up":
        return "Scroll Up";
    case "down":
        return "Scroll Down";
    case "left":
        return "Scroll Left";
    case "right":
        return "Scroll Right";
    default:
        return "Scroll";
    }
}

function formatBinding(binding) {
    if (!binding || binding.kind === "none")
        return "Disabled (None)";
    if (binding.kind === "wheel")
        return wheelLabel(binding.dir);
    if (binding.kind === "button")
        return buttonLabel(binding.button);
    return "Disabled (None)";
}
