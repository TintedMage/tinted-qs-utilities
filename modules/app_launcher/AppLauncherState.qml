// modules/app_launcher/AppLauncherState.qml

pragma Singleton
import QtQuick
import QtQml
import Quickshell
import qs.core.config

Singleton {
    id: root

    // Runtime state

    property bool isVisible: false
    property string searchQuery: ""

    // Shared with the main bar shader so the launcher is drawn
    // as part of the bottom border. The panel draws the SHAPE, the launcher
    // window draws the CONTENT; both read the same values below so they can
    // never get out of step.

    readonly property real launcherWidth: AppLauncherSettings.width
    readonly property real launcherHeight: AppLauncherSettings.height
    readonly property real cornerRadius: AppLauncherSettings.radius + 10

    // 0 = hidden, 1 = fully open. The single slide animation lives here.
    property real reveal: isVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
    }

    // Persistent launcher data/configuration is owned by AppLauncherSettings.
    readonly property var recentIds: AppLauncherSettings.recentIds

    // Derived properties consumed by UI

    readonly property string normalizedQuery: searchQuery.trim().toLowerCase()
    readonly property bool isSearching: normalizedQuery !== ""
    readonly property var currentModel: isSearching ? searchResults : defaultList

    // Unfiltered raw applications data.
    property var allApps: {
        // Track applications object to force re-evaluation when Quickshell
        // finishes asynchronous parsing.
        let _track = DesktopEntries.applications
        let arr = []
        let vals = DesktopEntries.applications.values

        for (let i = 0; i < vals.length; i++) {
            arr.push(vals[i])
        }

        return arr
    }

    // Baseline alphabetical application list.
    property var allAppsSorted: allApps.slice().sort(
        (a, b) => a.name.localeCompare(b.name)
    )

    // List generated against active user query.
    property var searchResults: {
        const q = normalizedQuery

        if (q === "")
        return []

        return allApps.filter(e => {
                if (e.name.toLowerCase().indexOf(q) !== -1)
                return true

                if (e.genericName && e.genericName.toLowerCase().indexOf(q) !== -1)
                return true

                if (e.keywords) {
                    for (let i = 0; i < e.keywords.length; i++) {
                        if (e.keywords[i].toLowerCase().indexOf(q) !== -1)
                        return true
                    }
                }

                return false
        }).sort((a, b) => a.name.localeCompare(b.name))
    }

    // Resolves entry models based on persistent ID records.
    property var recentApps: {
        let _trackApps = DesktopEntries.applications
        let _trigger = isVisible

        let result = []

        for (let i = 0; i < recentIds.length; i++) {
            let entry = DesktopEntries.byId(recentIds[i])
            if (entry)
            result.push(entry)
        }

        return result
    }

    // Default view: recents first, remaining apps alphabetically.
    property var defaultList: {
        let recents = recentApps
        let others = allAppsSorted.filter(
            app => recentIds.indexOf(app.id) === -1
        )

        return recents.concat(others)
    }

    // Actions

    function toggle() {
        isVisible = !isVisible

        if (!isVisible)
        searchQuery = ""
    }

    function show() {
        isVisible = true
        searchQuery = ""
    }

    function hide() {
        isVisible = false
        searchQuery = ""
    }

    function launch(appId) {
        const entry = DesktopEntries.byId(appId)

        if (!entry)
        return

        _recordRecent(appId)
        entry.execute()
        hide()
    }

    function clearRecents() {
        AppLauncherSettings._settings.recentIdsStr = "[]"
    }

    function _recordRecent(id) {
        const list = recentIds.slice()
        const index = list.indexOf(id)

        if (index !== -1)
        list.splice(index, 1)

        list.unshift(id)

        if (list.length > AppLauncherSettings.maxRecentApps)
        list.length = AppLauncherSettings.maxRecentApps

        AppLauncherSettings._settings.recentIdsStr = JSON.stringify(list)
    }
}
