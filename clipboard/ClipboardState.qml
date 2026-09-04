// ClipboardState.qml
// Instructions for AI: preserve comments
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

Singleton {
    id: root

    // Cursor position, clear-confirmation banner, active tab, live search text
    property int cursorX: 0
    property int cursorY: 0
    property bool confirmClear: false
    property string currentMode: "text" // "text", "images", "emojis"
    property string searchQuery: ""

    // Only one Clipboard PanelWindow instance is ever visible at a time.
    property var activeScreen: null

    // Arrays holding all parsed data for fast model filtering
    property var allEmojis: []
    property var allClipText: []

    // Shared list models — populated once here
    property ListModel clipModel: ListModel {}
    property ListModel clipImageModel: ListModel {}
    property ListModel emojiModel: ListModel {}

    onCurrentModeChanged: {
        if (currentMode === "emojis") root.sortEmojis();
        else if (currentMode === "text") root.filterText();
    }

    onSearchQueryChanged: {
        if (currentMode === "emojis") root.sortEmojis();
        else if (currentMode === "text") root.filterText();
    }

    // Finds which physical screen currently contains the cursor
    function screenForCursor(x, y) {
        for (const s of Quickshell.screens) {
            if (x >= s.x && x < s.x + s.width && y >= s.y && y < s.y + s.height)
            return s;
        }
        return Quickshell.screens[0] ?? null;
    }

    function toggle(): void {
        if (root.activeScreen !== null) {
            root.activeScreen = null;
        } else {
            cursorProc.running = true;
        }
    }

    function show(): void {
        cursorProc.running = true;
    }

    function hide(): void {
        root.activeScreen = null;
    }

    // Resets and populates clipboard models
    function fetchClipboard(): void {
        root.allClipText = [];
        clipModel.clear();
        clipImageModel.clear();
        cliphistListProc.running = true;
        cliphistImageProc.running = true;
        if (root.allEmojis.length === 0) {
            emojiProc.running = true;
        }
    }

    // Filters text bringing search matches directly into the model
    function filterText(): void {
        clipModel.clear();
        let q = root.searchQuery.toLowerCase().trim();
        for (let i = 0; i < root.allClipText.length; i++) {
            if (q.length === 0 || root.allClipText[i].itemText.toLowerCase().includes(q)) {
                clipModel.append(root.allClipText[i]);
            }
        }
    }

    // Sorts emojis bringing search matches to the top
    function sortEmojis(): void {
        let q = root.searchQuery.toLowerCase().trim();
        let sorted = root.allEmojis.slice().sort((a, b) => {
                let aMatch = q.length !== 0 && (a.emojiName.toLowerCase().includes(q) || a.emojiChar.includes(q));
                let bMatch = q.length !== 0 && (b.emojiName.toLowerCase().includes(q) || b.emojiChar.includes(q));
                if (aMatch && !bMatch) return -1;
                if (!aMatch && bMatch) return 1;
                return 0;
        });

        emojiModel.clear();
        for (let i = 0; i < sorted.length; i++) {
            emojiModel.append(sorted[i]);
        }
    }

    // IPC handler for clipboard actions
    property IpcHandler ipc: IpcHandler {
        target: "clipboard"

        function toggle(): void { root.toggle(); }
        function open(): void { root.show(); }
        function close(): void { root.hide(); }
    }

    // Fetches cursor coordinates from Hyprland before opening
    property Process cursorProc: Process {
        command: ["hyprctl", "cursorpos"]
        stdout: SplitParser {
            onRead: data => {
                let coords = data.trim().split(",");
                if (coords.length === 2) {
                    root.cursorX = parseInt(coords[0].trim());
                    root.cursorY = parseInt(coords[1].trim());
                }
            }
        }
        onExited: {
            root.confirmClear = false;
            root.searchQuery = "";
            root.fetchClipboard();
            // Resolve the target screen once, here — the matching
            // per-screen window then just checks its own `modelData`
            // against this value; no window ever migrates screens.
            root.activeScreen = root.screenForCursor(root.cursorX, root.cursorY);
        }
    }

    // Fetches text items from cliphist
    property Process cliphistListProc: Process {
        command: ["sh", "-c", `cliphist list | head -n ${Config.clipboardMaxItems}`]
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim();
                if (!line) return;
                let tabIndex = line.indexOf("\t");
                if (tabIndex !== -1) {
                    let id = line.substring(0, tabIndex);
                    let text = line.substring(tabIndex + 1);
                    if (!text.toLowerCase().startsWith("[[ binary data")) {
                        root.allClipText.push({ itemId: id, itemText: text });
                    }
                }
            }
        }
        onExited: {
            root.filterText();
        }
    }

    // Extracts and decodes image entries
    property Process cliphistImageProc: Process {
        command: [
        "sh", "-c",
        "mkdir -p /tmp/qs_clip_img && rm -f /tmp/qs_clip_img/* && " +
        "cliphist list | grep -iE '\\[\\[ binary data' | head -n 10 | while read -r line; do " +
        "id=$(echo \"$line\" | cut -f1); " +
        "cliphist decode \"$id\" > \"/tmp/qs_clip_img/$id.png\" 2>/dev/null && " +
        "echo \"$id\t/tmp/qs_clip_img/$id.png\"; " +
        "done"
        ]
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim();
                if (!line) return;
                let parts = line.split("\t");
                if (parts.length === 2) {
                    root.clipImageModel.append({ itemId: parts[0], imagePath: parts[1] });
                }
            }
        }
    }

    // Fetches emojis from local unicode emoji-test.txt
    property Process emojiProc: Process {
        command: ["sh", "-c", "python3 -c \"import sys; [print(f'{p[0]}\\t{p[2]}') for line in open('/usr/share/unicode/emoji/emoji-test.txt', encoding='utf-8') if '; fully-qualified' in line and '#' in line for p in [line.split('#')[1].strip().split(' ', 2)] if len(p) >= 3]\""]
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim();
                if (!line) return;
                let parts = line.split("\t");
                if (parts.length === 2) {
                    root.allEmojis.push({ emojiChar: parts[0], emojiName: parts[1] });
                }
            }
        }
        onExited: {
            root.sortEmojis();
        }
    }

    // clipboard decode, copy, focus settle, and conditional paste automation
    property Process clipboardPasteProc: Process {
        property string targetId: ""
        command: [
        "sh", "-c",
        `cliphist decode "${targetId}" | wl-copy && ` +
        `sleep 0.15 && ` +
        `ACTIVE_CLASS=$(hyprctl activewindow | awk '/^\\s*class:/ {print $2}') && ` +
        `if [[ "$ACTIVE_CLASS" =~ ^(kitty|Alacritty|foot|wezterm|konsole|ghostty)$ ]]; then ` +
        `    wtype -M shift -k Insert -m shift; ` +
        `else ` +
        `    wtype -M ctrl -k v -m ctrl; ` +
        `fi`
        ]
    }

    // Direct emoji typing with focus settle delay
    property Process typeEmojiProc: Process {
        property string targetEmoji: ""
        command: [
        "sh", "-c",
        `sleep 0.15 && printf "%s" "${targetEmoji}" | wtype -`
        ]
    }

    // Wipes clipboard history and cache
    property Process wipeProc: Process {
        command: ["sh", "-c", "cliphist wipe && rm -rf /tmp/qs_clip_img"]
        onExited: {
            root.confirmClear = false;
            root.fetchClipboard();
        }
    }
}
