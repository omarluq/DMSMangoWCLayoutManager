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

    implicitWidth: root.vertical ? root.widgetThickness : pillRow.implicitWidth + root.horizontalPadding * 2
    implicitHeight: root.vertical ? pillColumn.implicitHeight + Theme.spacingL * 2 : root.widgetThickness
    width: implicitWidth
    height: implicitHeight

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
