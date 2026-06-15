pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    // ---- configuration (bound from main.qml) -----------------------------
    property string baseUrl: ""
    property string username: ""
    property string password: ""
    property int refreshInterval: 5
    property int historyLength: 60
    property int requestTimeoutMs: 6000
    property string tempUnit: "C"            // "C" or "F"
    property string netUnit: "mbps"          // "mbps" | "mbytes" | "kbytes" | "auto"

    // ---- connection state ------------------------------------------------
    // status values: "idle" | "connecting" | "connected" | "error"
    property string status: "idle"
    property string statusMessage: ""
    property string accessToken: ""
    property string casaVersion: ""
    property double lastUpdateMs: 0

    // ---- CPU / RAM / disk ------------------------------------------------
    property real cpuPercent: -1
    property int cpuCores: 0
    property int cpuTemp: -1
    property string cpuModel: ""
    property var cpuPower: ({})

    property real memPercent: -1
    property double memUsed: 0
    property double memTotal: 0

    property real diskPercent: -1
    property double diskUsed: 0
    property double diskTotal: 0
    property double diskAvail: 0
    property bool diskHealthy: true

    // ---- system / hardware ----------------------------------------------
    property string hardwareModel: ""
    property string hardwareArch: ""
    property string osName: ""
    property string osVersion: ""
    property string kernelVersion: ""
    property string hostname: ""
    property double uptimeSeconds: 0

    // ---- network ---------------------------------------------------------
    property var networkInterfaces: []
    property real netRxRate: 0
    property real netTxRate: 0
    property var netRxHistory: []
    property var netTxHistory: []
    property double _lastNetRx: 0
    property double _lastNetTx: 0
    property double _lastNetTime: 0

    // ---- services --------------------------------------------------------
    property var servicesRunning: []
    property var servicesStopped: []

    // ---- history (sparklines) -------------------------------------------
    property var cpuHistory: []
    property var memHistory: []

    // ---- derived ---------------------------------------------------------
    readonly property bool isConnected: status === "connected"
    readonly property bool isConfigured: baseUrl.length > 0 && username.length > 0 && password.length > 0
    readonly property int servicesHealthyCount: servicesRunning.length
    readonly property int servicesTotalCount: servicesRunning.length + servicesStopped.length

    signal dataUpdated()
    signal restartRequested(bool success, string message)
    signal rebootConfirmRequested()

    // Surfaced to the full representation so the existing PromptDialog
    // can be opened from anywhere (e.g. middle-click on the panel).
    function requestRebootConfirm() {
        rebootConfirmRequested()
    }

    // ---- helpers ---------------------------------------------------------
    function normalizedBaseUrl() {
        var url = (baseUrl || "").trim()
        if (url.length === 0) {
            return ""
        }
        if (!/^https?:\/\//i.test(url)) {
            url = "http://" + url
        }
        while (url.endsWith("/")) {
            url = url.slice(0, -1)
        }
        return url
    }

    function dashboardUrl() {
        return normalizedBaseUrl()
    }

    function formatBytes(bytes) {
        if (bytes < 0 || isNaN(bytes)) {
            return "—"
        }
        var units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var value = bytes
        var unit = 0
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024
            unit++
        }
        return value < 10 ? value.toFixed(1) + " " + units[unit] : Math.round(value) + " " + units[unit]
    }

    function formatBytesShort(bytes) {
        if (bytes < 0 || isNaN(bytes)) {
            return "—"
        }
        var units = ["B", "K", "M", "G", "T", "P"]
        var value = bytes
        var unit = 0
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024
            unit++
        }
        if (unit === 0) {
            return Math.round(value) + units[unit]
        }
        return (value < 10 ? value.toFixed(1) : Math.round(value)) + units[unit]
    }

    function formatRate(bytesPerSec) {
        if (bytesPerSec <= 0 || isNaN(bytesPerSec)) {
            switch (netUnit) {
                case "mbps":   return "0 Mbps"
                case "mbytes": return "0 MB/s"
                case "kbytes": return "0 KB/s"
                default:       return "0 B/s"
            }
        }
        switch (netUnit) {
            case "mbps": {
                var mbps = bytesPerSec * 8 / 1000000
                if (mbps < 0.1)  return mbps.toFixed(2) + " Mbps"
                if (mbps < 10)   return mbps.toFixed(1) + " Mbps"
                return Math.round(mbps) + " Mbps"
            }
            case "mbytes": {
                var mb = bytesPerSec / (1024 * 1024)
                if (mb < 0.1)    return mb.toFixed(2) + " MB/s"
                if (mb < 10)     return mb.toFixed(1) + " MB/s"
                return Math.round(mb) + " MB/s"
            }
            case "kbytes": {
                var kb = bytesPerSec / 1024
                if (kb < 10)     return kb.toFixed(1) + " KB/s"
                return Math.round(kb) + " KB/s"
            }
            default:
                return formatBytesShort(bytesPerSec) + "/s"
        }
    }

    function formatTemp(celsius) {
        if (celsius === undefined || celsius === null || celsius < 0) {
            return "—"
        }
        if (tempUnit === "F") {
            return Math.round(celsius * 9 / 5 + 32) + "°F"
        }
        return Math.round(celsius) + "°C"
    }

    function formatUptime(seconds) {
        if (!seconds || seconds <= 0) {
            return "—"
        }
        var s = Math.floor(seconds)
        var d = Math.floor(s / 86400); s -= d * 86400
        var h = Math.floor(s / 3600);  s -= h * 3600
        var m = Math.floor(s / 60)
        if (d > 0) return d + "d " + h + "h " + m + "m"
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    function diskPairText() {
        if (diskTotal <= 0) {
            return "—"
        }
        return formatBytesShort(diskUsed) + "/" + formatBytesShort(diskTotal)
    }

    // Compact disk text without unit suffix. Picks GB if the disk is
    // < 4 TiB, otherwise TB. Always shown as integers so it fits in
    // tight panels — e.g. "245/931".
    function diskPairCompact() {
        if (diskTotal <= 0) {
            return "—"
        }
        var GB = 1024 * 1024 * 1024
        var TB = GB * 1024
        if (diskTotal >= 4 * TB) {
            return (diskUsed / TB).toFixed(1) + "/" + (diskTotal / TB).toFixed(1)
        }
        return Math.round(diskUsed / GB) + "/" + Math.round(diskTotal / GB)
    }

    function diskPairLongText() {
        if (diskTotal <= 0) {
            return "—"
        }
        return formatBytes(diskUsed) + " / " + formatBytes(diskTotal)
    }

    function percentColor(percent) {
        if (percent < 0) {
            return "#6b7280"
        }
        if (percent >= 90) {
            return "#ef4444"
        }
        if (percent >= 75) {
            return "#f59e0b"
        }
        if (percent >= 50) {
            return "#22d3ee"
        }
        return "#22c55e"
    }

    function pushHistory() {
        if (cpuPercent >= 0) {
            var cpu = cpuHistory.slice()
            cpu.push(cpuPercent)
            while (cpu.length > historyLength) {
                cpu.shift()
            }
            cpuHistory = cpu
        }
        if (memPercent >= 0) {
            var mem = memHistory.slice()
            mem.push(memPercent)
            while (mem.length > historyLength) {
                mem.shift()
            }
            memHistory = mem
        }
    }

    function pushNetHistory() {
        var rxArr = netRxHistory.slice()
        rxArr.push(netRxRate)
        while (rxArr.length > historyLength) rxArr.shift()
        netRxHistory = rxArr

        var txArr = netTxHistory.slice()
        txArr.push(netTxRate)
        while (txArr.length > historyLength) txArr.shift()
        netTxHistory = txArr
    }

    function updateNetworkRates() {
        var totalRx = 0
        var totalTx = 0
        for (var i = 0; i < networkInterfaces.length; i++) {
            var n = networkInterfaces[i]
            totalRx += (n.bytesRecv || n.bytes_recv || 0)
            totalTx += (n.bytesSent || n.bytes_sent || 0)
        }
        var now = Date.now()
        if (_lastNetTime > 0) {
            var dt = (now - _lastNetTime) / 1000
            if (dt > 0) {
                netRxRate = Math.max(0, (totalRx - _lastNetRx) / dt)
                netTxRate = Math.max(0, (totalTx - _lastNetTx) / dt)
            }
        }
        _lastNetRx = totalRx
        _lastNetTx = totalTx
        _lastNetTime = now
    }

    // ---- low-level HTTP --------------------------------------------------
    function request(method, path, body, callback) {
        var xhr = new XMLHttpRequest()
        var url = normalizedBaseUrl() + path
        var done = false

        function finish(ok, httpStatus, parsed, text) {
            if (done) return
            done = true
            callback(ok, httpStatus, parsed, text)
        }

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return
            }
            var ok = xhr.status >= 200 && xhr.status < 300
            var parsed = null
            if (xhr.responseText && xhr.responseText.length > 0) {
                try {
                    parsed = JSON.parse(xhr.responseText)
                } catch (e) {
                    parsed = xhr.responseText
                }
            }
            finish(ok, xhr.status, parsed, xhr.responseText)
        }

        try {
            xhr.open(method, url)
            xhr.timeout = requestTimeoutMs
            xhr.ontimeout = function() { finish(false, 0, null, "timeout") }
            xhr.setRequestHeader("Content-Type", "application/json")
            xhr.setRequestHeader("Accept", "application/json")
            if (accessToken.length > 0) {
                xhr.setRequestHeader("Authorization", accessToken)
            }
            if (body !== undefined && body !== null) {
                xhr.send(JSON.stringify(body))
            } else {
                xhr.send()
            }
        } catch (err) {
            finish(false, 0, null, String(err))
        }
    }

    // ---- response parsing ------------------------------------------------
    function extractToken(payload) {
        if (!payload || typeof payload !== "object") {
            return ""
        }
        var data = payload.data
        if (!data) {
            return ""
        }
        var token = data.token
        if (!token) {
            return ""
        }
        if (token.access_token) {
            return token.access_token
        }
        if (token.AccessToken) {
            return token.AccessToken
        }
        return ""
    }

    function parseUtilization(payload) {
        if (!payload || typeof payload !== "object") {
            return false
        }
        var data = payload.data
        if (!data) {
            return false
        }

        if (data.cpu) {
            cpuPercent = data.cpu.percent !== undefined ? data.cpu.percent : -1
            cpuCores = data.cpu.num !== undefined ? data.cpu.num : cpuCores
            cpuTemp = data.cpu.temperature !== undefined ? data.cpu.temperature : -1
            cpuModel = data.cpu.model !== undefined ? data.cpu.model : cpuModel
            cpuPower = data.cpu.power !== undefined ? data.cpu.power : {}
        }

        if (data.mem) {
            memUsed = data.mem.used !== undefined ? data.mem.used : 0
            memTotal = data.mem.total !== undefined ? data.mem.total : 0
            memPercent = data.mem.usedPercent !== undefined ? data.mem.usedPercent : (memTotal > 0 ? (memUsed / memTotal) * 100 : -1)
        }

        var disk = data.sys_disk
        if (disk) {
            diskUsed = disk.used !== undefined ? disk.used : 0
            diskTotal = disk.size !== undefined ? disk.size : 0
            diskAvail = disk.avail !== undefined ? disk.avail : 0
            diskHealthy = disk.health !== undefined ? disk.health : true
            diskPercent = diskTotal > 0 ? (diskUsed / diskTotal) * 100 : -1
        }

        if (data.net && data.net.length !== undefined) {
            networkInterfaces = data.net
            updateNetworkRates()
        }

        return true
    }

    function parseHardware(payload) {
        if (!payload || typeof payload !== "object" || !payload.data) {
            return
        }
        var d = payload.data
        if (d.drive_model !== undefined) hardwareModel = d.drive_model
        if (d.model !== undefined && hardwareModel.length === 0) hardwareModel = d.model
        if (d.arch !== undefined) hardwareArch = d.arch
        if (d.os_name !== undefined) osName = d.os_name
        if (d.os_version !== undefined) osVersion = d.os_version
        if (d.kernel !== undefined) kernelVersion = d.kernel
        if (d.kernel_version !== undefined) kernelVersion = d.kernel_version
        if (d.hostname !== undefined) hostname = d.hostname
        if (d.uptime !== undefined) uptimeSeconds = Number(d.uptime) || 0
    }

    function parseHealth(payload) {
        if (!payload || typeof payload !== "object" || !payload.data) {
            return
        }
        servicesRunning = payload.data.running || []
        servicesStopped = payload.data.not_running || []
    }

    // ---- public actions --------------------------------------------------
    function fetchVersion() {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200 && xhr.responseText) {
                casaVersion = xhr.responseText.trim()
            }
        }
        try {
            xhr.open("GET", normalizedBaseUrl() + "/v1/sys/version/current")
            xhr.send()
        } catch (e) {}
    }

    function login(callback) {
        if (!isConfigured) {
            status = "error"
            statusMessage = qsTr("Set server URL, username and password in widget settings")
            if (callback) callback(false)
            return
        }

        if (status !== "connected") {
            status = "connecting"
        }

        request("POST", "/v1/users/login", {
            username: username,
            password: password
        }, function(ok, httpStatus, parsed) {
            if (!ok || !parsed) {
                status = "error"
                statusMessage = httpStatus === 0
                    ? qsTr("Cannot reach %1").arg(normalizedBaseUrl() || "server")
                    : qsTr("Login failed (HTTP %1)").arg(httpStatus)
                accessToken = ""
                if (callback) callback(false)
                return
            }

            var token = extractToken(parsed)
            if (token.length === 0) {
                status = "error"
                statusMessage = parsed && parsed.message ? String(parsed.message) : qsTr("No access token in response")
                accessToken = ""
                if (callback) callback(false)
                return
            }

            accessToken = token
            if (callback) callback(true)
        })
    }

    function fetchStats() {
        if (!isConfigured) {
            status = "error"
            statusMessage = qsTr("Not configured")
            return
        }

        var afterAuth = function() {
            var pending = 3
            var firstError = ""

            function doneOne(success, errMsg) {
                if (!success && firstError.length === 0 && errMsg) {
                    firstError = errMsg
                }
                pending--
                if (pending === 0) {
                    if (firstError.length > 0) {
                        status = "error"
                        statusMessage = firstError
                    } else {
                        status = "connected"
                        statusMessage = ""
                        lastUpdateMs = Date.now()
                        pushHistory()
                        pushNetHistory()
                        dataUpdated()
                    }
                }
            }

            request("GET", "/v1/sys/utilization", null, function(ok, httpStatus, parsed) {
                if (!ok || !parseUtilization(parsed)) {
                    if (httpStatus === 401) {
                        accessToken = ""
                    }
                    doneOne(false, httpStatus === 0
                        ? qsTr("Server unreachable")
                        : qsTr("Utilization HTTP %1").arg(httpStatus))
                    return
                }
                doneOne(true, "")
            })

            request("GET", "/v1/sys/hardware/info", null, function(ok, httpStatus, parsed) {
                if (ok && parsed && parsed.data) {
                    parseHardware(parsed)
                    doneOne(true, "")
                } else {
                    request("GET", "/v1/sys/hardware", null, function(ok2, http2, parsed2) {
                        if (ok2) parseHardware(parsed2)
                        doneOne(true, "")
                    })
                }
            })

            request("GET", "/v2/casaos/health/services", null, function(ok, httpStatus, parsed) {
                if (ok) parseHealth(parsed)
                doneOne(true, "")
            })
        }

        if (accessToken.length === 0) {
            login(function(success) {
                if (success) {
                    fetchVersion()
                    afterAuth()
                }
            })
        } else {
            afterAuth()
        }
    }

    function refresh() {
        fetchStats()
    }

    // Restart the host system via CasaOS PUT /v1/sys/restart.
    // CasaOS also exposes POST /v1/sys/restart which only kills the CasaOS
    // service; PUT /v1/sys/{state} reboots the whole machine.
    function rebootServer() {
        if (!isConfigured) {
            restartRequested(false, qsTr("Widget is not configured"))
            return
        }

        var attempt = function() {
            request("PUT", "/v1/sys/restart", {}, function(ok, httpStatus, parsed) {
                if (ok) {
                    restartRequested(true, qsTr("Reboot requested"))
                    status = "connecting"
                    statusMessage = qsTr("Server rebooting…")
                    accessToken = ""
                } else if (httpStatus === 401) {
                    accessToken = ""
                    login(function(success) {
                        if (success) {
                            request("PUT", "/v1/sys/restart", {}, function(ok2, http2) {
                                if (ok2) {
                                    restartRequested(true, qsTr("Reboot requested"))
                                    status = "connecting"
                                    statusMessage = qsTr("Server rebooting…")
                                    accessToken = ""
                                } else {
                                    restartRequested(false, qsTr("Reboot failed (HTTP %1)").arg(http2))
                                }
                            })
                        } else {
                            restartRequested(false, qsTr("Cannot authenticate for reboot"))
                        }
                    })
                } else {
                    restartRequested(false, httpStatus === 0
                        ? qsTr("Cannot reach server")
                        : qsTr("Reboot failed (HTTP %1)").arg(httpStatus))
                }
            })
        }

        if (accessToken.length === 0) {
            login(function(success) {
                if (success) attempt()
                else restartRequested(false, qsTr("Cannot authenticate for reboot"))
            })
        } else {
            attempt()
        }
    }

    Component.onCompleted: {
        fetchVersion()
        refresh()
    }
}
