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

    // Shared layout dimensions

    // Current size (resizable, persisted)
    property real launcherWidth: AppLauncherSettings._settings.savedW > 0 ? AppLauncherSettings._settings.savedW : AppLauncherSettings.width
    property real launcherHeight: AppLauncherSettings._settings.savedH > 0 ? AppLauncherSettings._settings.savedH : AppLauncherSettings.height
    property bool resizing: false
    readonly property real cornerRadius: AppLauncherSettings.radius + 10

    // Floating position (top-left of the launcher, in screen coordinates).
    // -1 means "not placed yet": the UI centers the launcher on screen.
    property real posX: AppLauncherSettings._settings.posX
    property real posY: AppLauncherSettings._settings.posY
    property bool dragging: false

    function setPosition(x, y) {
        posX = x
        posY = y
    }

    // Persist the current position (called when a drag ends)
    function savePosition() {
        AppLauncherSettings._settings.posX = posX
        AppLauncherSettings._settings.posY = posY
    }

    function setGeometry(x, y, w, h) {
        posX = x
        posY = y
        launcherWidth = w
        launcherHeight = h
    }

    // Persist position and size (called when a drag/resize ends)
    function saveGeometry() {
        savePosition()
        AppLauncherSettings._settings.savedW = launcherWidth
        AppLauncherSettings._settings.savedH = launcherHeight
    }

    // Back to centered, default size
    function resetPosition() {
        launcherWidth = AppLauncherSettings.width
        launcherHeight = AppLauncherSettings.height
        setPosition(-1, -1)
        saveGeometry()
    }

    // Visibility as a number (no animation, flips instantly)

    readonly property real reveal: isVisible ? 1 : 0

    // Persistent launcher configuration

    readonly property var recentIds: AppLauncherSettings.recentIds

    // Derived properties consumed by UI

    readonly property string normalizedQuery: searchQuery.trim().toLowerCase()
    readonly property bool isSearching: normalizedQuery !== ""
    readonly property var currentModel: isSearching ? searchResults : defaultList

    // Unfiltered raw applications list, bound directly to values for updates
    property var allApps: {
        let vals = DesktopEntries.applications.values
        let arr = []

        for (let i = 0; i < vals.length; i++) {
            let entry = vals[i]
            if (entry && entry.id) {
                arr.push(entry)
            }
        }

        return arr
    }

    // Baseline alphabetical application list
    property var allAppsSorted: allApps.slice().sort((a, b) => {
            if (!a || !a.name) return -1
            if (!b || !b.name) return 1
            return a.name.localeCompare(b.name)
    })

    // List generated against active user query
    property var searchResults: {
        const q = normalizedQuery

        if (q === "")
        return []

        return allApps.filter(e => {
                if (!e || !e.name)
                return false

                if (e.name.toLowerCase().indexOf(q) !== -1)
                return true

                if (e.genericName && e.genericName.toLowerCase().indexOf(q) !== -1)
                return true

                if (e.keywords) {
                    for (let i = 0; i < e.keywords.length; i++) {
                        if (e.keywords[i] && e.keywords[i].toLowerCase().indexOf(q) !== -1)
                        return true
                    }
                }

                return false
        }).sort((a, b) => {
                if (!a || !a.name) return -1
                if (!b || !b.name) return 1
                return a.name.localeCompare(b.name)
        })
    }

    // Resolves entry models based on persistent ID records
    property var recentApps: {
        let _track = allApps
        let _trigger = isVisible
        let result = []

        for (let i = 0; i < recentIds.length; i++) {
            let entry = DesktopEntries.byId(recentIds[i])
            if (entry && entry.id)
            result.push(entry)
        }

        return result
    }

    // Default view: recents first, remaining apps alphabetically
    property var defaultList: {
        let recents = recentApps
        let others = allAppsSorted.filter(
            app => app && app.id && recentIds.indexOf(app.id) === -1
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
