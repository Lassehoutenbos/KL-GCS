import QtQuick
import PICODE

// Reusable elevated surface with bevel highlight + border + soft inner glow.
// Use as a drop-in for the inline gradient/border pattern repeated everywhere.
Rectangle {
    id: root

    property bool flat: false       // no gradient, just flat bgSecondary
    property bool inset: false      // recessed (sunken) variant

    border.color: Theme.border
    border.width: 1
    radius: Theme.radiusCard
    color: flat ? Theme.bgSecondary : "transparent"

    gradient: flat ? null : (inset ? insetGrad : raisedGrad)

    Gradient {
        id: raisedGrad
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: Theme.panelTop }
        GradientStop { position: 1.0; color: Theme.panelBottom }
    }
    Gradient {
        id: insetGrad
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: Theme.bgSunken }
        GradientStop { position: 1.0; color: Theme.bgSecondary }
    }

    // 1px top inner highlight for the bevel
    Rectangle {
        visible: !root.inset
        anchors {
            top: parent.top; left: parent.left; right: parent.right
            topMargin: 1; leftMargin: 1; rightMargin: 1
        }
        height: 1
        color: Theme.borderSoft
        radius: 1
    }

    default property alias content: contentArea.data
    Item {
        id: contentArea
        anchors.fill: parent
    }
}
