import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property bool vertical: false
    property bool available: false
    property string code: "?"
    property string iconName: "grid_view"
    property real widgetThickness: 0
    property real horizontalPadding: Theme.spacingXS

    // direction: +1 = next layout, -1 = previous layout.
    signal scrollRequested(int direction)
    signal middleClickRequested()

    implicitWidth: root.vertical ? root.widgetThickness : pillRow.implicitWidth + root.horizontalPadding * 2
    implicitHeight: root.vertical ? pillColumn.implicitHeight + Theme.spacingL * 2 : root.widgetThickness
    width: implicitWidth
    height: implicitHeight

    // WORKAROUND for missing native middle-click support in the DMS plugin
    // framework: PluginComponent exposes pillRightClickAction but no
    // pillMiddleClickAction equivalent, and BasePill's own MouseArea only
    // accepts Left/Right (see BasePill.qml, acceptedButtons). So we
    // intercept the middle button ourselves, one layer up. Left/right
    // press/click events still fall through untouched to BasePill's
    // MouseArea underneath (only MiddleButton is accepted here). Wheel
    // events aren't gated by acceptedButtons, so they're unaffected too.
    //
    // If DMS ever adds a native pillMiddleClickAction (mirroring
    // pillRightClickAction): delete this MouseArea and the
    // middleClickRequested signal, and wire
    // `pillMiddleClickAction: function () { root.toggleRightClickLayout(); }`
    // directly in MangoLayoutWidget.qml instead — toggleRightClickLayout()
    // itself doesn't change, it doesn't know or care how it gets invoked.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onPressed: root.middleClickRequested()
        onWheel: function (wheelEvent) {
            const delta = wheelEvent.angleDelta.y !== 0 ? wheelEvent.angleDelta.y : wheelEvent.angleDelta.x;
            if (delta === 0) {
                return;
            }
            wheelEvent.accepted = true;
            root.scrollRequested(delta > 0 ? 1 : -1);
        }
    }

    Row {
        id: pillRow
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DankIcon {
            name: root.iconName
            size: Theme.iconSize - 6
            color: root.available ? Theme.primary : Theme.surfaceVariantText
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: root.code
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Column {
        id: pillColumn
        visible: root.vertical
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DankIcon {
            name: root.iconName
            size: Theme.iconSize - 6
            color: root.available ? Theme.primary : Theme.surfaceVariantText
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: root.code
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
