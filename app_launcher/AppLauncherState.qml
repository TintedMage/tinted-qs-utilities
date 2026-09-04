// AppLauncherState.qml
pragma Singleton
import QtQml
import QtCore
import Quickshell

Singleton {
    id: root

    // Application state
    property bool isVisible: false
    property string searchQuery: ""

    // Persistent settings configuration
    property var _settings: Settings {
        location: Qt.resolvedUrl("applauncher.conf")
        category: "AppLauncher"
        property string recentIdsStr: "[]"
    }
    // Bind directly to settings to prevent lifecycle race conditions during Component.onCompleted
    property var recentIds: JSON.parse(_settings.recentIdsStr || "[]")

    // Derived properties consumed by UI
    readonly property bool isSearching: searchQuery.trim() !== ""
    readonly property var currentModel: isSearching ? searchResults : defaultList

    // Unfiltered raw applications data
    property var allApps: {
        // Track applications object to force re-evaluation when Quickshell finishes asynchronous parsing
        let _track = DesktopEntries.applications
        let arr = []
        let vals = DesktopEntries.applications.values
        for (let i = 0; i < vals.length; i++) {
            arr.push(vals[i])
        }
        return arr
    }

    // Baseline alphabetical application list
    property var allAppsSorted: allApps.slice().sort((a, b) => a.name.localeCompare(b.name))

    // List generated against active user query
    property var searchResults: {
        let q = searchQuery.trim().toLowerCase()
        if (q === "") return []

        return allApps.filter(e => {
                if (e.name.toLowerCase().indexOf(q) !== -1) return true
                if (e.genericName && e.genericName.toLowerCase().indexOf(q) !== -1) return true
                if (e.keywords) {
                    for (let i = 0; i < e.keywords.length; i++) {
                        if (e.keywords[i].toLowerCase().indexOf(q) !== -1) return true
                    }
                }
                return false
        }).sort((a, b) => a.name.localeCompare(b.name))
    }

    // Resolves entry models based on persistent ID records
    property var recentApps: {
        let _trackApps = DesktopEntries.applications // Re-evaluate when apps finish parsing
        let _trigger = isVisible // Force re-evaluation on visibility change to ensure fresh .byId lookup

        let result = []
        for (let i = 0; i < recentIds.length; i++) {
            let entry = DesktopEntries.byId(recentIds[i])
            if (entry) result.push(entry)
        }
        return result
    }

    // Default view: recents prioritized, remaining apps follow alphabetically
    property var defaultList: {
        let recents = recentApps
        let others = allAppsSorted.filter(app => recentIds.indexOf(app.id) === -1)
        return recents.concat(others)
    }

    // Action handlers
    function toggle() {
        isVisible = !isVisible
        if (!isVisible) searchQuery = ""
    }

    function show() {
        isVisible = true
        searchQuery = ""
    }

    function hide() {
        isVisible = false
        searchQuery = ""
    }

    // Executes application and handles state cleanup
    function launch(appId) {
        let entry = DesktopEntries.byId(appId)
        if (entry) {
            _recordRecent(appId)
            entry.execute()
            hide()
        }
    }

    // Internal tracker management
    function clearRecents() {
        _settings.recentIdsStr = "[]" // recentIds property auto-updates via binding
    }

    function _recordRecent(id) {
        let list = recentIds.slice()
        let idx = list.indexOf(id)
        if (idx !== -1) list.splice(idx, 1)

        list.unshift(id)
        if (list.length > 5) list = list.slice(0, 5)

        _settings.recentIdsStr = JSON.stringify(list) // recentIds property auto-updates via binding
    }
}
