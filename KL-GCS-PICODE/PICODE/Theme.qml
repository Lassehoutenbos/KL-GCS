pragma Singleton
import QtQuick

QtObject {
    // ── Surfaces (depth via subtle contrast, never pure black) ──────────────
    readonly property color bgPrimary:   "#0b0d10"
    readonly property color bgSecondary: "#12161b"
    readonly property color bgElevated:  "#1a2027"
    readonly property color bgRaised:    "#212832"   // hovered / floating layer
    readonly property color bgSunken:    "#080a0d"   // input wells, recessed areas

    // Subtle vertical page gradient (top → bottom)
    readonly property color bgGradTop:    "#0e1116"
    readonly property color bgGradBottom: "#08090c"

    // Panel gradient endpoints (used by Panel.qml + page side rails)
    readonly property color panelTop:     Qt.lighter(bgSecondary, 1.06)
    readonly property color panelBottom:  bgSecondary

    // ── Text ────────────────────────────────────────────────────────────────
    readonly property color textPrimary:   "#e8edf2"
    readonly property color textSecondary: "#8f9baa"
    readonly property color textDisabled:  "#5c6673"
    readonly property color textInverse:   "#0b0d10"   // text on bright accents

    // ── Accents ─────────────────────────────────────────────────────────────
    readonly property color accentYellow: "#e3d049"
    readonly property color accentBlue:   "#7fd6ff"

    // Soft tints (for active backgrounds, glows, ripples)
    readonly property color accentYellowSoft:    Qt.rgba(0.89, 0.82, 0.29, 0.14)
    readonly property color accentYellowGlow:    Qt.rgba(0.89, 0.82, 0.29, 0.35)
    readonly property color accentYellowFaint:   Qt.rgba(0.89, 0.82, 0.29, 0.04)
    readonly property color accentBlueSoft:      Qt.rgba(0.50, 0.84, 1.00, 0.14)
    readonly property color accentBlueGlow:      Qt.rgba(0.50, 0.84, 1.00, 0.35)
    readonly property color accentBlueFaint:     Qt.rgba(0.50, 0.84, 1.00, 0.06)

    // ── Status ──────────────────────────────────────────────────────────────
    readonly property color statusOk:   "#62d48f"
    readonly property color statusWarn: "#ffb347"
    readonly property color statusCrit: "#ff5b5b"
    readonly property color statusOkSoft:   Qt.rgba(0.38, 0.83, 0.56, 0.12)
    readonly property color statusWarnSoft: Qt.rgba(1.00, 0.70, 0.28, 0.12)
    readonly property color statusCritSoft: Qt.rgba(1.00, 0.36, 0.36, 0.12)

    // ── Borders & shadows ───────────────────────────────────────────────────
    readonly property color border:      "#2a313a"
    readonly property color borderStrong: "#3a434f"   // panel rails, divider strong
    readonly property color borderSoft:  Qt.rgba(1, 1, 1, 0.04)   // inner highlight (bevel)
    readonly property color shadow:      Qt.rgba(0, 0, 0, 0.55)
    readonly property color shadowSoft:  Qt.rgba(0, 0, 0, 0.22)

    // ── Typography ──────────────────────────────────────────────────────────
    // Bundled JetBrains Mono — guarantees identical rendering on Pi & Windows
    property FontLoader _fontMonoR: FontLoader { source: "qrc:/qt/qml/PICODE/assets/fonts/JetBrainsMono-Regular.ttf" }
    property FontLoader _fontMonoM: FontLoader { source: "qrc:/qt/qml/PICODE/assets/fonts/JetBrainsMono-Medium.ttf" }
    property FontLoader _fontMonoS: FontLoader { source: "qrc:/qt/qml/PICODE/assets/fonts/JetBrainsMono-SemiBold.ttf" }
    property FontLoader _fontMonoB: FontLoader { source: "qrc:/qt/qml/PICODE/assets/fonts/JetBrainsMono-Bold.ttf" }
    readonly property string fontMono: _fontMonoR.name || "Consolas, 'Roboto Mono', monospace"

    readonly property int fontPageTitle:    13
    readonly property int fontSectionLabel: 11
    readonly property int fontValueLarge:   32
    readonly property int fontValueMedium:  20
    readonly property int fontValueSmall:   14
    readonly property int fontButton:       13
    readonly property int fontUnit:         11
    readonly property int fontMicro:        10

    // ── Spacing scale (4-pt grid) ───────────────────────────────────────────
    readonly property int spaceXs:  4
    readonly property int spaceSm:  6
    readonly property int spaceMd:  10
    readonly property int spaceLg:  14
    readonly property int spaceXl:  20

    // ── Touch / sizing ──────────────────────────────────────────────────────
    readonly property int minTouchSize: 56
    readonly property int rowHeightSm:  28
    readonly property int rowHeightMd:  36

    // ── Radii ───────────────────────────────────────────────────────────────
    readonly property int radiusCard:   8
    readonly property int radiusButton: 6
    readonly property int radiusPill:   3
    readonly property int radiusBadge:  4

    // ── Layout ──────────────────────────────────────────────────────────────
    readonly property int statusBarH: 40
    readonly property int navBarH:    72
    readonly property int contentH:   488
    readonly property int screenW:    1024
    readonly property int screenH:    600
    readonly property int sectionHeaderH: 30
    readonly property int sectionHeaderHSm: 26

    // ── Motion tokens ───────────────────────────────────────────────────────
    readonly property int motionFast:    120   // hover, micro-feedback
    readonly property int motionMedium:  180   // tab switch, color
    readonly property int motionSlow:    320   // overlays, ripples
}
