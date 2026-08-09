import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "LayoutPreviewData.js" as LayoutPreviewData

PluginSettings {
    id: root
    pluginId: "mangoWmLayoutManager"

    StyledText {
        width: parent.width
        text: "MangoWM Layout Manager"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SelectionSetting {
        settingKey: "rightClickTarget"
        label: "Right-click toggle target"
        description: "Right-clicking the bar widget switches to this layout, or back to the previous one if it's already active. Choose None to disable."
        options: [{
                value: "",
                label: "None"
            }].concat(LayoutPreviewData.options().map(option => ({
                value: option.id,
                label: option.label
            })))
        defaultValue: "monocle"
    }

    SelectionSetting {
        settingKey: "middleClickTarget"
        label: "Middle-click toggle target"
        description: "Middle-clicking the bar widget switches to this layout, or back to the previous one if it's already active. Choose None to disable."
        options: [{
                value: "",
                label: "None"
            }].concat(LayoutPreviewData.options().map(option => ({
                value: option.id,
                label: option.label
            })))
        defaultValue: ""
    }

    ListSetting {
        id: scrollList
        settingKey: "scrollCycleLayouts"
        label: "Scroll cycle"
        description: "Layouts the scroll wheel (or two-finger swipe) cycles through on the bar widget, in this order. Use the eye to include or exclude a layout, and the arrows to reorder."
        defaultValue: LayoutPreviewData.options().map(option => ({
                id: option.id,
                label: option.label,
                enabled: true
            }))

        function moveItem(index, delta) {
            const newIndex = index + delta;
            if (newIndex < 0 || newIndex >= scrollList.items.length) {
                return;
            }
            const reordered = scrollList.items.slice();
            const moved = reordered.splice(index, 1)[0];
            reordered.splice(newIndex, 0, moved);
            scrollList.items = reordered;
        }

        function toggleItemEnabled(index) {
            const updated = scrollList.items.slice();
            updated[index] = Object.assign({}, updated[index], {
                enabled: !updated[index].enabled
            });
            scrollList.items = updated;
        }

        // ListSetting (shared DMS component, not ours) only loads its saved
        // value once, in its own Component.onCompleted - at which point
        // pluginService is still null (PluginListItem.qml assigns it to the
        // settings page instance after construction). Unlike SelectionSetting/
        // ToggleSetting/SliderSetting/etc., ListSetting exposes no loadValue()
        // function of its own, so it never took part in PluginSettings' reload
        // protocol (see PluginSettings.qml: onPluginServiceChanged and
        // reloadChildValues() both call child.loadValue() for every child that
        // has one). Adding it here opts this instance into that same protocol,
        // without touching the shared DMS component - fixes order/enabled
        // state reverting to defaultValue after a reload.
        function loadValue() {
            const settings = findSettings();
            if (settings) {
                items = settings.loadValue(settingKey, defaultValue);
            }
        }

        delegate: Component {
            StyledRect {
                id: row
                required property var modelData
                required property int index

                width: parent.width
                height: 40
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.width: 0

                // Live visual feedback for the row being dragged (see dragArea below).
                // Purely cosmetic: an additive transform that follows the raw mouse
                // delta, on top of whatever position Column/y already assigns - it
                // never touches `index`/`items`, so it can't interfere with the
                // step-based moveItem() below. z raises the dragged row above its
                // neighbors while it slides past them; the Behavior (disabled while
                // pressed, so the offset tracks the cursor 1:1 with no lag) animates
                // it back to 0 on release, in sync with the reflow Behavior on y
                // triggers below.
                property real dragOffsetY: 0
                z: dragArea.pressed ? 2 : 0
                transform: Translate {
                    y: row.dragOffsetY
                }
                Behavior on dragOffsetY {
                    enabled: !dragArea.pressed
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Easing.OutCubic
                    }
                }

                // Animates the reflow triggered by moveItem() (called from a drag step
                // below). Column still owns `y`; Behavior only smooths the transition
                // to whatever position Column assigns, it doesn't fight it.
                Behavior on y {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    DankIcon {
                        name: row.modelData.enabled ? "visibility" : "visibility_off"
                        size: Theme.iconSize - 6
                        color: row.modelData.enabled ? Theme.primary : Theme.outline
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: scrollList.toggleItemEnabled(row.index)
                        }
                    }

                    StyledText {
                        text: row.modelData.label
                        color: row.modelData.enabled ? Theme.surfaceText : Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Item {
                    id: dragHandle
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24

                    // One row "slot" (delegate height + the gap ListSetting.qml's own
                    // inner Column puts between rows, Theme.spacingS - not exposed as a
                    // property on scrollList, so mirrored here as a literal).
                    readonly property real slotHeight: row.height + Theme.spacingS

                    DankIcon {
                        name: "drag_indicator"
                        size: Theme.iconSize - 4
                        color: dragArea.pressed ? Theme.primary : Theme.outline
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        // Without this, the ancestor Flickable (the Settings
                        // page's own scroll container) steals the mouse grab
                        // as soon as it sees vertical movement past its drag
                        // threshold, so the whole page scrolls instead of
                        // this row moving. preventStealing keeps the grab
                        // here for the duration of the press.
                        preventStealing: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                        // Step-based drag, resolved once on release rather than live:
                        // scrollList.items is a plain JS array, and ListSetting's Repeater
                        // (shared DMS component) is bound to it directly - it can't diff a
                        // plain array like it would a ListModel, so every reassignment
                        // destroys and recreates ALL delegates, including this one's own
                        // MouseArea, losing the mid-drag press state. Only the net number
                        // of slots crossed is accumulated while dragging (items untouched,
                        // so this MouseArea survives the gesture); moveItem() applies the
                        // full delta once, on release. Trade-off: other rows don't reflow
                        // live while dragging, only once, on release.
                        property real pressY: 0
                        property int pressIndex: 0
                        property int pendingSteps: 0

                        onPressed: mouse => {
                            pressY = mouse.y;
                            pressIndex = row.index;
                            pendingSteps = 0;
                        }
                        onPositionChanged: mouse => {
                            if (!pressed) {
                                return;
                            }
                            const totalDelta = mouse.y - pressY;
                            pendingSteps = Math.trunc(totalDelta / dragHandle.slotHeight);
                            row.dragOffsetY = totalDelta;
                        }
                        onReleased: {
                            if (pendingSteps !== 0) {
                                scrollList.moveItem(pressIndex, pendingSteps);
                            }
                            pendingSteps = 0;
                            row.dragOffsetY = 0;
                        }
                    }
                }
            }
        }
    }

    SliderSetting {
        settingKey: "scrollCooldownMs"
        label: "Scroll speed"
        description: "Minimum time between layout changes while scrolling or swiping the bar widget. Raise this if a trackpad swipe jumps through several layouts at once; lower it for a snappier response with a mouse wheel."
        defaultValue: 500
        minimum: 200
        maximum: 1000
        unit: "ms"
        leftIcon: "speed"
    }
}
