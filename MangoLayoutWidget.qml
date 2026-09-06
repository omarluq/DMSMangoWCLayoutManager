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
    // Layout active immediately before the current one, updated on every
    // real transition regardless of source (click, scroll, right-click
    // toggle, or an external tag change picked up via `mmsg watch`).
    // Used by the right-click toggle to switch back.
    property string previousLayoutRaw: ""
    property string lastError: ""
    property string queryBuffer: ""
    property string pendingLayoutId: ""
    // Monitor name a get-monitor query was launched against, captured at
    // start so a late result for a monitor we've since moved away from can
    // be discarded instead of overwriting the new monitor's layout.
    property string queryMonitor: ""
    // Set while intentionally tearing down the watcher for a monitor change
    // (or removal), so the exit is treated as expected (no error) and, once
    // the old process has actually exited, a fresh watcher is started for
    // the current monitor if there is one.
    property bool watchRestartPending: false
    property bool mangoAvailable: false
    // Fallback target for the right-click toggle when there is no
    // previousLayoutRaw yet (e.g. right after launch).
    readonly property string rightClickFallbackId: "monocle"
    // Timestamp (ms) of the last scroll-triggered layout switch, used to
    // throttle bursts of wheel events from trackpad kinetic scrolling.
    property real lastScrollCycleTime: 0

    readonly property string currentLayoutCode: formatLayoutCode(currentLayoutRaw)
    readonly property string currentLayoutIcon: formatLayoutIcon(currentLayoutRaw)
    readonly property bool busy: queryProcess.running || setProcess.running
    property var layoutOptions: root.visibleLayoutOptions()
    readonly property string monitorName: root.parentScreen && root.parentScreen.name
        ? String(root.parentScreen.name)
        : ""

    popoutWidth: 560
    popoutHeight: 460

    // Right-click and middle-click each toggle between their own
    // independently configurable target layout and whatever was active
    // before; scroll cycles through the configured layout list. All three
    // read their config fresh from pluginService on every use, so edits
    // made in the Settings page apply immediately.
    pillRightClickAction: function () {
        root.toggleRightClickLayout();
    }

    Component.onCompleted: {
        startWatch();
    }

    // mmsg has no monitor-agnostic query; every get/watch/dispatch is
    // addressed to a specific output name, so moving the widget to another
    // screen (or losing its screen) must resubscribe the watcher.
    onMonitorNameChanged: {
        if (watchProcess.running) {
            // Tear the stale watcher down first; the restart (if any) is
            // deferred to watchProcess.onExited once the old process has
            // actually exited, so we never leave a watcher subscribed to
            // the old monitor and never race a half-dead process.
            root.watchRestartPending = true;
            watchProcess.running = false;
        } else {
            startWatch();
        }
    }

    // Starts the watcher for the current monitor. No-op when there is no
    // monitor (empty name stops watching) or one is already running.
    function startWatch() {
        if (!root.monitorName || watchProcess.running) {
            return;
        }
        refreshCurrentLayout();
        // Capture the monitor now; its dependent command binding may still be stale.
        watchProcess.command = [root.mmsgCommand, "watch", "monitor", root.monitorName];
        watchProcess.running = true;
        startupPollTimer.restart();
    }

    // Defensive retry for a race at launch between the compositor/mmsg
    // socket becoming ready and our first query: retries a few times,
    // a short interval apart, until a layout is known.
    Timer {
        id: startupPollTimer
        interval: 400
        repeat: true
        property int attempts: 0

        onTriggered: {
            attempts += 1;
            if (root.mangoAvailable || attempts >= 5) {
                stop();
                attempts = 0;
                return;
            }
            root.refreshCurrentLayout();
        }
    }

    function normalizeLayoutValue(value) {
        const raw = String(value === undefined || value === null ? "" : value).trim();
        return raw.replace(/^"+|"+$/g, "");
    }

    // `mmsg get monitor <name>` / `mmsg watch monitor <name>` each emit one
    // JSON object per line (watch pushes the initial state immediately,
    // then one line per change). The monitor's active layout is exposed as
    // the short "layout_symbol" code (e.g. "T", "VK", "DW").
    function extractLayoutSymbol(output) {
        const raw = String(output === undefined || output === null ? "" : output).trim();
        if (!raw) {
            return "";
        }

        const lines = raw.split(/\r?\n/).map(line => line.trim()).filter(line => line.length > 0);
        if (lines.length === 0) {
            return "";
        }

        try {
            const data = JSON.parse(lines[lines.length - 1]);
            return data && data.layout_symbol ? String(data.layout_symbol) : "";
        } catch (e) {
            return "";
        }
    }

    function applyLayoutUpdate(output) {
        const symbol = extractLayoutSymbol(output);
        if (!symbol) {
            return;
        }

        recordLayoutTransition(symbol);
        mangoAvailable = true;
        lastError = "";
    }

    // Single place that updates currentLayoutRaw, used both for changes
    // detected externally (watch/query) and for changes we trigger
    // ourselves (setLayout). Keeps previousLayoutRaw consistent
    // regardless of what caused the transition.
    function recordLayoutTransition(symbol) {
        // Compare logical layout identity, not the raw string: currentLayoutRaw
        // sometimes holds the mmsg code ("M") and sometimes a layout id
        // ("monocle") depending on the source, and both can refer to the
        // same layout via LayoutPreviewData's aliases.
        const incomingOption = lookupLayout(symbol);
        const currentOption = lookupLayout(currentLayoutRaw);
        const incomingId = incomingOption ? incomingOption.id : normalizeLayoutValue(symbol);
        const currentId = currentOption ? currentOption.id : normalizeLayoutValue(currentLayoutRaw);

        if (incomingId && incomingId !== currentId && currentLayoutRaw) {
            previousLayoutRaw = currentLayoutRaw;
        }
        currentLayoutRaw = symbol;
    }

    function loadPluginValue(key, defaultValue) {
        if (root.pluginService && root.pluginService.loadPluginData) {
            return root.pluginService.loadPluginData(root.pluginId, key, defaultValue);
        }
        return defaultValue;
    }

    // Shared by the right-click and middle-click toggles: reads `settingKey`
    // fresh from pluginService on every use (so Settings-page edits apply
    // immediately), then either switches to targetId or, if that's already
    // the active layout, back to whatever was active before it (falling
    // back to fallbackId when there's no previousLayoutRaw yet).
    function toggleConfiguredLayout(settingKey, fallbackId) {
        const targetId = normalizeLayoutValue(loadPluginValue(settingKey, fallbackId));
        if (!targetId) {
            return;
        }

        if (isCurrentLayout(targetId)) {
            const previousOption = root.previousLayoutRaw ? lookupLayout(root.previousLayoutRaw) : null;
            const returnId = previousOption ? previousOption.id : (targetId !== fallbackId ? fallbackId : "");
            if (returnId) {
                setLayout(returnId);
            }
            return;
        }

        setLayout(targetId);
    }

    // Right-click must work even before the Settings page has ever been
    // opened and saved a value, hence the rightClickFallbackId default.
    function toggleRightClickLayout() {
        root.toggleConfiguredLayout("rightClickTarget", root.rightClickFallbackId);
    }

    // Middle-click has no fallback: it's a second, independent target the
    // user opts into from Settings, "None" (disabled) until then.
    function toggleMiddleClickLayout() {
        root.toggleConfiguredLayout("middleClickTarget", "");
    }

    // Ordered, visibility-filtered layout list — single source of truth for
    // both the popout grid (layoutOptions) and the scroll cycle, driven by
    // the Settings page's "Scroll cycle" list. Falls back to every known
    // layout, in the popout's natural order, when nothing has been
    // configured yet. Deliberately NOT applied to the right-click target
    // dropdown, which lists every layout regardless of visibility here —
    // that lets a layout be reachable only via right-click, hidden from
    // the grid and the scroll cycle.
    function visibleLayoutOptions() {
        const stored = loadPluginValue("scrollCycleLayouts", null);
        if (Array.isArray(stored) && stored.length > 0) {
            return stored
                .filter(entry => entry && entry.id && entry.enabled !== false)
                .map(entry => LayoutPreviewData.findOption(entry.id))
                .filter(option => option);
        }
        return LayoutPreviewData.options();
    }

    function cycleLayout(direction) {
        // Ordered list of layout ids to cycle through with the scroll wheel.
        const ids = root.visibleLayoutOptions().map(option => option.id);
        if (ids.length === 0) {
            return;
        }

        const currentOption = lookupLayout(root.currentLayoutRaw);
        const currentId = currentOption ? currentOption.id : "";
        const index = ids.indexOf(currentId);
        // When the current layout is not in the cycle list (index === -1),
        // forward should land on the first entry and backward on the last,
        // rather than modulo arithmetic off the -1 sentinel.
        let nextIndex;
        if (index === -1) {
            nextIndex = direction >= 0 ? 0 : ids.length - 1;
        } else {
            nextIndex = ((index + direction) % ids.length + ids.length) % ids.length;
        }
        root.setLayout(ids[nextIndex]);
    }

    // Throttles scroll-triggered layout switches: trackpad kinetic scroll
    // fires many wheel events per physical swipe, each of which would
    // otherwise cycle one more layout. scrollCooldownMs (Settings page,
    // default matches SliderSetting's defaultValue: 500) sets the minimum
    // gap between two accepted switches.
    function handleScrollCycle(direction) {
        const cooldown = loadPluginValue("scrollCooldownMs", 500);
        const now = Date.now();
        if (now - root.lastScrollCycleTime < cooldown) {
            return;
        }
        root.lastScrollCycleTime = now;
        root.cycleLayout(direction);
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

        if (!root.monitorName) {
            return;
        }

        queryBuffer = "";
        queryMonitor = root.monitorName;
        queryProcess.command = [root.mmsgCommand, "get", "monitor", root.queryMonitor];
        queryProcess.running = true;
    }

    function setLayout(layoutId) {
        if (setProcess.running) {
            return;
        }

        pendingLayoutId = layoutId;
        lastError = "";
        setProcess.command = [mmsgCommand, "dispatch", "setlayout," + layoutId];
        setProcess.running = true;
    }

    Process {
        id: queryProcess
        command: [root.mmsgCommand, "get", "monitor", root.monitorName]
        running: false

        stdout: SplitParser {
            onRead: data => {
                root.queryBuffer += (root.queryBuffer ? "\n" : "") + data;
            }
        }

        onExited: exitCode => {
            // Discard a result for a monitor we've since left so it can't
            // clobber the current monitor's layout state.
            if (root.queryMonitor !== root.monitorName) {
                return;
            }
            if (exitCode === 0) {
                root.applyLayoutUpdate(root.queryBuffer);
            } else {
                root.mangoAvailable = false;
                root.lastError = "Failed to query MangoWM with mmsg get monitor.";
            }
        }
    }

    Process {
        id: watchProcess
        command: [root.mmsgCommand, "watch", "monitor", root.monitorName]
        running: false

        stdout: SplitParser {
            onRead: data => {
                if (!root.watchRestartPending) {
                    root.applyLayoutUpdate(data);
                }
            }
        }

        onExited: exitCode => {
            if (root.watchRestartPending) {
                // Expected exit from an intentional stop (monitor change or
                // removal); not an error. Start a fresh watcher for the
                // current monitor, or stay stopped if it's now empty.
                root.watchRestartPending = false;
                root.startWatch();
                return;
            }
            if (exitCode !== 0) {
                root.lastError = "Failed to watch MangoWM layout changes with mmsg watch monitor.";
                root.mangoAvailable = false;
            }
        }
    }

    Process {
        id: setProcess
        command: [root.mmsgCommand, "dispatch", ""]
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                root.mangoAvailable = true;
                root.lastError = "";
                root.recordLayoutTransition(root.pendingLayoutId);
                root.closePopout();
                Qt.callLater(root.refreshCurrentLayout);
            } else {
                root.lastError = "Failed to switch layout with mmsg dispatch setlayout,<layout>.";
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
            onScrollRequested: direction => root.handleScrollCycle(direction)
            onMiddleClickRequested: root.toggleMiddleClickLayout()
        }
    }

    verticalBarPill: Component {
        MangoLayoutPill {
            vertical: true
            available: root.mangoAvailable
            code: root.currentLayoutCode
            iconName: root.currentLayoutIcon
            widgetThickness: root.widgetThickness
            onScrollRequested: direction => root.handleScrollCycle(direction)
            onMiddleClickRequested: root.toggleMiddleClickLayout()
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: chooser
            headerText: ""
            detailsText: ""
            showCloseButton: true

            // Force a fresh query every time the popout is actually shown,
            // not just at plugin startup: `opened` fires on every open
            // (verified in DankPopoutStandalone.qml), unlike Component.onCompleted
            // which only fires once since this content stays alive across toggles.
            Connections {
                target: chooser.parentPopout
                function onOpened() {
                    root.refreshCurrentLayout();
                    root.layoutOptions = root.visibleLayoutOptions();
                }
            }

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
                            text: "MangoWM Layout Manager"
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
                    // Size to the actual grid content so the popout (which auto-grows to
                    // its content's implicitHeight, see PluginPopout.qml) shows every
                    // layout tile without clipping; cap at 75% of screen height as a
                    // safety net for short displays.
                    height: Math.min(buttonGrid.implicitHeight + Theme.spacingM * 2, root.parentScreen ? root.parentScreen.height * 0.75 : 700)
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
