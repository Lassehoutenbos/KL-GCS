import QtQuick
import QtQuick.Layouts
import PICODE

Rectangle {
    id: root

    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: Qt.lighter(Theme.bgSecondary, 1.04) }
        GradientStop { position: 1.0; color: Theme.bgSecondary }
    }

    // 1px inner top highlight (bevel)
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        color: Theme.borderSoft
    }
    // Bottom separator
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 1; color: Theme.border
    }

    signal quickPanelToggled()

    // Reusable vertical divider
    component VDiv: Rectangle {
        width: 1
        Layout.fillHeight: true
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        color: Theme.border
        opacity: 0.6
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── BRAND ────────────────────────────────────────────────────────────
        Item {
            Layout.preferredWidth: 44
            Layout.fillHeight: true

            BrandLogo {
                anchors.centerIn: parent
                variant: "mark"
                width: 26; height: 26
                alertTint: GCSState.anyWarningActive
                            && (GCSState.warnTemp === 2 || GCSState.warnDrone === 2 || GCSState.warnLink === 2)
                searching: !GCSState.mavlinkConnected
            }
        }

        VDiv {}

        // ── LINK ─────────────────────────────────────────────────────────────
        Item {
            Layout.preferredWidth: 110
            Layout.fillHeight: true

            RowLayout {
                anchors { fill: parent; leftMargin: 12 }
                spacing: 7
                StatusDot {
                    level: GCSState.mavlinkConnected ? 0 : 2
                }
                Text {
                    text: GCSState.mavlinkConnected ? "LINK" : "NO LINK"
                    color: GCSState.mavlinkConnected ? Theme.statusOk : Theme.statusCrit
                    font.pixelSize: Theme.fontSectionLabel
                    font.weight: Font.SemiBold
                    font.letterSpacing: 0.6
                    Behavior on color { ColorAnimation { duration: Theme.motionMedium } }
                }
            }
        }

        VDiv {}

        // ── GPS ───────────────────────────────────────────────────────────────
        Item {
            Layout.preferredWidth: 154
            Layout.fillHeight: true

            RowLayout {
                anchors { fill: parent; leftMargin: 12 }
                spacing: 6
                StatusDot {
                    level: GCSState.gpsSats >= 6 ? 0 : (GCSState.gpsSats > 0 ? 1 : 2)
                }
                Text {
                    text: "GPS"
                    color: Theme.textDisabled
                    font.pixelSize: Theme.fontMicro
                    font.weight: Font.Medium
                    font.letterSpacing: 0.4
                }
                Text {
                    text: GCSState.gpsSats.toString().padStart(2, '0')
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSectionLabel
                    font.weight: Font.SemiBold
                    font.family: Theme.fontMono
                }
                Text {
                    text: GCSState.gpsFixType
                    color: GCSState.gpsFixType === "NO-FIX" ? Theme.statusCrit : Theme.statusOk
                    font.pixelSize: Theme.fontMicro
                    font.weight: Font.SemiBold
                    font.letterSpacing: 0.5
                }
            }
        }

        VDiv {}

        // ── BATTERY ───────────────────────────────────────────────────────────
        Item {
            Layout.preferredWidth: 200
            Layout.fillHeight: true

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 6 }
                spacing: 7

                Text {
                    text: "BAT"
                    color: Theme.textDisabled
                    font.pixelSize: Theme.fontMicro
                    font.weight: Font.Medium
                    font.letterSpacing: 0.4
                }
                Text {
                    text: GCSState.batteryVoltage.toFixed(1) + "V"
                    color: GCSState.batteryPercent < 20 ? Theme.statusCrit
                         : GCSState.batteryPercent < 40 ? Theme.statusWarn
                         : Theme.textPrimary
                    font.pixelSize: Theme.fontSectionLabel
                    font.weight: Font.SemiBold
                    font.family: Theme.fontMono
                    Behavior on color { ColorAnimation { duration: Theme.motionMedium } }
                }
                Text {
                    text: GCSState.batteryPercent + "%"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontMicro
                    font.family: Theme.fontMono
                    font.weight: Font.Medium
                }

                // Smooth animated progress bar (replaces 5-segment bar — finer resolution)
                Rectangle {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 8
                    radius: 2
                    color: Theme.bgSunken
                    border.color: Theme.border
                    border.width: 1

                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 1 }
                        width: Math.max(0, (parent.width - 2) * Math.min(1, GCSState.batteryPercent / 100))
                        radius: 1
                        color: GCSState.batteryPercent < 20 ? Theme.statusCrit
                             : GCSState.batteryPercent < 40 ? Theme.statusWarn
                             : Theme.statusOk
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }
                }
            }
        }

        VDiv {}

        // ── ALTITUDE ─────────────────────────────────────────────────────────
        Item {
            Layout.preferredWidth: 110
            Layout.fillHeight: true

            RowLayout {
                anchors { fill: parent; leftMargin: 12 }
                spacing: 6
                Text {
                    text: "ALT"
                    color: Theme.textDisabled
                    font.pixelSize: Theme.fontMicro
                    font.weight: Font.Medium
                    font.letterSpacing: 0.4
                }
                Text {
                    text: GCSState.altitude.toFixed(0).padStart(3, '0')
                    color: Theme.accentBlue
                    font.pixelSize: Theme.fontSectionLabel
                    font.weight: Font.SemiBold
                    font.family: Theme.fontMono
                }
                Text {
                    text: "m"
                    color: Theme.textDisabled
                    font.pixelSize: Theme.fontMicro
                }
            }
        }

        VDiv {}

        Item { Layout.fillWidth: true }

        // ── CLOCK ─────────────────────────────────────────────────────────────
        Item {
            Layout.preferredWidth: 80
            Layout.fillHeight: true

            Text {
                id: clockText
                anchors.centerIn: parent
                text: Qt.formatTime(new Date(), "hh:mm")
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSectionLabel
                font.weight: Font.Medium
                font.family: Theme.fontMono
                font.letterSpacing: 1.0
            }

            // Tick every 5s — clock displays minutes; cheap and stays accurate.
            Timer {
                interval: 5000; running: true; repeat: true
                triggeredOnStart: true
                onTriggered: clockText.text = Qt.formatTime(new Date(), "hh:mm")
            }
        }

        VDiv {}

        // ── MENU AFFORDANCE (only this opens QuickPanel — not "tap anywhere") ─
        Item {
            id: menuTrigger
            Layout.preferredWidth: Theme.statusBarH
            Layout.fillHeight: true

            Rectangle {
                anchors.fill: parent
                color: menuArea.pressed ? Theme.accentYellowSoft
                     : menuArea.containsMouse ? Qt.rgba(1,1,1,0.04)
                     : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            }

            // 3-line "menu" glyph
            Column {
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: 3
                    Rectangle {
                        width: 16; height: 2; radius: 1
                        color: menuArea.pressed ? Theme.accentYellow : Theme.textSecondary
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    }
                }
            }

            MouseArea {
                id: menuArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.quickPanelToggled()
            }
        }
    }
}
