pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    Plasmoid.icon: "computer"
    Plasmoid.title: Plasmoid.configuration.serverName || i18n("CasaOS Homelab")

    toolTipMainText: Plasmoid.configuration.serverName || i18n("CasaOS Homelab")
    toolTipSubText: api.isConnected
        ? i18n("CPU %1% · RAM %2% · Disk %3",
               Math.round(api.cpuPercent),
               Math.round(api.memPercent),
               api.diskPairText())
        : api.statusMessage || i18n("Disconnected")

    switchWidth: Kirigami.Units.gridUnit * 20
    switchHeight: Kirigami.Units.gridUnit * 10

    CasaOSClient {
        id: api
        baseUrl: Plasmoid.configuration.serverUrl
        username: Plasmoid.configuration.username
        password: Plasmoid.configuration.password
        refreshInterval: Plasmoid.configuration.refreshInterval
    }

    Timer {
        interval: Math.max(2, Plasmoid.configuration.refreshInterval) * 1000
        running: api.isConfigured
        repeat: true
        triggeredOnStart: true
        onTriggered: api.refresh()
    }

    Connections {
        target: Plasmoid.configuration
        function onServerUrlChanged() { api.refresh() }
        function onUsernameChanged() { api.accessToken = ""; api.refresh() }
        function onPasswordChanged() { api.accessToken = ""; api.refresh() }
    }

    compactRepresentation: CompactRepresentation {
        api: root.api
    }

    fullRepresentation: FullRepresentation {
        api: root.api
    }
}
