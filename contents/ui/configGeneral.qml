import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: root

    property alias cfg_serverUrl: serverUrlField.text
    property alias cfg_serverName: serverNameField.text
    property alias cfg_username: usernameField.text
    property alias cfg_password: passwordField.text
    property alias cfg_refreshInterval: refreshSpin.value
    property int cfg_compactDisplay

    Kirigami.FormLayout {
        QQC2.TextField {
            id: serverUrlField
            Kirigami.FormData.label: i18n("Server URL:")
            placeholderText: i18n("http://100.x.x.x or http://192.168.1.10")
        }

        QQC2.TextField {
            id: serverNameField
            Kirigami.FormData.label: i18n("Display name:")
        }

        QQC2.TextField {
            id: usernameField
            Kirigami.FormData.label: i18n("Username:")
        }

        QQC2.TextField {
            id: passwordField
            Kirigami.FormData.label: i18n("Password:")
            echoMode: TextInput.Password
        }

        QQC2.SpinBox {
            id: refreshSpin
            Kirigami.FormData.label: i18n("Refresh (s):")
            from: 2
            to: 120
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Panel display:")
            model: [
                i18n("Full — stats with progress bars"),
                i18n("Compact — stats without bars"),
                i18n("Minimal — stats only, no server name")
            ]
            currentIndex: root.cfg_compactDisplay
            onActivated: function(index) { root.cfg_compactDisplay = index }
        }
    }
}
