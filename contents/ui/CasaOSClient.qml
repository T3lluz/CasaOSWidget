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
    property string kernelName: ""
    property string kernelVersion: ""
    property string hostname: ""
    property double uptimeSeconds: 0
    property string platform: ""
    property string platformFamily: ""
    property string platformVersion: ""
    property string biosVendor: ""
    property string biosVersion: ""
    property string biosDate: ""
    property string motherboard: ""
    property string manufacturer: ""
    property string virtualization: ""
    property string timezone: ""
    property string bootTime: ""
    property int processCount: 0

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

    // ---- installed apps --------------------------------------------------
    // Each app: { name, title, status, running, icon }
    property var apps: []

    // ---- history (sparklines) -------------------------------------------
    property var cpuHistory: []
    property var memHistory: []

    // ---- derived ---------------------------------------------------------
    readonly property bool isConnected: status === "connected"
    readonly property bool isConfigured: baseUrl.length > 0 && username.length > 0 && password.length > 0
    readonly property int servicesHealthyCount: servicesRunning.length
    readonly property int servicesTotalCount: servicesRunning.length + servicesStopped.length
    readonly property int appsRunningCount: {
        var n = 0
        for (var i = 0; i < apps.length; i++) if (apps[i].running) n++
        return n
    }
    readonly property int appsTotalCount: apps.length

    // CasaOS reports the CPU only as a vendor keyword ("amd"/"intel"/"arm").
    // Present it in a recognisable form for the System card.
    readonly property string cpuVendorDisplay: {
        var m = String(cpuModel || "").trim().toLowerCase()
        if (m.length === 0) return ""
        if (m === "amd")   return "AMD"
        if (m === "intel") return "Intel"
        if (m === "arm")   return "ARM"
        return cpuModel
    }

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

    // Resolve an app icon reference returned by the CasaOS app_management
    // endpoint into a real URL. CasaOS variously returns:
    //   • a full https URL (e.g. jsdelivr CDN, app store)
    //   • a path relative to the CasaOS server ("/v2/...")
    //   • a bare filename
    // Anything we can't sensibly resolve becomes "" so the UI shows the
    // letter-avatar fallback.
    function resolveAppIcon(iconRef) {
        if (!iconRef) return ""
        var s = String(iconRef).trim()
        if (s.length === 0) return ""
        if (/^(https?:|data:)/i.test(s)) return s
        var base = normalizedBaseUrl()
        if (base.length === 0) return ""
        if (s.charAt(0) === "/") return base + s
        return base + "/" + s
    }

    // Normalize an app name/title into a dashboard-icons slug:
    // lowercase, spaces/underscores → hyphens, strip anything else.
    function iconSlug(s) {
        if (!s) return ""
        return String(s).toLowerCase().trim()
            .replace(/\s+/g, "-")
            .replace(/_/g, "-")
            .replace(/[^a-z0-9-]/g, "")
            .replace(/-+/g, "-")
            .replace(/^-+|-+$/g, "")
    }

    // Common CasaOS app id → dashboard-icons slug aliases, for cases where
    // the raw name doesn't match the icon repo's slug (e.g. "adguardhome").
    readonly property var _iconAliases: ({
        "adguard": "adguard-home",
        "adguardhome": "adguard-home",
        "pihole": "pi-hole",
        "homeassistant": "home-assistant",
        "hass": "home-assistant",
        "nginxproxymanager": "nginx-proxy-manager",
        "npm": "nginx-proxy-manager",
        "uptimekuma": "uptime-kuma",
        "bitwarden": "vaultwarden",
        "qbit": "qbittorrent",
        "syncthing": "syncthing",
        "nextcloud": "nextcloud"
    })

    // Build a themeable SVG logo URL from the maintained dashboard-icons
    // collection (served via the jsDelivr CDN). Used as a fallback when
    // CasaOS doesn't hand us a working icon URL.
    function dashboardIconUrl(ref) {
        var slug = iconSlug(ref)
        if (slug.length === 0) return ""
        if (_iconAliases[slug] !== undefined) slug = _iconAliases[slug]
        return "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/" + slug + ".svg"
    }

    // Ordered list of icon URLs to try for an app, best first:
    //   1. the icon CasaOS reported (if it resolves to a URL)
    //   2. dashboard-icons by display title
    //   3. dashboard-icons by app name/id
    // The UI walks this list, falling back on load errors, and shows the
    // letter avatar only once every candidate fails.
    function appIconUrls(name, title, rawIcon) {
        var out = []
        function add(u) { if (u && out.indexOf(u) < 0) out.push(u) }
        add(resolveAppIcon(rawIcon))
        add(dashboardIconUrl(title))
        add(dashboardIconUrl(name))
        return out
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

    function _pickField(obj) {
        if (!obj) return undefined
        for (var i = 1; i < arguments.length; i++) {
            var k = arguments[i]
            var v = obj[k]
            if (v !== undefined && v !== null && v !== "") return v
        }
        return undefined
    }

    function parseHardware(payload) {
        if (!payload || typeof payload !== "object" || !payload.data) {
            return
        }
        var d = payload.data
        var v

        v = _pickField(d, "drive_model", "driveModel", "DriveModel")
        if (v !== undefined) hardwareModel = String(v)
        if (hardwareModel.length === 0) {
            v = _pickField(d, "model", "Model", "product_name", "ProductName")
            if (v !== undefined) hardwareModel = String(v)
        }

        v = _pickField(d, "arch", "Arch", "architecture", "Architecture")
        if (v !== undefined) hardwareArch = String(v)

        v = _pickField(d, "os_name", "osName", "OSName", "distribution", "Distribution")
        if (v !== undefined) osName = String(v)

        v = _pickField(d, "os_version", "osVersion", "OSVersion", "distribution_version", "DistributionVersion")
        if (v !== undefined) osVersion = String(v)

        // CasaOS sometimes returns "kernel" as the kernel name ("Linux")
        // and "kernel_version" as the version ("6.5.0-…"). Keep them
        // separate so the UI can show both.
        v = _pickField(d, "kernel", "Kernel", "kernel_name", "KernelName")
        if (v !== undefined && /[a-zA-Z]/.test(String(v)) && !/^\d/.test(String(v))) {
            kernelName = String(v)
        }

        v = _pickField(d, "kernel_version", "kernelVersion", "KernelVersion")
        if (v !== undefined) {
            kernelVersion = String(v)
        } else if (kernelName.length > 0 && /^\d/.test(kernelName)) {
            // some builds return only a numeric "kernel" field
            kernelVersion = kernelName
            kernelName = ""
        }

        v = _pickField(d, "hostname", "Hostname", "HostName", "host_name")
        if (v !== undefined) hostname = String(v)

        v = _pickField(d, "uptime", "Uptime", "uptime_seconds", "UptimeSeconds")
        if (v !== undefined) uptimeSeconds = Number(v) || 0

        v = _pickField(d, "platform", "Platform")
        if (v !== undefined) platform = String(v)

        v = _pickField(d, "platform_family", "platformFamily", "PlatformFamily")
        if (v !== undefined) platformFamily = String(v)

        v = _pickField(d, "platform_version", "platformVersion", "PlatformVersion")
        if (v !== undefined) platformVersion = String(v)

        v = _pickField(d, "bios_vendor", "biosVendor", "BiosVendor", "bios", "Bios")
        if (v !== undefined) biosVendor = String(v)

        v = _pickField(d, "bios_version", "biosVersion", "BiosVersion")
        if (v !== undefined) biosVersion = String(v)

        v = _pickField(d, "bios_date", "biosDate", "BiosDate", "bios_release_date")
        if (v !== undefined) biosDate = String(v)

        v = _pickField(d, "board_name", "boardName", "BoardName",
                          "motherboard", "Motherboard", "board_product")
        if (v !== undefined) motherboard = String(v)

        v = _pickField(d, "vendor", "Vendor", "manufacturer", "Manufacturer",
                          "sys_vendor", "SystemVendor")
        if (v !== undefined) manufacturer = String(v)

        v = _pickField(d, "virtualization", "Virtualization",
                          "virt", "Virt", "virtualization_system")
        if (v !== undefined) virtualization = String(v)

        v = _pickField(d, "timezone", "Timezone", "TimeZone", "tz")
        if (v !== undefined) timezone = String(v)

        v = _pickField(d, "boot_time", "bootTime", "BootTime")
        if (v !== undefined) bootTime = String(v)

        v = _pickField(d, "procs", "Procs", "processes", "Processes", "process_count")
        if (v !== undefined) processCount = Number(v) || 0

        // CasaOS hardware/info sometimes returns a fuller CPU name here
        // than /v1/sys/utilization (which can be just the vendor on AMD).
        v = _pickField(d, "cpu_model", "cpuModel", "CPUModel", "cpu_name", "CPUName")
        if (v !== undefined && String(v).length > cpuModel.length) {
            cpuModel = String(v)
        }
    }

    function parseHealth(payload) {
        if (!payload || typeof payload !== "object" || !payload.data) {
            return
        }
        servicesRunning = payload.data.running || []
        servicesStopped = payload.data.not_running || []
    }

    function _titleFromField(t) {
        if (!t) return ""
        if (typeof t === "string") return t
        if (typeof t === "object") {
            return t.en_us || t.en_US || t.en || t["en-US"]
                || t.custom || t[Object.keys(t)[0]] || ""
        }
        return ""
    }

    function _appTitle(a) {
        if (!a) return ""
        // v2 compose apps nest the human title under store_info.title.
        var si = a.store_info || a.storeInfo
        if (si) {
            var st = _titleFromField(si.title)
            if (st.length) return st
        }
        var direct = _titleFromField(a.title)
        if (direct.length) return direct
        return a.name || a.app_name || a.id || a.main_app || ""
    }

    // Pull an icon reference out of an app entry, accounting for the
    // several shapes CasaOS uses (v2 compose nests it under store_info).
    function _appIcon(a) {
        if (!a) return ""
        var si = a.store_info || a.storeInfo
        if (si && si.icon) return si.icon
        if (a.icon) return a.icon
        if (a.image && a.image.icon) return a.image.icon
        return ""
    }

    function _appIsRunning(status) {
        if (!status) return false
        var s = String(status).toLowerCase()
        return s.indexOf("running") >= 0 || s === "up" || s === "active" || s === "started"
    }

    function parseApps(payload) {
        if (!payload) return false
        var data = payload.data !== undefined ? payload.data : payload
        var arr = []
        if (Array.isArray(data)) {
            arr = data
        } else if (data && typeof data === "object") {
            for (var k in data) {
                var v = data[k]
                if (v && typeof v === "object") {
                    arr.push(Object.assign({ name: k }, v))
                }
            }
        } else {
            return false
        }

        var out = []
        for (var i = 0; i < arr.length; i++) {
            var a = arr[i]
            if (!a || typeof a !== "object") continue
            var status = a.status !== undefined ? a.status
                       : (a.state !== undefined ? a.state : "")
            if (status && typeof status === "object") {
                status = status.main || status.status || status.state || ""
            }
            var name = a.name
                || (a.compose && a.compose.name)
                || a.main_app || a.app_name || a.id || ""
            out.push({
                name: name,
                title: _appTitle(a) || name,
                status: String(status || ""),
                running: _appIsRunning(status),
                icon: _appIcon(a)
            })
        }
        out.sort(function(x, y) {
            if (x.running !== y.running) return x.running ? -1 : 1
            return x.title.toLowerCase() < y.title.toLowerCase() ? -1 : 1
        })
        apps = out
        return true
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
            var pending = 4
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

            request("GET", "/v2/app_management/compose", null, function(ok, httpStatus, parsed) {
                if (ok && parseApps(parsed)) {
                    doneOne(true, "")
                    return
                }
                request("GET", "/v1/apps", null, function(ok2, http2, parsed2) {
                    if (ok2) parseApps(parsed2)
                    doneOne(true, "")
                })
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
