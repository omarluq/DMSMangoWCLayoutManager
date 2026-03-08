import QtQuick
import qs.Common
import qs.Widgets
import "LayoutPreviewData.js" as LayoutPreviewData

Rectangle {
    id: root

    required property var layout
    property bool selected: false
    property bool busy: false

    signal layoutSelected(string layoutId)

    readonly property bool hovered: buttonArea.containsMouse

    implicitHeight: contentColumn.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: root.selected ? Qt.alpha(Theme.primary, 0.12) : (root.hovered ? Theme.surfaceContainer : Theme.surfaceContainerHigh)
    border.color: root.selected ? Theme.primary : Theme.outline
    border.width: root.selected ? 2 : 1

    Column {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        MangoLayoutPreview {
            width: parent.width
            selected: root.selected
            hovered: root.hovered
            previewModel: LayoutPreviewData.windowSpecs(root.layout.id)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            width: parent.width
            text: root.layout.label
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
            font.weight: root.selected ? Font.DemiBold : Font.Medium
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }

    MouseArea {
        id: buttonArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !root.busy
        onClicked: root.layoutSelected(root.layout.id)
    }
}
