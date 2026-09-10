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

    // Shared list models — populated once here
    property ListModel clipModel: ListModel {}
    property ListModel clipImageModel: ListModel {}
    property ListModel emojiModel: ListModel {}

    // Normalized once so text and emoji filtering do not repeatedly
    // trim/lowercase the same query.
    readonly property string normalizedQuery: searchQuery.trim().toLowerCase()

    onCurrentModeChanged: root.refreshActiveModel()
    onNormalizedQueryChanged: root.refreshActiveModel()

    function refreshActiveModel(): void {
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

    function toggle(): void {
        if (root.activeScreen !== null) {
            root.hide();
        } else {
            root.show();
        }
    }

    function show(): void {
        if (!cursorProc.running)
        cursorProc.running = true;
    }

    function hide(): void {
        root.activeScreen = null;
    }

    // Resets and populates clipboard models
    function fetchClipboard(): void {
        root.allClipText = [];
        root.allClipImages = [];
        clipModel.clear();
        clipImageModel.clear();

        if (cliphistListProc.running)
        cliphistListProc.running = false;

        if (cliphistImageProc.running)
        cliphistImageProc.running = false;

        cliphistListProc.running = true;

        if (root.allEmojis.length === 0 && !emojiProc.running)
        emojiProc.running = true;
    }

    // Filters text bringing search matches directly into the model
    function filterText(): void {
        clipModel.clear();

        const q = root.normalizedQuery;
        const items = root.allClipText;

        for (let i = 0, count = items.length; i < count; ++i) {
            const item = items[i];

            if (q.length === 0 ||
                item.itemText.toLowerCase().includes(q)) {
                clipModel.append(item);
            }
        }
    }

    // Sorts emojis bringing search matches to the top
    function sortEmojis(): void {
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

            const matched =
            item.emojiName.toLowerCase().includes(q) ||
            item.emojiChar.includes(q);

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

        function toggle(): void { root.toggle(); }
        function open(): void { root.show(); }
        function close(): void { root.hide(); }
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

            // Resolve the target screen once, here — the matching
            // per-screen window then just checks its own `modelData`
            // against this value; no window ever migrates screens.
            root.activeScreen = root.screenForCursor(
                root.cursorX,
                root.cursorY
            );
        }
    }

    // Fetches text items from cliphist
    //
    // Text and image entries are intentionally collected from the same
    // cliphist snapshot. This avoids running `cliphist list` twice and,
    // more importantly, prevents the text/image views from observing
    // different history snapshots.
    property Process cliphistListProc: Process {
        command: [
        "sh",
        "-c",
        `cliphist list | head -n ${ClipboardConfig.maxItems}`
        ]

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();

                if (!line)
                return;

                const tabIndex = line.indexOf("\t");

                if (tabIndex === -1)
                return;

                const id = line.substring(0, tabIndex);
                const text = line.substring(tabIndex + 1);

                const lowerText = text.toLowerCase();

                if (lowerText.startsWith("[[ binary data")) {
                    const formatMatch = lowerText.match(
                        /\b(jpeg|jpg|png|webp|bmp|gif|tiff)\b/
                    );

                    root.allClipImages.push({
                            itemId: id,
                            extension: formatMatch ? formatMatch[1] : "img"
                    });

                    return;
                }

                root.allClipText.push({
                        itemId: id,
                        itemText: text
                });
            }
        }

        onExited: {
            root.filterText();
            root.refreshImages();
        }
    }

    // Extracts and decodes image entries
    //
    // The image IDs come from the same `cliphist list` snapshot as the
    // text entries. This avoids a second history query racing the first
    // query and guarantees both views represent the same clipboard state.
    function refreshImages(): void {
        const images = root.allClipImages
        .slice(0, ClipboardConfig.maxImageItems)
        .filter(image => /^[0-9]+$/.test(image.itemId));

        if (images.length === 0)
        return;

        const entries = images
        .map(image => `${image.itemId}\t${image.extension}`)
        .join("\n");

        cliphistImageProc.command = [
        "sh",
        "-c",
        `
        set -u

        cache="${ClipboardConfig.imageCacheDir}"
        mkdir -p "$cache"

        valid="$cache/.active.$$"
        : > "$valid"

        while IFS="$(printf '\\t')" read -r id ext; do
        [ -n "$id" ] || continue

        output="$cache/$id.$ext"
        printf '%s\\n' "$output" >> "$valid"

        if [ ! -s "$output" ]; then
        temp="$cache/.$id.$$.tmp"

        if cliphist decode "$id" > "$temp" 2>/dev/null &&
        [ -s "$temp" ]; then
        mv -f "$temp" "$output"
        else
        rm -f "$temp"
        continue
        fi
        fi

        printf '%s\\t%s\\n' "$id" "$output"
        done <<'EOF'
        ${entries}
        EOF

        find "$cache" -maxdepth 1 -type f ! -name '.active.*' ! -name '.*.tmp' -print |
        while IFS= read -r file; do
        grep -Fqx "$file" "$valid" || rm -f "$file"
        done

        rm -f "$valid"
        `
        ];

        cliphistImageProc.running = true;
    }

    property Process cliphistImageProc: Process {
        command: ["sh", "-c", root.imageDecodeCommand]

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();

                if (!line)
                return;

                const tabIndex = line.indexOf("\t");

                if (tabIndex === -1)
                return;

                const itemId = line.substring(0, tabIndex);
                const imagePath = line.substring(tabIndex + 1);

                if (!itemId || !imagePath)
                return;

                root.clipImageModel.append({
                        itemId: itemId,
                        imagePath: imagePath
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

                if (!line)
                return;

                const tabIndex = line.indexOf("\t");

                if (tabIndex === -1)
                return;

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

    // clipboard decode, copy, focus settle, and conditional paste automation
    property Process clipboardPasteProc: Process {
        property string targetId: ""

        command: [
        "sh",
        "-c",
        `cliphist decode "${targetId}" | wl-copy && ` +
        `sleep ${ClipboardConfig.pasteDelay} && ` +
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
        "sh",
        "-c",
        `sleep ${ClipboardConfig.emojiDelay} && printf "%s" "${targetEmoji}" | wtype -`
        ]
    }

    // Wipes clipboard history and cache
    property Process wipeProc: Process {
        command: [
        "sh",
        "-c",
        `cliphist wipe && rm -rf "${ClipboardConfig.imageCacheDir}"`
        ]

        onExited: {
            root.confirmClear = false;
            root.fetchClipboard();
        }
    }
}
