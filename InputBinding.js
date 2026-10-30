.pragma library

const MODIFIER_MASK = Qt.ControlModifier | Qt.ShiftModifier | Qt.AltModifier | Qt.MetaModifier;

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

function cleanModifiers(mods) {
    return (mods || 0) & MODIFIER_MASK;
}

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
            modifiers: cleanModifiers(raw.modifiers)
        };
    }
    if (raw.kind === "button") {
        const btn = Number(raw.button) || 0;
        if (btn <= 0)
            return fallback;
        return {
            kind: "button",
            button: btn,
            modifiers: cleanModifiers(raw.modifiers)
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
    const dx = usePixels && wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x : wheel.angleDelta.x;
    const dy = usePixels && wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y;
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
        rawAngleX: wheel.angleDelta.x,
        rawAngleY: wheel.angleDelta.y,
        isTouchpad: usePixels,
        modifiers: cleanModifiers(wheel.modifiers)
    };
}

function matchesWheel(binding, info) {
    if (!binding || binding.kind !== "wheel" || !info)
        return false;
    if (cleanModifiers(binding.modifiers) !== info.modifiers)
        return false;
    if (binding.dir === info.dir)
        return true;

    // On Wayland/Qt, holding Shift with a vertical scroll wheel often translates
    // vertical detents into angleDelta.x while angleDelta.y is 0.
    if ((binding.modifiers & Qt.ShiftModifier) !== 0 && info.rawAngleY === 0 && info.rawAngleX !== 0) {
        if (binding.dir === "up" && info.rawAngleX > 0)
            return true;
        if (binding.dir === "down" && info.rawAngleX < 0)
            return true;
    }
    return false;
}

function matchesButton(binding, button, modifiers) {
    if (!binding || binding.kind !== "button")
        return false;
    return binding.button === button && cleanModifiers(binding.modifiers) === cleanModifiers(modifiers);
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

function formatModifiers(mods) {
    const clean = cleanModifiers(mods);
    const parts = [];
    if (clean & Qt.ControlModifier)
        parts.push("Ctrl");
    if (clean & Qt.AltModifier)
        parts.push("Alt");
    if (clean & Qt.ShiftModifier)
        parts.push("Shift");
    if (clean & Qt.MetaModifier)
        parts.push("Super");
    return parts.length > 0 ? parts.join(" + ") + " + " : "";
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
    const prefix = formatModifiers(binding.modifiers);
    if (binding.kind === "wheel")
        return prefix + wheelLabel(binding.dir);
    if (binding.kind === "button")
        return prefix + buttonLabel(binding.button);
    return "Disabled (None)";
}
