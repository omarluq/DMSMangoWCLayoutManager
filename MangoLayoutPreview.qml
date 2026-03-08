import QtQuick
import qs.Common

Rectangle {
    id: root

    property bool selected: false
    property bool hovered: false
    property var previewModel: []

    implicitHeight: 92
    radius: Theme.cornerRadius - 2
    color: root.selected ? Qt.alpha(Theme.surface, 0.94) : Qt.alpha(Theme.surface, 0.76)
    border.color: root.selected ? Qt.alpha(Theme.primary, 0.6) : Qt.alpha(Theme.outline, 0.75)
    border.width: 1
    clip: true

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: Math.max(4, root.radius - 3)
        color: root.selected ? Qt.alpha(Theme.surfaceContainer, 0.9) : Qt.alpha(Theme.surfaceContainerHigh, 0.86)
        border.color: Qt.alpha(Theme.outline, 0.38)
        border.width: 1
        clip: true

        Item {
            id: viewport
            anchors.fill: parent
            anchors.margins: 9

            Repeater {
                model: root.previewModel

                delegate: Rectangle {
                    required property var modelData

                    x: viewport.width * modelData.x
                    y: viewport.height * modelData.y
                    width: viewport.width * modelData.w
                    height: viewport.height * modelData.h
                    radius: 6
                    z: modelData.z || 0
                    opacity: modelData.opacity === undefined ? 1 : modelData.opacity
                    color: modelData.accent
                        ? Qt.alpha(Theme.primary, root.selected ? 0.78 : 0.34)
                        : Qt.alpha(Theme.surfaceText, root.hovered ? 0.18 : 0.12)
                    border.color: modelData.accent
                        ? Qt.alpha(Theme.primary, root.selected ? 0.95 : 0.55)
                        : Qt.alpha(Theme.outline, 0.55)
                    border.width: 1
                }
            }
        }
    }
}
