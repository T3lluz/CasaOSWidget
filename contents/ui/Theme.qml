pragma ComponentBehavior: Bound

import QtQuick

// Centralized colors and metrics. Power-Deck inspired: dark, minimal,
// data-rich with vivid accents. Used by both compact and full
// representations so the widget looks consistent regardless of the
// active Plasma color scheme.
QtObject {
    id: theme

    readonly property color bg:          "#0f1115"
    readonly property color bgElevated:  "#171a21"
    readonly property color bgHover:     "#1f232c"
    readonly property color cardBorder:  "#262b36"
    readonly property color divider:     "#1d2129"

    readonly property color text:        "#e6e9ef"
    readonly property color textDim:     "#9aa3b2"
    readonly property color textMuted:   "#6b7280"

    readonly property color cpu:         "#22d3ee"
    readonly property color ram:         "#a78bfa"
    readonly property color disk:        "#34d399"
    readonly property color temp:        "#fb923c"
    readonly property color netRx:       "#60a5fa"
    readonly property color netTx:       "#f472b6"

    readonly property color success:     "#22c55e"
    readonly property color warning:     "#f59e0b"
    readonly property color danger:      "#ef4444"
    readonly property color info:        "#22d3ee"

    readonly property color trackBg:     "#232733"

    readonly property int radiusSm: 4
    readonly property int radiusMd: 8
    readonly property int radiusLg: 12

    function alpha(color, a) {
        return Qt.rgba(color.r, color.g, color.b, a)
    }

    function severityColor(percent) {
        if (percent < 0)   return textMuted
        if (percent >= 90) return danger
        if (percent >= 75) return warning
        if (percent >= 50) return cpu
        return success
    }
}
