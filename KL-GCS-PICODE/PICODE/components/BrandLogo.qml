import QtQuick
import QtQuick.Shapes
import PICODE

// Reusable KL-Systems brand mark.
// variant:    "mark" | "main" | "both"
// alertTint:  fade silver → red (peripheral-vision warning signal)
// searching:  rotate a sweeping yellow arc around the mark (link-acquiring state)
// glowOpacity: optional yellow halo strength (0..1)
Item {
    id: root
    property string variant: "mark"
    property real   glowOpacity: 0.0
    property bool   alertTint: false
    property bool   searching: false

    implicitWidth:  variant === "mark" ? 28 : 96
    implicitHeight: variant === "mark" ? 28 : 28

    // Soft accent halo
    Rectangle {
        anchors.centerIn: img
        width: img.paintedWidth + 18
        height: img.paintedHeight + 18
        radius: width / 2
        color: Theme.accentYellowGlow
        opacity: root.glowOpacity
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.motionMedium } }
    }

    Image {
        id: img
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        source: {
            switch (root.variant) {
                case "main": return "qrc:/qt/qml/PICODE/assets/logos/Main.png"
                case "both": return "qrc:/qt/qml/PICODE/assets/logos/Both.png"
                default:     return "qrc:/qt/qml/PICODE/assets/logos/Favicon.png"
            }
        }

        // Red wash for alert state — multiplied over the silver mark
        Rectangle {
            anchors.fill: parent
            color: Theme.statusCrit
            opacity: root.alertTint ? 0.35 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.motionMedium } }
        }
    }

    // Sweeping radar arc for "searching / no link"
    Item {
        id: sweepHost
        anchors.centerIn: img
        width: img.paintedWidth + 12
        height: img.paintedHeight + 12
        visible: root.searching
        opacity: root.searching ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motionMedium } }

        rotation: 0
        RotationAnimator on rotation {
            running: root.searching
            from: 0; to: 360
            duration: 1600
            loops: Animation.Infinite
        }

        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.accentYellow
                fillColor: "transparent"
                strokeWidth: 1.5
                capStyle: ShapePath.RoundCap
                startX: sweepHost.width / 2 + sweepHost.width * 0.45
                startY: sweepHost.height / 2

                PathArc {
                    x: sweepHost.width / 2
                    y: sweepHost.height / 2 - sweepHost.height * 0.45
                    radiusX: sweepHost.width * 0.45
                    radiusY: sweepHost.height * 0.45
                    direction: PathArc.Counterclockwise
                }
            }
        }
    }
}
