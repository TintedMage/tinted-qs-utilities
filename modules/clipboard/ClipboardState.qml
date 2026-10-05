// modules/clipboard/ClipboardState.qml

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

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
    property var allClipImages: []

    // Shared list models, populated once here.
    property ListModel clipModel: ListModel {}
    property ListModel clipImageModel: ListModel {}
    property ListModel emojiModel: ListModel {}

    // Normalized once so text and emoji filtering do not repeatedly
    // trim/lowercase the same query.
    readonly property string normalizedQuery: searchQuery.trim().toLowerCase()

    onCurrentModeChanged: root.refreshActiveModel()
    onNormalizedQueryChanged: root.refreshActiveModel()

    function refreshActiveModel() {
        if (currentMode === "emojis")
        root.sortEmojis();
        else if (currentMode === "text")
        root.filterText();
    }

    // Finds which physical screen currently contains the cursor
    function screenForCursor(x, y) {
        for (const s of Quickshell.screens) {
            if (x >= s.x && x < s.x + s.width &&
                y >= s.y && y < s.y + s.height) {
                return s;
            }
        }

        return Quickshell.screens.length > 0
        ? Quickshell.screens[0]
        : null;
    }

    function toggle() {
        if (root.activeScreen !== null) {
            root.hide();
        } else {
            root.show();
        }
    }

    function show() {
        if (!cursorProc.running)
        cursorProc.running = true;
    }

    function hide() {
        root.activeScreen = null;
    }

    // Helper method to paste a clipboard item by ID
    function pasteItem(itemId) {
        if (!itemId) return;
        root.hide();
        clipboardPasteProc.targetId = itemId;
        clipboardPasteProc.updateCommand();
        clipboardPasteProc.running = true;
    }

    // Helper method to copy an item without pasting
    function copyItem(itemId) {
        if (!itemId) return;
        root.hide();
        copyOnlyProc.targetId = itemId;
        copyOnlyProc.updateCommand();
        copyOnlyProc.running = true;
    }

    // Helper method to paste an emoji
    function pasteEmoji(emojiChar) {
        if (!emojiChar) return;
        root.hide();
        typeEmojiProc.targetEmoji = emojiChar;
        typeEmojiProc.updateCommand();
        typeEmojiProc.running = true;
    }

    // Resets and populates clipboard models
    function fetchClipboard() {
        root.allClipText = [];
        root.allClipImages = [];
        clipModel.clear();
        clipImageModel.clear();

        if (cliphistListProc.running)
        cliphistListProc.running = false;

        if (cliphistImageProc.running)
        cliphistImageProc.running = false;

        cliphistListProc.running = true;
        root.refreshImages();

        if (root.allEmojis.length === 0 && !emojiProc.running)
        emojiProc.running = true;
    }

    // Filters text bringing search matches directly into the model
    function filterText() {
        clipModel.clear();

        const q = root.normalizedQuery;
        const items = root.allClipText;

        for (let i = 0, count = items.length; i < count; ++i) {
            const item = items[i];

            if (q.length === 0 || item.itemText.toLowerCase().includes(q)) {
                clipModel.append(item);
            }
        }
    }

    // Sorts emojis bringing search matches to the top
    function sortEmojis() {
        const q = root.normalizedQuery;
        const source = root.allEmojis;

        emojiModel.clear();

        if (q.length === 0) {
            for (let i = 0, count = source.length; i < count; ++i)
            emojiModel.append(source[i]);
            return;
        }

        const matches = [];
        const rest = [];

        for (let i = 0, count = source.length; i < count; ++i) {
            const item = source[i];

            const matched = item.emojiName.toLowerCase().includes(q) || item.emojiChar.includes(q);

            if (matched)
            matches.push(item);
            else
            rest.push(item);
        }

        for (let i = 0; i < matches.length; ++i)
        emojiModel.append(matches[i]);

        for (let i = 0; i < rest.length; ++i)
        emojiModel.append(rest[i]);
    }

    // IPC handler for clipboard actions
    property IpcHandler ipc: IpcHandler {
        target: "clipboard"

        function toggle() { root.toggle(); }
        function open() { root.show(); }
        function close() { root.hide(); }
    }

    // Fetches cursor coordinates from Hyprland before opening
    property Process cursorProc: Process {
        command: ["hyprctl", "cursorpos"]

        stdout: SplitParser {
            onRead: data => {
                const coords = data.trim().split(",");

                if (coords.length !== 2)
                return;

                const x = Number.parseInt(coords[0].trim(), 10);
                const y = Number.parseInt(coords[1].trim(), 10);

                if (Number.isNaN(x) || Number.isNaN(y))
                return;

                root.cursorX = x;
                root.cursorY = y;
            }
        }

        onExited: {
            root.confirmClear = false;
            root.searchQuery = "";
            root.fetchClipboard();

            root.activeScreen = root.screenForCursor(
                root.cursorX,
                root.cursorY
            );
        }
    }

    // Fetches text and image list from cliphist safely
    property Process cliphistListProc: Process {
        command: ["sh", "-c", "cliphist list"]

        stdout: SplitParser {
            onRead: data => {
                if (root.allClipText.length + root.allClipImages.length >= ClipboardSettings.maxItems)
                return;

                const line = data.trim();
                if (!line) return;

                const tabIndex = line.indexOf("\t");
                if (tabIndex === -1) return;

                const id = line.substring(0, tabIndex).trim();
                const text = line.substring(tabIndex + 1);

                if (!id || !/^\d+$/.test(id)) return;

                const lowerText = text.toLowerCase();

                if (lowerText.startsWith("[[ binary data") || lowerText.includes("binary data")) {
                    root.allClipImages.push({
                            itemId: id
                    });
                    return;
                }

                root.allClipText.push({
                        itemId: id,
                        itemText: text
                });
            }
        }

        onExited: root.filterText()
    }

    // Builds the image model from its own fresh `cliphist list`, newest first.
    // It no longer depends on the text list's parse/exit timing, so the
    // most recent entry cannot be missed.
    function refreshImages() {
        if (cliphistImageProc.running)
        cliphistImageProc.running = false;

        clipImageModel.clear();

        cliphistImageProc.command = [
        "sh",
        "-c",
        `
        set -u
        cache="${ClipboardSettings.imageCacheDir}"
        mkdir -p "$cache"

        cliphist list \
        | grep -E '^[0-9]+[[:space:]]+\\[\\[ binary data' \
        | head -n ${ClipboardSettings.maxImageItems} \
        | cut -f1 \
        | while IFS= read -r id; do
        [ -n "$id" ] || continue

        existing=$(find "$cache" -maxdepth 1 -name "$id.*" ! -name '.*' 2>/dev/null | head -n 1)
        if [ -n "$existing" ] && [ -s "$existing" ]; then
        printf '%s\\t%s\\n' "$id" "$existing"
        continue
        fi

        temp="$cache/.$id.$$.tmp"
        if cliphist decode "$id" > "$temp" 2>/dev/null && [ -s "$temp" ]; then
        mime=$(file -b --mime-type "$temp" 2>/dev/null || echo "image/png")
        case "$mime" in
        image/jpeg) ext="jpg" ;;
        image/png)  ext="png" ;;
        image/webp) ext="webp" ;;
        image/gif)  ext="gif" ;;
        image/bmp)  ext="bmp" ;;
        *)          ext="png" ;;
        esac

        output="$cache/$id.$ext"
        mv -f "$temp" "$output"
        printf '%s\\t%s\\n' "$id" "$output"
        else
        rm -f "$temp"
        fi
        done

        find "$cache" -maxdepth 1 -name '.*.tmp' -mtime +1 -delete 2>/dev/null || true
        `
        ];

        cliphistImageProc.running = true;
    }

    property Process cliphistImageProc: Process {
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line) return;

                const tabIndex = line.indexOf("\t");
                if (tabIndex === -1) return;

                const itemId = line.substring(0, tabIndex).trim();
                const imagePath = line.substring(tabIndex + 1).trim();

                if (!itemId || !imagePath) return;

                const fileUrl = imagePath.startsWith("file://") ? imagePath : "file://" + imagePath;

                for (let i = 0; i < root.clipImageModel.count; ++i) {
                    if (root.clipImageModel.get(i).itemId === itemId) return;
                }

                root.clipImageModel.append({
                        itemId: itemId,
                        imagePath: fileUrl
                });
            }
        }
    }

    // Fetches emojis from local unicode emoji-test.txt
    property Process emojiProc: Process {
        command: [
        "sh",
        "-c",
        "python3 -c \"import sys; [print(f'{p[0]}\\t{p[2]}') for line in open('/usr/share/unicode/emoji/emoji-test.txt', encoding='utf-8') if '; fully-qualified' in line and '#' in line for p in [line.split('#')[1].strip().split(' ', 2)] if len(p) >= 3]\""
        ]

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line) return;

                const tabIndex = line.indexOf("\t");
                if (tabIndex === -1) return;

                root.allEmojis.push({
                        emojiChar: line.substring(0, tabIndex),
                        emojiName: line.substring(tabIndex + 1)
                });
            }
        }

        onExited: {
            root.sortEmojis();
        }
    }

    // Dynamic decode, copy, focus settle, and conditional paste process
    property Process clipboardPasteProc: Process {
        property string targetId: ""

        onTargetIdChanged: updateCommand()

        function updateCommand() {
            if (!targetId) return;
            command = [
            "sh",
            "-c",
            `cliphist decode "${targetId}" | wl-copy && ` +
            `cliphist decode "${targetId}" | wl-copy --primary && ` +
            `sleep ${ClipboardSettings.pasteDelay} && ` +
            `ACTIVE_CLASS=$(hyprctl activewindow -j | jq -r '.class // empty' 2>/dev/null || hyprctl activewindow | awk '/^\\s*class:/ {print $2}') && ` +
            `if [[ "$ACTIVE_CLASS" =~ ^(kitty|Alacritty|foot|wezterm|konsole|ghostty|st|rxvt|terminal)$ ]]; then ` +
            `    wtype -M ctrl -M shift -k v -m shift -m ctrl; ` +
            `else ` +
            `    wtype -M ctrl -k v -m ctrl; ` +
            `fi`
            ];
        }
    }

    // Copy item to clipboard only without auto-pasting
    property Process copyOnlyProc: Process {
        property string targetId: ""

        onTargetIdChanged: updateCommand()

        function updateCommand() {
            if (!targetId) return;
            command = [
            "sh",
            "-c",
            `cliphist decode "${targetId}" | wl-copy && ` +
            `cliphist decode "${targetId}" | wl-copy --primary`
            ];
        }
    }

    // Direct emoji typing with focus settle delay
    property Process typeEmojiProc: Process {
        property string targetEmoji: ""

        onTargetEmojiChanged: updateCommand()

        function updateCommand() {
            if (!targetEmoji) return;
            const safeEmoji = targetEmoji.replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
            command = [
            "sh",
            "-c",
            `sleep ${ClipboardSettings.emojiDelay} && printf "%s" "${safeEmoji}" | wtype -`
            ];
        }
    }

    // Wipes clipboard history and cache
    property Process wipeProc: Process {
        command: [
        "sh",
        "-c",
        `cliphist wipe && rm -rf "${ClipboardSettings.imageCacheDir}"`
        ]

        onExited: {
            root.allClipText = [];
            root.allClipImages = [];
            clipModel.clear();
            clipImageModel.clear();
            root.confirmClear = false;
            root.fetchClipboard();
        }
    }
}
