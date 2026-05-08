import QtQuick
import QtQuick.Shapes
import PICODE

// Vector line-icon set tuned for the 9 nav tabs.
// Drawn on a 24×24 viewBox; uses Item.transform Scale to fit width/height.
Item {
    id: root
    property string name: "dash"
    property color  color: Theme.textDisabled
    property real   strokeWidth: 1.8

    width: 22
    height: 22

    Item {
        id: vb
        width: 24
        height: 24
        anchors.centerIn: parent
        transform: Scale {
            origin.x: 12; origin.y: 12
            xScale: root.width / 24
            yScale: root.height / 24
        }

        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.color
                fillColor: "transparent"
                strokeWidth: root.strokeWidth * 24 / Math.max(root.width, root.height)
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: {
                        switch (root.name) {
                        case "dash":
                            return "M3 3 H10 V10 H3 Z M14 3 H21 V10 H14 Z "
                                 + "M3 14 H10 V21 H3 Z M14 14 H21 V21 H14 Z"

                        case "drone":
                            return "M5 5 m-2.5 0 a2.5 2.5 0 1 0 5 0 a2.5 2.5 0 1 0 -5 0 "
                                 + "M19 5 m-2.5 0 a2.5 2.5 0 1 0 5 0 a2.5 2.5 0 1 0 -5 0 "
                                 + "M5 19 m-2.5 0 a2.5 2.5 0 1 0 5 0 a2.5 2.5 0 1 0 -5 0 "
                                 + "M19 19 m-2.5 0 a2.5 2.5 0 1 0 5 0 a2.5 2.5 0 1 0 -5 0 "
                                 + "M6.8 6.8 L17.2 17.2 M17.2 6.8 L6.8 17.2 "
                                 + "M12 10 L12 14 M10 12 L14 12"

                        case "camera":
                            return "M3 7 H8 L9.5 5 H14.5 L16 7 H21 V19 H3 Z "
                                 + "M12 13 m-3.5 0 a3.5 3.5 0 1 0 7 0 a3.5 3.5 0 1 0 -7 0"

                        case "map":
                            return "M3 6 L9 4 L15 6 L21 4 V18 L15 20 L9 18 L3 20 Z "
                                 + "M9 4 V18 M15 6 V20"

                        case "mission":
                            return "M5 4 V21 M5 4 H17 L14 8 L17 12 H5"

                        case "params":
                            return "M4 7 H20 M4 12 H20 M4 17 H20 "
                                 + "M9 7 m-1.6 0 a1.6 1.6 0 1 0 3.2 0 a1.6 1.6 0 1 0 -3.2 0 "
                                 + "M15 12 m-1.6 0 a1.6 1.6 0 1 0 3.2 0 a1.6 1.6 0 1 0 -3.2 0 "
                                 + "M8 17 m-1.6 0 a1.6 1.6 0 1 0 3.2 0 a1.6 1.6 0 1 0 -3.2 0"

                        case "payload":
                            return "M4 8 L12 4 L20 8 V17 L12 21 L4 17 Z "
                                 + "M4 8 L12 12 L20 8 M12 12 V21 "
                                 + "M9 14 L12 17 L15 14"

                        case "periph":
                            return "M5 6 m-2 0 a2 2 0 1 0 4 0 a2 2 0 1 0 -4 0 "
                                 + "M19 12 m-2 0 a2 2 0 1 0 4 0 a2 2 0 1 0 -4 0 "
                                 + "M5 18 m-2 0 a2 2 0 1 0 4 0 a2 2 0 1 0 -4 0 "
                                 + "M7 6 L17 11 M7 18 L17 13"

                        case "case":
                            return "M3 8 H21 V19 H3 Z M3 12 H21 "
                                 + "M9 8 V5 H15 V8"

                        default: return ""
                        }
                    }
                }
            }
        }
    }

    Behavior on color { ColorAnimation { duration: Theme.motionMedium } }
}
