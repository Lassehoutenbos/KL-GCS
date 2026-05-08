import QtQuick
import PICODE

// Reusable section header: vertical accent rail + label.
// Replaces inline gradient-bar + text pattern repeated across pages.
Item {
    id: root
    implicitHeight: compact ? Theme.sectionHeaderHSm : Theme.sectionHeaderH

    property string text: ""
    property string accent: "yellow"   // "yellow" | "blue" | "crit"
    property bool   compact: false
    property bool   alert: false        // pulse the rail when true (for warnings)
    property int    fontSize: compact ? Theme.fontMicro : Theme.fontPageTitle

    readonly property color accentColor: {
        if (alert) return Theme.statusCrit
        switch (accent) {
            case "blue": return Theme.accentBlue
            case "crit": return Theme.statusCrit
            default:     return Theme.accentYellow
        }
    }
    readonly property color accentSoft: {
        if (alert) return Qt.rgba(1, 0.36, 0.36, 0.4)
        switch (accent) {
            case "blue": return Qt.rgba(0.50, 0.84, 1.0, 0.4)
            case "crit": return Qt.rgba(1, 0.36, 0.36, 0.4)
            default:     return Qt.rgba(0.89, 0.82, 0.29, 0.4)
        }
    }

    // Accent rail (3px) with soft fade at top/bottom
    Rectangle {
        id: rail
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 3
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: root.accentSoft }
            GradientStop { position: 0.5; color: root.accentColor }
            GradientStop { position: 1.0; color: root.accentSoft }
        }

        SequentialAnimation on opacity {
            running: root.alert
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.45; duration: 700; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.45; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
        }
    }

    // Subtle glow halo behind the rail
    Rectangle {
        anchors { left: rail.right; top: parent.top; bottom: parent.bottom }
        width: 18
        opacity: 0.5
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Text {
        anchors { left: parent.left; leftMargin: 11; verticalCenter: parent.verticalCenter }
        text: root.text
        color: root.alert ? Theme.statusWarn : Theme.textSecondary
        font.pixelSize: root.fontSize
        font.weight: Font.SemiBold
        font.letterSpacing: 0.8
    }

    // Optional right-side content (status indicator, count, etc.)
    default property alias rightContent: rightSlot.children
    Item {
        id: rightSlot
        anchors { right: parent.right; rightMargin: 10; top: parent.top; bottom: parent.bottom }
        width: childrenRect.width
    }

    // Hairline under the header
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.border
    }
}
