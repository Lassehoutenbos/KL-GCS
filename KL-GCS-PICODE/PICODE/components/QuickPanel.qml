import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PICODE

Item {
    id: panel
    property string quickLayoutMode: "PILOT"
    signal brandLogoRequested()

    function toggle() {
        if (visible) {
            hideAnim.start()
        } else {
            visible = true
            showAnim.start()
        }
    }

    // Brightness ratios for proportional master-slider scaling
    property var brightnessRatios: [1.0, 1.0, 1.0, 1.0, 1.0]

    NumberAnimation {
        id: showAnim
        target: panelRect
        property: "y"
        to: 0
        duration: 150
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: hideAnim
        target: panelRect
        property: "y"
        to: -panelRect.height
        duration: 150
        easing.type: Easing.OutCubic
        onStopped: panel.visible = false
    }

    // Scrim (click to dismiss)
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)

        MouseArea {
            anchors.fill: parent
            onClicked: panel.toggle()
        }
    }

    // ── Reusable mini-slider style ────────────────────────────────────────
    component MiniSlider : Slider {
        id: ms
        from: 0; to: 100; stepSize: 1
        property color trackColor: Theme.accentBlue

        background: Item {
            x: ms.leftPadding
            y: ms.topPadding + ms.availableHeight / 2 - height / 2
            implicitWidth: 200; implicitHeight: 6
            width: ms.availableWidth; height: 6

            Rectangle {
                width: parent.width; height: parent.height; radius: 3
                color: Theme.bgSunken
                border.color: Theme.border; border.width: 1
            }
            Rectangle {
                width: ms.visualPosition * parent.width
                height: parent.height; radius: 3
                color: ms.trackColor; opacity: 0.85
            }
        }
        handle: Rectangle {
            x: ms.leftPadding + ms.visualPosition * (ms.availableWidth - width)
            y: ms.topPadding + ms.availableHeight / 2 - height / 2
            width: 16; height: 16; radius: 8
            color: Theme.textPrimary
            border.color: ms.trackColor; border.width: 2
            scale: ms.pressed ? 0.86 : 1.0
            Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
        }
    }

    // Slide-down panel
    Rectangle {
        id: panelRect
        width: parent.width
        height: 504
        y: -height
        color: Theme.bgSecondary
        border.color: Theme.border
        border.width: 1

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.panelTop }
            GradientStop { position: 1.0; color: Theme.panelBottom }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // ── HEADER ──────────────────────────────────────────────────
            RowLayout {
                spacing: 10
                Layout.fillWidth: true
                Layout.preferredHeight: 36

                BrandLogo {
                    variant: "mark"
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                }

                Text {
                    text: "QUICK PANEL"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontPageTitle
                    font.weight: Font.SemiBold
                    font.letterSpacing: 0.8
                    Layout.fillWidth: true
                }

                Text {
                    text: "KL-SYSTEMS"
                    color: Theme.textDisabled
                    font.pixelSize: Theme.fontMicro
                    font.weight: Font.Medium
                    font.letterSpacing: 1.2
                    font.family: Theme.fontMono
                }

                // Show brand-logo splash
                Rectangle {
                    id: showLogoBtn
                    Layout.preferredWidth: 88
                    Layout.preferredHeight: 36
                    radius: Theme.radiusButton
                    color: pressArea.pressed ? Theme.accentYellowSoft : Theme.bgSecondary
                    border.color: pressArea.pressed ? Theme.accentYellow : Theme.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        BrandLogo {
                            variant: "mark"
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                        }
                        Text {
                            text: "LOGO"
                            color: pressArea.pressed ? Theme.accentYellow : Theme.textSecondary
                            font.pixelSize: Theme.fontMicro
                            font.family: Theme.fontMono
                            font.weight: Font.SemiBold
                            font.letterSpacing: 1.6
                        }
                    }

                    MouseArea {
                        id: pressArea
                        anchors.fill: parent
                        onClicked: panel.brandLogoRequested()
                    }
                }

                BigButton {
                    label: "✕"
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    onClicked: panel.toggle()
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

            // ════════════════════ LIGHTING CARD ════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 168
                radius: Theme.radiusCard
                color: Theme.bgElevated
                border.color: Theme.border
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "LIGHTING"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSectionLabel
                            font.weight: Font.SemiBold
                            font.letterSpacing: 0.6
                            Layout.fillWidth: true
                        }
                        // Live preview swatch
                        Rectangle {
                            width: 18; height: 18; radius: 9
                            color: GCSState.worklightOn
                                   ? GCSState.worklightColor
                                   : Qt.rgba(GCSState.worklightColor.r, GCSState.worklightColor.g, GCSState.worklightColor.b, 0.25)
                            border.color: Theme.border; border.width: 1
                        }
                    }

                    // Two big toggles
                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.radiusButton
                            color: GCSState.worklightOn ? Theme.accentYellowSoft : Theme.bgSecondary
                            border.color: GCSState.worklightOn ? Theme.accentYellow : Theme.border
                            border.width: GCSState.worklightOn ? 2 : 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14; anchors.rightMargin: 14
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4
                                    color: GCSState.worklightOn ? Theme.accentYellow : Theme.textDisabled
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    Text {
                                        text: "WORKLIGHT"
                                        color: GCSState.worklightOn ? Theme.accentYellow : Theme.textSecondary
                                        font.pixelSize: 11
                                        font.weight: Font.SemiBold
                                        font.letterSpacing: 0.6
                                    }
                                    Text {
                                        text: GCSState.worklightOn ? "ACTIVE" : "OFF"
                                        color: Theme.textDisabled
                                        font.pixelSize: 9
                                        font.family: Theme.fontMono
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: GCSState.worklightOn = !GCSState.worklightOn
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.radiusButton
                            color: GCSState.alsAutoEnabled ? Theme.accentBlueSoft : Theme.bgSecondary
                            border.color: GCSState.alsAutoEnabled ? Theme.accentBlue : Theme.border
                            border.width: GCSState.alsAutoEnabled ? 2 : 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14; anchors.rightMargin: 14
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4
                                    color: GCSState.alsAutoEnabled ? Theme.accentBlue : Theme.textDisabled
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    Text {
                                        text: "AMBIENT"
                                        color: GCSState.alsAutoEnabled ? Theme.accentBlue : Theme.textSecondary
                                        font.pixelSize: 11
                                        font.weight: Font.SemiBold
                                        font.letterSpacing: 0.6
                                    }
                                    Text {
                                        text: GCSState.alsAutoEnabled ? "AUTO" : "MANUAL"
                                        color: Theme.textDisabled
                                        font.pixelSize: 9
                                        font.family: Theme.fontMono
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: GCSState.alsAutoEnabled = !GCSState.alsAutoEnabled
                            }
                        }
                    }

                    // ── HUE SLIDER ─────────────────────────────────────
                    Item {
                        id: colorRow
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56

                        // Helpers
                        property bool isWhite: Math.abs(GCSState.worklightColor.r - 1) < 0.02
                                               && Math.abs(GCSState.worklightColor.g - 1) < 0.02
                                               && Math.abs(GCSState.worklightColor.b - 1) < 0.02
                        property bool isWarm:  Math.abs(GCSState.worklightColor.r - 1) < 0.02
                                               && Math.abs(GCSState.worklightColor.g - 200/255) < 0.03
                                               && Math.abs(GCSState.worklightColor.b - 120/255) < 0.03

                        RowLayout {
                            anchors.fill: parent
                            spacing: 8

                            Text {
                                text: "COLOR"
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSectionLabel
                                font.weight: Font.Medium
                                Layout.preferredWidth: 56
                            }

                            // Rainbow hue slider
                            Slider {
                                id: hueSlider
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                from: 0; to: 1; stepSize: 0.001
                                value: GCSState.worklightColor.hsvSaturation > 0.1
                                       ? GCSState.worklightColor.hsvHue
                                       : 0

                                background: Item {
                                    x: hueSlider.leftPadding
                                    y: hueSlider.topPadding + hueSlider.availableHeight / 2 - height / 2
                                    width: hueSlider.availableWidth
                                    height: 14

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 7
                                        border.color: Theme.border
                                        border.width: 1
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.000; color: "#ff0000" }
                                            GradientStop { position: 0.166; color: "#ffff00" }
                                            GradientStop { position: 0.333; color: "#00ff00" }
                                            GradientStop { position: 0.500; color: "#00ffff" }
                                            GradientStop { position: 0.666; color: "#0066ff" }
                                            GradientStop { position: 0.833; color: "#ff00ff" }
                                            GradientStop { position: 1.000; color: "#ff0000" }
                                        }
                                    }
                                }

                                handle: Rectangle {
                                    x: hueSlider.leftPadding + hueSlider.visualPosition * (hueSlider.availableWidth - width)
                                    y: hueSlider.topPadding + hueSlider.availableHeight / 2 - height / 2
                                    width: 22; height: 22; radius: 11
                                    color: Qt.hsva(hueSlider.value, 1, 1, 1)
                                    border.color: Theme.textPrimary
                                    border.width: 2
                                    scale: hueSlider.pressed ? 0.88 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 6; height: 6; radius: 3
                                        color: Theme.bgPrimary; opacity: 0.5
                                    }
                                }

                                onMoved: GCSState.worklightColor = Qt.hsva(value, 1, 1, 1)
                            }

                            // White / Warm chips
                            Rectangle {
                                Layout.preferredWidth: 44
                                Layout.fillHeight: true
                                radius: Theme.radiusButton
                                color: colorRow.isWhite ? Qt.rgba(1,1,1,0.18) : Theme.bgSecondary
                                border.color: colorRow.isWhite ? "#ffffff" : Theme.border
                                border.width: colorRow.isWhite ? 2 : 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "W"
                                    color: colorRow.isWhite ? "#ffffff" : Theme.textSecondary
                                    font.pixelSize: 12; font.weight: Font.Bold
                                    font.family: Theme.fontMono
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: GCSState.worklightColor = Qt.rgba(1, 1, 1, 1)
                                }
                            }
                            Rectangle {
                                Layout.preferredWidth: 44
                                Layout.fillHeight: true
                                radius: Theme.radiusButton
                                color: colorRow.isWarm ? Qt.rgba(1, 200/255, 120/255, 0.20) : Theme.bgSecondary
                                border.color: colorRow.isWarm ? Qt.rgba(1, 200/255, 120/255, 1) : Theme.border
                                border.width: colorRow.isWarm ? 2 : 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "WW"
                                    color: colorRow.isWarm ? Qt.rgba(1, 200/255, 120/255, 1) : Theme.textSecondary
                                    font.pixelSize: 11; font.weight: Font.Bold
                                    font.family: Theme.fontMono
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: GCSState.worklightColor = Qt.rgba(1, 200/255, 120/255, 1)
                                }
                            }
                        }
                    }
                }
            }

            // ════════════════════ BRIGHTNESS CARD ════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 192
                radius: Theme.radiusCard
                color: Theme.bgElevated
                border.color: Theme.border
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "BRIGHTNESS"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSectionLabel
                            font.weight: Font.SemiBold
                            font.letterSpacing: 0.6
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "MASTER " + Math.round(masterSlider.value) + "%"
                            color: Theme.accentYellow
                            font.pixelSize: 10
                            font.family: Theme.fontMono
                            font.weight: Font.SemiBold
                        }
                    }

                    // Master slider
                    MiniSlider {
                        id: masterSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        trackColor: Theme.accentYellow
                        value: GCSState.brightnessScreenL

                        onPressedChanged: {
                            if (pressed) {
                                var cur = value || 1
                                brightnessRatios = [
                                    GCSState.brightnessScreenL / cur,
                                    GCSState.brightnessScreenR / cur,
                                    GCSState.brightnessLed     / cur,
                                    GCSState.brightnessTft     / cur,
                                    GCSState.brightnessBtnLeds / cur
                                ]
                            }
                        }
                        onMoved: {
                            var v = Math.round(value)
                            GCSState.brightnessScreenL = Math.min(100, Math.round(brightnessRatios[0] * v))
                            GCSState.brightnessScreenR = Math.min(100, Math.round(brightnessRatios[1] * v))
                            GCSState.brightnessLed     = Math.min(100, Math.round(brightnessRatios[2] * v))
                            GCSState.brightnessTft     = Math.min(100, Math.round(brightnessRatios[3] * v))
                            GCSState.brightnessBtnLeds = Math.min(100, Math.round(brightnessRatios[4] * v))
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; opacity: 0.6 }

                    // Per-channel grid: 5 mini sliders in two columns
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 2
                        rowSpacing: 4
                        columnSpacing: 14

                        // Channel definitions: [label, getter, setter property name]
                        Repeater {
                            model: [
                                { lbl: "SCREEN L", val: GCSState.brightnessScreenL, prop: "brightnessScreenL" },
                                { lbl: "SCREEN R", val: GCSState.brightnessScreenR, prop: "brightnessScreenR" },
                                { lbl: "LED STRIP", val: GCSState.brightnessLed,    prop: "brightnessLed" },
                                { lbl: "TFT",       val: GCSState.brightnessTft,    prop: "brightnessTft" },
                                { lbl: "BTN LEDS",  val: GCSState.brightnessBtnLeds, prop: "brightnessBtnLeds" }
                            ]

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: modelData.lbl
                                    color: Theme.textSecondary
                                    font.pixelSize: 9
                                    font.family: Theme.fontMono
                                    font.weight: Font.Medium
                                    Layout.preferredWidth: 64
                                }
                                MiniSlider {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 22
                                    trackColor: Theme.accentBlue
                                    value: modelData.val
                                    onMoved: GCSState[modelData.prop] = Math.round(value)
                                }
                                Text {
                                    text: modelData.val + "%"
                                    color: Theme.textPrimary
                                    font.pixelSize: 10
                                    font.family: Theme.fontMono
                                    Layout.preferredWidth: 32
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }

            // ════════════════════ QUICK LAYOUTS ════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                radius: Theme.radiusCard
                color: Theme.bgElevated
                border.color: Theme.border
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Text {
                        text: "QUICK LAYOUTS"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSectionLabel
                        font.weight: Font.SemiBold
                        font.letterSpacing: 0.6
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: ["PILOT", "MAP", "DEBUG", "POWER", "CLEAN"]
                            Rectangle {
                                Layout.fillWidth: true
                                height: 26
                                radius: Theme.radiusButton
                                property bool selected: panel.quickLayoutMode === modelData
                                color: selected ? Theme.accentYellowSoft : Theme.bgSecondary
                                border.color: selected ? Theme.accentYellow : Theme.border
                                border.width: selected ? 2 : 1
                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: parent.selected ? Theme.accentYellow : Theme.textSecondary
                                    font.pixelSize: 10
                                    font.weight: Font.SemiBold
                                    font.letterSpacing: 0.5
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: panel.quickLayoutMode = modelData
                                }
                            }
                        }
                    }
                }
            }

            // ════════════════════ FOOTER STATUS ════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: Theme.radiusCard
                color: Theme.bgSunken
                border.color: Theme.border
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    spacing: 16

                    Text {
                        text: "CPU " + GCSState.tempCpuPi.toFixed(0) + "°"
                        color: GCSState.tempCpuPi < 80 ? Theme.textSecondary : Theme.statusWarn
                        font.pixelSize: 10
                        font.family: Theme.fontMono
                    }
                    Text {
                        text: "MEM " + GCSState.memPercent + "%"
                        color: Theme.textSecondary
                        font.pixelSize: 10
                        font.family: Theme.fontMono
                    }
                    Text {
                        text: "DISK " + GCSState.diskPercent + "%"
                        color: Theme.textSecondary
                        font.pixelSize: 10
                        font.family: Theme.fontMono
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: panel.quickLayoutMode
                        color: Theme.accentBlue
                        font.pixelSize: Theme.fontSectionLabel
                        font.weight: Font.SemiBold
                        font.letterSpacing: 0.8
                    }
                }
            }
        }
    }
}
