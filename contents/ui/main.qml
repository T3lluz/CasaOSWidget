pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // Expose api and theme so bindings like `root.api` resolve cleanly
    // both inside this file and across Compact/Full representations.
    readonly property alias api: apiImpl
    readonly property alias theme: themeImpl

    Plasmoid.icon: "computer"
    Plasmoid.title: Plasmoid.configuration.serverName || i18n("CasaOS Homelab")

    toolTipMainText: Plasmoid.configuration.serverName || i18n("CasaOS Homelab")
    toolTipSubText: api.isConnected
        ? i18n("CPU %1% · RAM %2% · Disk %3",
               Math.round(api.cpuPercent),
               Math.round(api.memPercent),
               api.diskPairText())
        : api.statusMessage || i18n("Disconnected")

    // Always keep the panel widget in its compact, single-line form.
    // Without this, Plasma swaps in the full representation inline as soon
    // as the panel is tall/wide enough — which broke "click to expand".
    preferredRepresentation: compactRepresentation
    switchWidth: -1
    switchHeight: -1

    Theme { id: themeImpl }

    CasaOSClient {
        id: apiImpl
        baseUrl: Plasmoid.configuration.serverUrl
        username: Plasmoid.configuration.username
        password: Plasmoid.configuration.password
        refreshInterval: Plasmoid.configuration.refreshInterval
        requestTimeoutMs: Plasmoid.configuration.requestTimeoutMs
        historyLength: Plasmoid.configuration.historyLength
        tempUnit: Plasmoid.configuration.tempUnit
        netUnit: Plasmoid.configuration.netUnit
    }

    Timer {
        interval: Math.max(2, Plasmoid.configuration.refreshInterval) * 1000
        running: apiImpl.isConfigured
        repeat: true
        triggeredOnStart: true
        onTriggered: apiImpl.refresh()
    }

    Connections {
        target: Plasmoid.configuration
        function onServerUrlChanged() {
            apiImpl.accessToken = ""
            apiImpl.refresh()
        }
        function onUsernameChanged() {
            apiImpl.accessToken = ""
            apiImpl.refresh()
        }
        function onPasswordChanged() {
            apiImpl.accessToken = ""
            apiImpl.refresh()
        }
    }

    // --- dashboard opener -----------------------------------------------
    // Hoisted to the root so both compact (middle-click → dashboard) and
    // full (header dashboard button) representations can share one
    // executable data source.
    Plasma5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        function run(cmd) {
            disconnectSource(cmd)
            connectSource(cmd)
        }
    }

    function openDashboard() {
        var url = apiImpl.dashboardUrl()
        if (url.length === 0) return
        var cmd = (Plasmoid.configuration.browserCommand || "xdg-open").trim()
        if (cmd.length === 0) cmd = "xdg-open"
        exec.run(cmd + " " + url)
    }

    compactRepresentation: CompactRepresentation {
        api: root.api
        theme: root.theme
        plasmoidItem: root
    }

    fullRepresentation: FullRepresentation {
        api: root.api
        theme: root.theme
        plasmoidItem: root
    }
}
