import QtQuick
import QtQuick.Layouts
import PICODE

Rectangle {
    id: navRoot

    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: Qt.lighter(Theme.bgSecondary, 1.05) }
        GradientStop { position: 1.0; color: Theme.bgSecondary }
    }

    // Top separator + 1px inner highlight
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        color: Theme.border
    }
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1 }
        height: 1
        color: Theme.borderSoft
    }

    signal tabClicked(string pageKey)
    property string currentPage: "dash"

    property var tabs: [
        { label: "DASH",    key: "dash" },
        { label: "DRONE",   key: "drone" },
        { label: "CAMERA",  key: "camera" },
        { label: "MAP",     key: "map" },
        { label: "MISSION", key: "mission" },
        { label: "PARAMS",  key: "params" },
        { label: "PAYLOAD", key: "payload" },
        { label: "PERIPH",  key: "periph" },
        { label: "COMMS",   key: "comms" },
        { label: "CASE",    key: "case" }
    ]

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: navRoot.tabs

            Item {
                id: tabItem
                Layout.fillHeight: true
                Layout.fillWidth: true
                clip: true

                property bool isActive: modelData.key === currentPage

                // Press-scale feedback host
                Item {
                    id: pressHost
                    anchors.fill: parent
                    transformOrigin: Item.Center
                    scale: hoverArea.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutQuad } }

                    // Active background tint
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop {
                                position: 0.0
                                color: tabItem.isActive ? Theme.accentYellowFaint : "transparent"
                            }
                            GradientStop {
                                position: 1.0
                                color: tabItem.isActive
                                       ? Qt.rgba(0.89, 0.82, 0.29, 0.18)
                                       : (hoverArea.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
                                Behavior on color { ColorAnimation { duration: Theme.motionMedium } }
                            }
                        }
                    }

                    // Top accent edge — only when active (visual anchor at top)
                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 1
                        color: Theme.accentYellow
                        opacity: tabItem.isActive ? 0.85 : 0.0
                        Behavior on opacity { NumberAnimation { duration: Theme.motionMedium } }
                    }

                    // Left divider (between tabs)
                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 }
                        width: 1
                        color: Theme.border
                        opacity: 0.6
                        visible: index > 0
                    }

                    // Active accent bar with glow halo (bottom edge)
                    Rectangle {
                        id: glowHalo
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: 14
                        opacity: tabItem.isActive ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: Theme.motionMedium } }
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Theme.accentYellowGlow }
                        }
                    }
                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: 3
                        color: Theme.accentYellow
                        opacity: tabItem.isActive ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: Theme.motionMedium } }
                    }

                    // Ripple
                    Item {
                        id: rippleHost
                        anchors.fill: parent
                        clip: true

                        Rectangle {
                            id: ripple
                            property real targetSize: Math.max(parent.width, parent.height) * 2.4
                            width: 0; height: 0
                            radius: width / 2
                            color: Qt.rgba(0.89, 0.82, 0.29, 0.22)
                            opacity: 0
                            x: 0; y: 0

                            function trigger(px, py) {
                                x = px; y = py
                                width = 0; height = 0
                                opacity = 0.55
                                rippleAnim.restart()
                            }
                        }
                        ParallelAnimation {
                            id: rippleAnim
                            NumberAnimation { target: ripple; property: "width"; to: ripple.targetSize; duration: 380; easing.type: Easing.OutQuad }
                            NumberAnimation { target: ripple; property: "height"; to: ripple.targetSize; duration: 380; easing.type: Easing.OutQuad }
                            NumberAnimation { target: ripple; property: "x"; to: rippleHost.width / 2 - ripple.targetSize / 2; duration: 380; easing.type: Easing.OutQuad }
                            NumberAnimation { target: ripple; property: "y"; to: rippleHost.height / 2 - ripple.targetSize / 2; duration: 380; easing.type: Easing.OutQuad }
                            NumberAnimation { target: ripple; property: "opacity"; to: 0; duration: 380; easing.type: Easing.OutQuad }
                        }
                    }

                    // Icon + label
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        NavIcon {
                            name: modelData.key
                            color: tabItem.isActive ? Theme.accentYellow : Theme.textDisabled
                            strokeWidth: tabItem.isActive ? 2.0 : 1.6
                            width: 22; height: 22
                            Layout.alignment: Qt.AlignHCenter
                            scale: tabItem.isActive ? 1.0 : 0.9
                            // Overshoot on activation — feels mechanical, not bouncy
                            Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                        }
                        Text {
                            text: modelData.label
                            color: tabItem.isActive ? Theme.accentYellow : Theme.textSecondary
                            font.pixelSize: 10
                            font.weight: tabItem.isActive ? Font.Bold : Font.Medium
                            font.letterSpacing: 0.7
                            Layout.alignment: Qt.AlignHCenter
                            Behavior on color { ColorAnimation { duration: Theme.motionMedium } }
                        }
                    }
                }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onPressed: (mouse) => ripple.trigger(mouse.x - 1, mouse.y - 1)
                    onClicked: tabClicked(modelData.key)
                }
            }
        }
    }
}
