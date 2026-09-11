pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME")
        || (homeDir + "/.cache")
    readonly property string colorsPath: cacheHome + "/wal/colors.json"

    property var palette: ({})

    function colorAt(section: string, key: string, fallback: string): string {
        const group = root.palette && root.palette[section];
        const value = group && group[key];
        return typeof value === "string" && /^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(value)
            ? value
            : fallback;
    }

    function reloadPalette(): void {
        try {
            const parsed = JSON.parse(colorsFile.text());
            root.palette = parsed && typeof parsed === "object" ? parsed : ({});
        } catch (error) {
            root.palette = ({});
        }
    }

    FileView {
        id: colorsFile

        path: root.colorsPath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: colorsFile.reload()
        onLoaded: root.reloadPalette()
        onLoadFailed: root.palette = ({})
    }

    Component.onCompleted: root.reloadPalette()

    readonly property color background: root.colorAt("special", "background", "#11101c")
    readonly property color foreground: root.colorAt("special", "foreground", "#f3efff")
    // Terminal color8 can be almost black; derive readable secondary text from
    // the theme foreground instead of assuming that ANSI gray has contrast.
    readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.72)
    readonly property color accent: root.colorAt("colors", "color5", "#b497d6")
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.28)
    readonly property color card: Qt.rgba(background.r, background.g, background.b, 0.94)
    readonly property color cardLow: Qt.rgba(background.r, background.g, background.b, 0.86)
    readonly property color border: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.22)
    readonly property color critical: "#ff718c"
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.34)
    readonly property string fontFamily: "DejaVu Sans"
}
