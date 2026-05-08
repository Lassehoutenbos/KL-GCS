import QtQuick
import PICODE

Item {
    id: root
    width: 156
    height: 100

    property string label: "LABEL"
    property string value: "0.0"
    property string unit:  "unit"

    // Layered drop shadow (cheap, no shader, reliable on Pi)
    Rectangle {
        anchors.fill: card
        anchors.topMargin: 4
        anchors.leftMargin: 1
        anchors.rightMargin: -1
        radius: card.radius
        color: Qt.rgba(0, 0, 0, 0.35)
        z: -1
    }
    Rectangle {
        anchors.fill: card
        anchors.topMargin: 2
        radius: card.radius
        color: Qt.rgba(0, 0, 0, 0.22)
        z: -1
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.radiusCard
        border.color: Theme.border
        border.width: 1
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.lighter(Theme.bgSecondary, 1.10) }
            GradientStop { position: 1.0; color: Theme.bgSecondary }
        }

        // Inner top highlight — subtle bevel
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right
                      topMargin: 1; leftMargin: 1; rightMargin: 1 }
            height: 1
            color: Theme.borderSoft
            radius: 1
        }

        // Top accent bar with horizontal fade
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 2
            radius: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0.50, 0.84, 1.0, 0.10) }
                GradientStop { position: 0.5; color: Qt.rgba(0.50, 0.84, 1.0, 0.85) }
                GradientStop { position: 1.0; color: Qt.rgba(0.50, 0.84, 1.0, 0.10) }
            }
        }

        // Top-left corner bracket
        Rectangle { anchors.top: parent.top; anchors.left: parent.left; width: 10; height: 1.5; color: Theme.accentBlue; opacity: 0.5 }
        Rectangle { anchors.top: parent.top; anchors.left: parent.left; width: 1.5; height: 10; color: Theme.accentBlue; opacity: 0.5 }

        // Bottom-right corner bracket
        Rectangle { anchors.bottom: parent.bottom; anchors.right: parent.right; width: 10; height: 1.5; color: Theme.accentBlue; opacity: 0.3 }
        Rectangle { anchors.bottom: parent.bottom; anchors.right: parent.right; width: 1.5; height: 10; color: Theme.accentBlue; opacity: 0.3 }

        // Label — top-left
        Text {
            anchors { top: parent.top; left: parent.left; topMargin: 8; leftMargin: 10 }
            text: root.label
            color: Theme.textSecondary
            font.pixelSize: Theme.fontUnit
            font.weight: Font.Medium
            font.letterSpacing: 0.5
        }

        // Value — centered
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 3
            text: root.value
            color: Theme.textPrimary
            font.pixelSize: Theme.fontValueLarge
            font.weight: Font.Bold
            font.family: Theme.fontMono
        }

        // Unit — bottom-right
        Text {
            anchors { bottom: parent.bottom; right: parent.right; bottomMargin: 8; rightMargin: 10 }
            text: root.unit
            color: Theme.textDisabled
            font.pixelSize: Theme.fontUnit
            font.letterSpacing: 0.3
        }
    }
}
