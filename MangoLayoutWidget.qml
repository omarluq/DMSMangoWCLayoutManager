import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "LayoutPreviewData.js" as LayoutPreviewData

PluginComponent {
    id: root

    property string mmsgCommand: "mmsg"
    readonly property real pillHorizontalPadding: Theme.spacingXS
    property string currentLayoutRaw: ""
    property string lastError: ""
    property string queryBuffer: ""
    property string pendingLayoutId: ""
    property bool mangoAvailable: false

    readonly property string currentLayoutCode: formatLayoutCode(currentLayoutRaw)
    readonly property string currentLayoutIcon: formatLayoutIcon(currentLayoutRaw)
    readonly property bool busy: queryProcess.running || setProcess.running
    readonly property var layoutOptions: LayoutPreviewData.options()

    popoutWidth: 560
    popoutHeight: 460

    Component.onCompleted: {
        refreshCurrentLayout();
        watchProcess.running = true;
    }

    function normalizeLayoutValue(value) {
        const raw = String(value === undefined || value === null ? "" : value).trim();
        const unquoted = raw.replace(/^"+|"+$/g, "");
        if (!unquoted) {
            return "";
        }

        const layoutMatch = unquoted.match(/\blayout\s+([A-Za-z_]+)\s*$/i);
        if (layoutMatch) {
            return layoutMatch[1].trim();
        }

        if (unquoted.indexOf(":") !== -1) {
            const parts = unquoted.split(":");
            return parts[parts.length - 1].trim();
        }

        return unquoted;
    }

    function extractLayoutFromQueryOutput(output) {
        const raw = String(output === undefined || output === null ? "" : output).trim();
        if (!raw) {
            return "";
        }

        const lines = raw.split(/\r?\n/).map(line => line.trim()).filter(line => line.length > 0);
        if (lines.length === 0) {
            return "";
        }

        const screenName = root.parentScreen && root.parentScreen.name
            ? String(root.parentScreen.name).trim().toLowerCase()
            : "";
        let fallbackLayout = "";

        for (let i = 0; i < lines.length; i += 1) {
            const match = lines[i].match(/^(\S+)\s+layout\s+([A-Za-z_]+)\s*$/i);
            if (!match) {
                continue;
            }

            const lineScreen = String(match[1] || "").trim().toLowerCase();
            const lineLayout = String(match[2] || "").trim();

            if (!fallbackLayout) {
                fallbackLayout = lineLayout;
            }

            if (screenName && lineScreen === screenName) {
                return lineLayout;
            }
        }

        if (fallbackLayout) {
            return fallbackLayout;
        }

        if (lines.length === 1) {
            const normalized = normalizeLayoutValue(lines[0]);
            if (normalized && normalized !== lines[0]) {
                return normalized;
            }

            if (/^[A-Za-z_]+$/.test(lines[0])) {
                return lines[0];
            }
        }

        return "";
    }

    function applyLayoutUpdate(output) {
        const parsed = extractLayoutFromQueryOutput(output);
        if (!parsed) {
            return;
        }

        currentLayoutRaw = parsed;
        mangoAvailable = true;
        lastError = "";
    }

    function lookupLayout(value) {
        const normalized = normalizeLayoutValue(value);
        if (!normalized) {
            return null;
        }

        return LayoutPreviewData.findOption(normalized);
    }

    function formatLayoutCode(value) {
        const option = lookupLayout(value);
        if (option) {
            return option.code;
        }

        const normalized = normalizeLayoutValue(value);
        if (!normalized) {
            return "?";
        }

        return normalized.length > 3 ? normalized.slice(0, 3).toUpperCase() : normalized.toUpperCase();
    }

    function formatLayoutIcon(value) {
        const option = lookupLayout(value);
        return option && option.icon ? option.icon : "grid_view";
    }

    function isCurrentLayout(layoutId) {
        const option = lookupLayout(currentLayoutRaw);
        return option ? option.id === layoutId : normalizeLayoutValue(currentLayoutRaw) === layoutId;
    }

    function refreshCurrentLayout() {
        if (queryProcess.running) {
            return;
        }

        queryBuffer = "";
        queryProcess.running = true;
    }

    function setLayout(layoutId) {
        if (setProcess.running) {
            return;
        }

        pendingLayoutId = layoutId;
        lastError = "";
        setProcess.command = [mmsgCommand, "-d", "setlayout," + layoutId];
        setProcess.running = true;
    }

    Process {
        id: queryProcess
        command: [root.mmsgCommand, "-g", "-l"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                root.queryBuffer += (root.queryBuffer ? "\n" : "") + data;
            }
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                root.applyLayoutUpdate(root.queryBuffer);
            } else {
                root.mangoAvailable = false;
                root.lastError = "Failed to query MangoWC with mmsg -g -l.";
            }
        }
    }

    Process {
        id: watchProcess
        command: [root.mmsgCommand, "-w", "-t", "-l"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                root.applyLayoutUpdate(data);
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.lastError = "Failed to watch MangoWC layout changes with mmsg -w -t -l.";
                root.mangoAvailable = false;
            }
        }
    }

    Process {
        id: setProcess
        command: [root.mmsgCommand, "-d", ""]
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                root.mangoAvailable = true;
                root.lastError = "";
                root.currentLayoutRaw = root.pendingLayoutId;
                root.closePopout();
                Qt.callLater(root.refreshCurrentLayout);
            } else {
                root.lastError = "Failed to switch layout with mmsg -d setlayout,<layout>.";
            }

            root.pendingLayoutId = "";
        }
    }

    horizontalBarPill: Component {
        MangoLayoutPill {
            available: root.mangoAvailable
            code: root.currentLayoutCode
            iconName: root.currentLayoutIcon
            widgetThickness: root.widgetThickness
            horizontalPadding: root.pillHorizontalPadding
        }
    }

    verticalBarPill: Component {
        MangoLayoutPill {
            vertical: true
            available: root.mangoAvailable
            code: root.currentLayoutCode
            iconName: root.currentLayoutIcon
            widgetThickness: root.widgetThickness
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: chooser
            headerText: ""
            detailsText: ""
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingM

                Item {
                    width: parent.width
                    implicitHeight: titleRow.implicitHeight

                    Row {
                        id: titleRow
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: root.currentLayoutIcon
                            size: Theme.iconSize - 2
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "MangoWC Layout Manager"
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Rectangle {
                    visible: root.lastError !== ""
                    width: parent.width
                    implicitHeight: visible ? statusColumn.implicitHeight + Theme.spacingM * 2 : 0
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    border.color: Theme.outline
                    border.width: 1

                    Column {
                        id: statusColumn
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingXS

                        StyledText {
                            width: parent.width
                            text: root.lastError
                            color: Theme.error
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                DankFlickable {
                    width: parent.width
                    height: Math.max(160, root.popoutHeight - chooser.headerHeight - chooser.detailsHeight - titleRow.implicitHeight - (root.lastError !== "" ? 132 : 72))
                    clip: true
                    contentWidth: width
                    contentHeight: buttonGrid.implicitHeight + Theme.spacingM * 2

                    Grid {
                        id: buttonGrid
                        x: Theme.spacingM
                        y: Theme.spacingM
                        width: parent.width - Theme.spacingM * 2 - 12
                        columns: 3
                        spacing: Theme.spacingS

                        Repeater {
                            model: root.layoutOptions

                            delegate: MangoLayoutTile {
                                required property var modelData
                                width: (buttonGrid.width - buttonGrid.spacing * (buttonGrid.columns - 1)) / buttonGrid.columns
                                layout: modelData
                                selected: root.isCurrentLayout(modelData.id)
                                busy: root.busy
                                onLayoutSelected: layoutId => root.setLayout(layoutId)
                            }
                        }
                    }
                }
            }
        }
    }
}
