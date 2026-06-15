pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    property string baseUrl: ""
    property string username: ""
    property string password: ""
    property int refreshInterval: 5
    property int historyLength: 60

    property string status: "idle"
    property string statusMessage: ""
    property string accessToken: ""
    property string casaVersion: ""

    property real cpuPercent: -1
    property int cpuCores: 0
    property int cpuTemp: -1
    property string cpuModel: ""
    property var cpuPower: ({})

    property real memPercent: -1
    property int memUsed: 0
    property int memTotal: 0

    property real diskPercent: -1
    property int diskUsed: 0
    property int diskTotal: 0
    property int diskAvail: 0
    property bool diskHealthy: true

    property string hardwareModel: ""
    property string hardwareArch: ""
    property var networkInterfaces: []

    property var servicesRunning: []
    property var servicesStopped: []

    property var cpuHistory: []
    property var memHistory: []

    property real netRxRate: 0
    property real netTxRate: 0

    property int _lastNetRx: 0
    property int _lastNetTx: 0
    property int _lastNetTime: 0

    readonly property bool isConnected: status === "connected"
    readonly property bool isConfigured: baseUrl.length > 0 && username.length > 0 && password.length > 0
    readonly property int servicesHealthyCount: servicesRunning.length
    readonly property int servicesTotalCount: servicesRunning.length + servicesStopped.length

    signal dataUpdated()

    function normalizedBaseUrl() {
        var url = baseUrl.trim()
        if (url.endsWith("/")) {
            url = url.slice(0, -1)
        }
        return url
    }

    function formatBytes(bytes) {
        if (bytes < 0 || isNaN(bytes)) {
            return "—"
        }
        var units = ["B", "KB", "MB", "GB", "TB"]
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
        var units = ["B", "K", "M", "G", "T"]
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

    function diskPairText() {
        if (diskTotal <= 0) {
            return "—"
        }
        return formatBytesShort(diskUsed) + "/" + formatBytesShort(diskTotal)
    }

    function diskPairLongText() {
        if (diskTotal <= 0) {
            return "—"
        }
        return formatBytes(diskUsed) + " / " + formatBytes(diskTotal)
    }

    function formatRate(bytesPerSec) {
        if (bytesPerSec <= 0 || isNaN(bytesPerSec)) {
            return "0 B/s"
        }
        return formatBytes(bytesPerSec) + "/s"
    }

    function percentColor(percent) {
        if (percent < 0) {
            return "#888888"
        }
        if (percent >= 90) {
            return "#e74c3c"
        }
        if (percent >= 75) {
            return "#f39c12"
        }
        return "#27ae60"
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

    function updateNetworkRates() {
        var totalRx = 0
        var totalTx = 0
        for (var i = 0; i < networkInterfaces.length; i++) {
            var n = networkInterfaces[i]
            totalRx += n.bytesRecv || 0
            totalTx += n.bytesSent || 0
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

    function request(method, path, body, callback) {
        var xhr = new XMLHttpRequest()
        var url = normalizedBaseUrl() + path
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return
            }
            var ok = xhr.status >= 200 && xhr.status < 300
            var parsed = null
            if (xhr.responseText.length > 0) {
                try {
                    parsed = JSON.parse(xhr.responseText)
                } catch (e) {
                    parsed = xhr.responseText
                }
            }
            callback(ok, xhr.status, parsed, xhr.responseText)
        }
        xhr.open(method, url)
        xhr.setRequestHeader("Content-Type", "application/json")
        if (accessToken.length > 0) {
            xhr.setRequestHeader("Authorization", accessToken)
        }
        if (body !== undefined && body !== null) {
            xhr.send(JSON.stringify(body))
        } else {
            xhr.send()
        }
    }

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
            cpuCores = data.cpu.num !== undefined ? data.cpu.num : 0
            cpuTemp = data.cpu.temperature !== undefined ? data.cpu.temperature : -1
            cpuModel = data.cpu.model !== undefined ? data.cpu.model : ""
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

        if (data.net && data.net.length) {
            networkInterfaces = data.net
            updateNetworkRates()
        }

        return true
    }

    function parseHardware(payload) {
        if (!payload || typeof payload !== "object" || !payload.data) {
            return
        }
        hardwareModel = payload.data.drive_model !== undefined ? payload.data.drive_model : ""
        hardwareArch = payload.data.arch !== undefined ? payload.data.arch : ""
    }

    function parseHealth(payload) {
        if (!payload || typeof payload !== "object" || !payload.data) {
            return
        }
        servicesRunning = payload.data.running || []
        servicesStopped = payload.data.not_running || []
    }

    function login(callback) {
        if (!isConfigured) {
            status = "error"
            statusMessage = qsTr("Configure server URL, username, and password")
            callback(false)
            return
        }

        status = "connecting"
        request("POST", "/v1/users/login", {
            username: username,
            password: password
        }, function(ok, httpStatus, parsed) {
            if (!ok || !parsed) {
                status = "error"
                statusMessage = qsTr("Login failed (HTTP %1)").arg(httpStatus)
                accessToken = ""
                callback(false)
                return
            }

            var token = extractToken(parsed)
            if (token.length === 0) {
                status = "error"
                statusMessage = parsed.message !== undefined ? parsed.message : qsTr("No access token in response")
                accessToken = ""
                callback(false)
                return
            }

            accessToken = token
            callback(true)
        })
    }

    function fetchVersion() {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                casaVersion = xhr.responseText.trim()
            }
        }
        xhr.open("GET", normalizedBaseUrl() + "/v1/sys/version/current")
        xhr.send()
    }

    function fetchStats() {
        if (!isConfigured) {
            status = "error"
            statusMessage = qsTr("Not configured")
            return
        }

        var afterAuth = function() {
            var pending = 3
            var hadError = false

            function doneOne(success) {
                if (!success) {
                    hadError = true
                }
                pending--
                if (pending === 0) {
                    if (hadError) {
                        status = "error"
                        if (statusMessage.length === 0) {
                            statusMessage = qsTr("Failed to fetch server stats")
                        }
                    } else {
                        status = "connected"
                        statusMessage = ""
                        pushHistory()
                        dataUpdated()
                    }
                }
            }

            request("GET", "/v1/sys/utilization", null, function(ok, httpStatus, parsed) {
                if (!ok || !parseUtilization(parsed)) {
                    statusMessage = qsTr("Utilization request failed (HTTP %1)").arg(httpStatus)
                    if (httpStatus === 401) {
                        accessToken = ""
                    }
                    doneOne(false)
                    return
                }
                doneOne(true)
            })

            request("GET", "/v1/sys/hardware", null, function(ok, httpStatus, parsed) {
                if (ok) {
                    parseHardware(parsed)
                }
                doneOne(ok)
            })

            request("GET", "/v2/casaos/health/services", null, function(ok, httpStatus, parsed) {
                if (ok) {
                    parseHealth(parsed)
                }
                doneOne(true)
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

    Component.onCompleted: {
        fetchVersion()
        refresh()
    }
}
