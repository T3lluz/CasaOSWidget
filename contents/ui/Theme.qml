pragma Singleton
import QtQuick

// Power-Deck app-pack theme singleton.
//
// This holds every visual decision the widget makes that does NOT come
// from the user's Plasma color scheme: the accent palette, animation
// timings and a couple of helpers. Backgrounds, base text colors and
// spacing are intentionally NOT defined here — components pull those from
// `Kirigami.Theme` / `Kirigami.Units` directly so the widget follows the
// active color scheme (see THEME_GUIDE §0 + §2).
//
// Semantic role names used by CasaOSWidget (cpu, ram, disk, success, …)
// are mapped onto the Power-Deck palette below and all collapse to the
// single selected accent when monochrome mode is on.
QtObject {
    id: theme

    // ---- theme mode ----
    property bool monochrome: false
    property int accentChoice: 0

    // ---- base palette ----
    readonly property color hueAccent: "#7d93f0"     // primary interactive
    readonly property color hueAccentBright: "#9aacf5"
    readonly property color hueRed: "#f25563"        // danger / critical only
    readonly property color hueRedBright: "#ff6b78"
    readonly property color hueTeal: "#2dd4bf"
    readonly property color hueGreen: "#34d399"
    readonly property color hueBlue: "#56b6f0"
    readonly property color hueAmber: "#f4b73d"

    // ---- monochrome accent options ----
    readonly property var monoAccents: [
        { name: "White",  base: "#e6e9ef", bright: "#ffffff" },
        { name: "Green",  base: "#34d399", bright: "#5fe6b5" },
        { name: "Teal",   base: "#2dd4bf", bright: "#5fe6d6" },
        { name: "Orange", base: "#fb923c", bright: "#fdb877" },
        { name: "Red",    base: "#f2596a", bright: "#ff7180" },
        { name: "Blue",   base: "#56b6f0", bright: "#85ccf6" },
        { name: "Purple", base: "#a78bfa", bright: "#c1acfc" }
    ]
    readonly property int monoIndex: Math.max(0, Math.min(accentChoice, monoAccents.length - 1))
    readonly property color monoSel: monoAccents[monoIndex].base
    readonly property color monoSelBright: monoAccents[monoIndex].bright

    // ---- neutral grayscale chrome (monochrome theme) ----
    readonly property color monoText: "#e9ecf2"
    readonly property color monoNeutral: "#aeb4be"

    // ---- active palette ----
    readonly property color accent: monochrome ? monoSel : hueAccent
    readonly property color accentBright: monochrome ? monoSelBright : hueAccentBright
    readonly property color red: monochrome ? monoSel : hueRed
    readonly property color redBright: monochrome ? monoSelBright : hueRedBright
    readonly property color teal: monochrome ? monoSel : hueTeal
    readonly property color green: monochrome ? monoSel : hueGreen
    readonly property color blue: monochrome ? monoSel : hueBlue
    readonly property color amber: monochrome ? monoSel : hueAmber

    // Neutral wordmark / faint label tone.
    readonly property color muted: monochrome ? monoNeutral : "#9aa7bd"

    // Section-header glyph tints.
    readonly property color iconHeader: monochrome ? monoNeutral : "#8da4c0"
    readonly property color iconGraphics: monochrome ? monoSel : "#a78bfa"  // violet
    readonly property color iconAnime: monochrome ? monoSel : "#f472b6"     // pink
    readonly property color iconKbd: monochrome ? monoSel : "#60a5fa"       // blue
    readonly property color iconRefresh: monochrome ? monoSel : "#22d3ee"   // cyan
    readonly property color iconCharge: monochrome ? monoSel : "#34d399"    // green
    readonly property color iconFn: monochrome ? monoSel : "#f4b73d"        // amber

    // ---- CasaOS semantic roles (mapped onto the pack palette) ----
    // Per-metric accents. Each goes grayscale in monochrome mode.
    readonly property color cpu:    monochrome ? monoSel : "#22d3ee"  // cyan
    readonly property color ram:    monochrome ? monoSel : "#a78bfa"  // violet
    readonly property color disk:   monochrome ? monoSel : "#34d399"  // green
    readonly property color temp:   monochrome ? monoSel : "#fb923c"  // orange
    readonly property color netRx:  monochrome ? monoSel : "#60a5fa"  // blue
    readonly property color netTx:  monochrome ? monoSel : "#f472b6"  // pink

    // Status semantics.
    readonly property color success: monochrome ? monoSel : hueGreen
    readonly property color warning: monochrome ? monoSel : hueAmber
    readonly property color danger:  monochrome ? monoSel : hueRed
    readonly property color info:    monochrome ? monoSel : hueTeal

    // ---- animation ----
    readonly property int durFast: 140
    readonly property int durMed: 240
    readonly property int durSlow: 380
    readonly property int easeOut: Easing.OutCubic
    readonly property int easeBack: Easing.OutBack

    // Opacity for content whose feature is toggled off.
    readonly property real offOpacity: 0.32

    // ---- corner radii (small fixed shapes; cards derive from Kirigami) ----
    readonly property int radiusSm: 4
    readonly property int radiusMd: 8
    readonly property int radiusLg: 12

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function severityColor(percent) {
        if (percent < 0)   return muted
        if (percent >= 90) return danger
        if (percent >= 75) return warning
        if (percent >= 50) return cpu
        return success
    }
}
