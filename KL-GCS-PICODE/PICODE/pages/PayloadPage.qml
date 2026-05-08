import QtQuick
import QtQuick.Layouts
import PICODE

Rectangle {
    id: root
    color: Theme.bgPrimary

    // ── Local event log (in-memory only) ─────────────────────────────────────
    property var fireLog: []
    property int pay1FireCount: 0
    property int pay2FireCount: 0
    property var lastPay1FireT: null
    property var lastPay2FireT: null

    function logEvent(bay, kind, on) {
        var t = Date.now()
        var line = { t: t, bay: bay, kind: kind, on: on }
        var arr = fireLog.slice()
        arr.unshift(line)
        while (arr.length > 60) arr.pop()
        fireLog = arr
        if (kind === "FIRE" && on) {
            if (bay === 1) { pay1FireCount++; lastPay1FireT = t }
            else            { pay2FireCount++; lastPay2FireT = t }
        }
    }

    function fmtTime(t) {
        var d = new Date(t)
        function p(n){ return n < 10 ? "0"+n : ""+n }
        return p(d.getHours()) + ":" + p(d.getMinutes()) + ":" + p(d.getSeconds())
    }
    function fmtAgo(t) {
        if (!t) return "—"
        var s = Math.floor((Date.now() - t) / 1000)
        if (s < 60) return s + "s ago"
        if (s < 3600) return Math.floor(s / 60) + "m ago"
        return Math.floor(s / 3600) + "h ago"
    }

    Connections {
        target: GCSState
        function onSwitchStateChanged() {
            if (GCSState.sw3Pay1Arm  !== root._lastP1Arm)  { logEvent(1, "ARM",  GCSState.sw3Pay1Arm);  root._lastP1Arm  = GCSState.sw3Pay1Arm }
            if (GCSState.sw3Pay2Arm  !== root._lastP2Arm)  { logEvent(2, "ARM",  GCSState.sw3Pay2Arm);  root._lastP2Arm  = GCSState.sw3Pay2Arm }
            if (GCSState.sw3Pay1Fire !== root._lastP1Fire) { logEvent(1, "FIRE", GCSState.sw3Pay1Fire); root._lastP1Fire = GCSState.sw3Pay1Fire }
            if (GCSState.sw3Pay2Fire !== root._lastP2Fire) { logEvent(2, "FIRE", GCSState.sw3Pay2Fire); root._lastP2Fire = GCSState.sw3Pay2Fire }
        }
    }
    property bool _lastP1Arm:  GCSState.sw3Pay1Arm
    property bool _lastP2Arm:  GCSState.sw3Pay2Arm
    property bool _lastP1Fire: GCSState.sw3Pay1Fire
    property bool _lastP2Fire: GCSState.sw3Pay2Fire

    // 1Hz tick to refresh "ago" text
    Timer { interval: 1000; running: true; repeat: true; onTriggered: agoTick++ }
    property int agoTick: 0

    // ── Layout ───────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ════════════════ TOP: SAFETY STATUS BAR ════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            color: GCSState.sw1Arm ? Qt.rgba(1, 0.36, 0.36, 0.06) : Theme.bgSecondary
            border.color: GCSState.sw1Arm ? Theme.statusCrit : Theme.border
            border.width: 1
            Behavior on color { ColorAnimation { duration: 220 } }

            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 18

                // KEY
                ColumnLayout {
                    spacing: 1
                    Text { text: "KEY"; color: Theme.textDisabled; font.pixelSize: 9; font.weight: Font.SemiBold; font.letterSpacing: 0.6 }
                    RowLayout {
                        spacing: 6
                        StatusDot { level: GCSState.keyUnlocked ? 0 : 1 }
                        Text {
                            text: GCSState.keyUnlocked ? "UNLOCKED" : "LOCKED"
                            color: GCSState.keyUnlocked ? Theme.statusOk : Theme.statusWarn
                            font.pixelSize: Theme.fontValueSmall; font.weight: Font.Bold; font.family: Theme.fontMono
                        }
                    }
                }

                Rectangle { width: 1; Layout.fillHeight: true; Layout.topMargin: 12; Layout.bottomMargin: 12; color: Theme.border }

                // MASTER ARM
                ColumnLayout {
                    spacing: 1
                    Text { text: "MASTER ARM"; color: Theme.textDisabled; font.pixelSize: 9; font.weight: Font.SemiBold; font.letterSpacing: 0.6 }
                    RowLayout {
                        spacing: 6
                        StatusDot { level: GCSState.sw1Arm ? 2 : 0 }
                        Text {
                            text: GCSState.sw1Arm ? "ARMED" : "SAFE"
                            color: GCSState.sw1Arm ? Theme.statusCrit : Theme.statusOk
                            font.pixelSize: Theme.fontValueSmall; font.weight: Font.Bold; font.family: Theme.fontMono
                        }
                    }
                }

                Rectangle { width: 1; Layout.fillHeight: true; Layout.topMargin: 12; Layout.bottomMargin: 12; color: Theme.border }

                // DRONE
                ColumnLayout {
                    spacing: 1
                    Text { text: "DRONE"; color: Theme.textDisabled; font.pixelSize: 9; font.weight: Font.SemiBold; font.letterSpacing: 0.6 }
                    RowLayout {
                        spacing: 6
                        StatusDot { level: GCSState.droneArmed ? 2 : 0 }
                        Text {
                            text: GCSState.droneArmed ? "ARMED" : "DISARMED"
                            color: GCSState.droneArmed ? Theme.statusCrit : Theme.statusOk
                            font.pixelSize: Theme.fontValueSmall; font.weight: Font.Bold; font.family: Theme.fontMono
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // System status badge
                Rectangle {
                    width: sysBadge.width + 16; height: 28; radius: 4
                    property bool danger: GCSState.sw1Arm && (GCSState.sw3Pay1Arm || GCSState.sw3Pay2Arm)
                    color: danger ? Qt.rgba(1, 0.36, 0.36, 0.15)
                                  : (GCSState.keyUnlocked ? Qt.rgba(0.38, 0.83, 0.56, 0.12) : Qt.rgba(1, 0.7, 0.28, 0.12))
                    border.color: danger ? Theme.statusCrit
                                         : (GCSState.keyUnlocked ? Theme.statusOk : Theme.statusWarn)
                    border.width: 1
                    Text {
                        id: sysBadge; anchors.centerIn: parent
                        text: parent.danger ? "PAYLOAD HOT"
                            : GCSState.keyUnlocked ? "OPERATIONAL" : "STANDBY"
                        color: parent.danger ? Theme.statusCrit
                            : (GCSState.keyUnlocked ? Theme.statusOk : Theme.statusWarn)
                        font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 0.6
                    }
                }
            }
        }

        // ════════════════ MIDDLE: BAYS + EVENT LOG ════════════════
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 1

            // ── LEFT: PAY1 + PAY2 cards ──
            ColumnLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: 640
                spacing: 1

                Repeater {
                    model: [
                        { idx: 1, arm: GCSState.sw3Pay1Arm, fire: GCSState.sw3Pay1Fire, count: pay1FireCount, lastT: lastPay1FireT },
                        { idx: 2, arm: GCSState.sw3Pay2Arm, fire: GCSState.sw3Pay2Fire, count: pay2FireCount, lastT: lastPay2FireT }
                    ]
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: modelData.fire ? Qt.rgba(1, 0.36, 0.36, 0.10)
                             : modelData.arm ? Qt.rgba(1, 0.7, 0.28, 0.06)
                             : Theme.bgSecondary
                        border.color: modelData.fire ? Theme.statusCrit
                                    : modelData.arm  ? Theme.statusWarn
                                    : Theme.border
                        border.width: modelData.arm ? 2 : 1
                        Behavior on color { ColorAnimation { duration: 220 } }
                        Behavior on border.color { ColorAnimation { duration: 220 } }

                        // Hot-side accent bar
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: modelData.arm ? 4 : 0
                            color: modelData.fire ? Theme.statusCrit : Theme.statusWarn
                            Behavior on width { NumberAnimation { duration: 160 } }
                        }

                        RowLayout {
                            anchors { fill: parent; margins: 14; leftMargin: modelData.arm ? 18 : 14 }
                            spacing: 18

                            // ── BIG BAY VISUAL ──
                            Item {
                                Layout.preferredWidth: 124
                                Layout.fillHeight: true

                                // Outer ring
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 110; height: 110; radius: 55
                                    color: "transparent"
                                    border.color: modelData.fire ? Theme.statusCrit
                                                : modelData.arm  ? Theme.statusWarn
                                                : Theme.border
                                    border.width: 2

                                    // Pulsing inner glow when armed
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 88; height: 88; radius: 44
                                        color: modelData.fire ? Theme.statusCrit
                                             : modelData.arm  ? Qt.rgba(1, 0.7, 0.28, 0.20)
                                             : Theme.bgElevated
                                        opacity: modelData.fire ? 1.0 : (modelData.arm ? 0.7 : 0.35)
                                        SequentialAnimation on opacity {
                                            running: modelData.arm && !modelData.fire
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 0.35; to: 0.85; duration: 700; easing.type: Easing.InOutQuad }
                                            NumberAnimation { from: 0.85; to: 0.35; duration: 700; easing.type: Easing.InOutQuad }
                                        }
                                    }

                                    // Center label
                                    Text {
                                        anchors.centerIn: parent
                                        text: "PAY " + modelData.idx
                                        color: modelData.fire ? Theme.bgPrimary
                                             : modelData.arm  ? Theme.statusWarn
                                             : Theme.textSecondary
                                        font.pixelSize: 22; font.weight: Font.Bold; font.letterSpacing: 0.8
                                    }
                                }
                            }

                            // ── STATE COLUMN ──
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "BAY " + modelData.idx
                                        color: Theme.textPrimary; font.pixelSize: 14; font.weight: Font.Bold; font.letterSpacing: 0.5
                                    }
                                    Item { Layout.fillWidth: true }
                                    Rectangle {
                                        width: badge.width + 14; height: 24; radius: 3
                                        color: modelData.fire ? Theme.statusCrit
                                             : modelData.arm  ? Qt.rgba(1, 0.7, 0.28, 0.15)
                                             : Qt.rgba(1, 1, 1, 0.05)
                                        border.color: modelData.fire ? Theme.statusCrit
                                                    : modelData.arm  ? Theme.statusWarn
                                                    : Theme.border
                                        border.width: 1
                                        Text {
                                            id: badge; anchors.centerIn: parent
                                            text: modelData.fire ? "FIRING" : (modelData.arm ? "ARMED" : "SAFE")
                                            color: modelData.fire ? Theme.bgPrimary
                                                : modelData.arm  ? Theme.statusWarn
                                                : Theme.statusOk
                                            font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 0.6
                                        }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                                // Fire pulse bar (big)
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 12
                                    radius: 3
                                    color: Theme.bgSunken
                                    border.color: Theme.border; border.width: 1
                                    Rectangle {
                                        width: modelData.fire ? parent.width - 2 : 0
                                        x: 1; y: 1
                                        height: parent.height - 2
                                        radius: 2
                                        color: Theme.statusCrit
                                        Behavior on width { NumberAnimation { duration: 80 } }
                                    }
                                }

                                // Stat row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    Layout.topMargin: 4

                                    ColumnLayout {
                                        spacing: 1
                                        Text { text: "ARM SW";  color: Theme.textDisabled; font.pixelSize: 9; font.weight: Font.SemiBold; font.letterSpacing: 0.4 }
                                        Text {
                                            text: modelData.arm ? "ON" : "OFF"
                                            color: modelData.arm ? Theme.statusCrit : Theme.textSecondary
                                            font.pixelSize: 14; font.weight: Font.Bold; font.family: Theme.fontMono
                                        }
                                    }
                                    ColumnLayout {
                                        spacing: 1
                                        Text { text: "FIRE BTN"; color: Theme.textDisabled; font.pixelSize: 9; font.weight: Font.SemiBold; font.letterSpacing: 0.4 }
                                        Text {
                                            text: modelData.fire ? "ACTIVE" : "IDLE"
                                            color: modelData.fire ? Theme.statusCrit : Theme.textSecondary
                                            font.pixelSize: 14; font.weight: Font.Bold; font.family: Theme.fontMono
                                        }
                                    }
                                    ColumnLayout {
                                        spacing: 1
                                        Text { text: "FIRES";    color: Theme.textDisabled; font.pixelSize: 9; font.weight: Font.SemiBold; font.letterSpacing: 0.4 }
                                        Text {
                                            text: modelData.count
                                            color: modelData.count > 0 ? Theme.accentYellow : Theme.textSecondary
                                            font.pixelSize: 14; font.weight: Font.Bold; font.family: Theme.fontMono
                                        }
                                    }
                                    ColumnLayout {
                                        spacing: 1
                                        Text { text: "LAST FIRE"; color: Theme.textDisabled; font.pixelSize: 9; font.weight: Font.SemiBold; font.letterSpacing: 0.4 }
                                        Text {
                                            text: { var _ = agoTick; return fmtAgo(modelData.lastT) }
                                            color: Theme.accentBlue
                                            font.pixelSize: 14; font.weight: Font.Bold; font.family: Theme.fontMono
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.border }

            // ── RIGHT: Activity log ──
            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                spacing: 0

                Item {
                    Layout.fillWidth: true; height: 30
                    Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 3; color: Theme.accentBlue }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 11; rightMargin: 10 }
                        Text {
                            text: "ACTIVITY LOG"
                            color: Theme.textSecondary; font.pixelSize: Theme.fontPageTitle; font.weight: Font.SemiBold; font.letterSpacing: 0.8
                            Layout.fillWidth: true
                        }
                        Text {
                            text: fireLog.length + " events"
                            color: Theme.textDisabled; font.pixelSize: 10; font.family: Theme.fontMono
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                // Empty state
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    visible: fireLog.length === 0
                    Text {
                        anchors.centerIn: parent
                        text: "No events yet.\nArm/fire transitions will appear here."
                        color: Theme.textDisabled
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Theme.fontSectionLabel
                    }
                }

                ListView {
                    id: logList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: fireLog.length > 0
                    clip: true
                    model: fireLog
                    delegate: Rectangle {
                        width: logList.width
                        height: 30
                        color: index % 2 === 0 ? Theme.bgPrimary : Theme.bgSecondary

                        property color accentColor: modelData.kind === "FIRE"
                            ? (modelData.on ? Theme.statusCrit : Theme.textDisabled)
                            : (modelData.on ? Theme.statusWarn : Theme.statusOk)

                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: 3; color: parent.accentColor
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                            spacing: 10

                            Text {
                                text: fmtTime(modelData.t)
                                color: Theme.textDisabled
                                font.pixelSize: 10; font.family: Theme.fontMono
                                Layout.preferredWidth: 64
                            }
                            Text {
                                text: "PAY " + modelData.bay
                                color: Theme.textSecondary
                                font.pixelSize: 10; font.weight: Font.SemiBold; font.family: Theme.fontMono
                                Layout.preferredWidth: 44
                            }
                            Text {
                                text: modelData.kind
                                color: parent.parent.accentColor
                                font.pixelSize: 10; font.weight: Font.Bold; font.family: Theme.fontMono
                                Layout.preferredWidth: 40
                            }
                            Text {
                                text: modelData.on ? (modelData.kind === "FIRE" ? "▶ ACTIVE" : "▲ ON")
                                                   : (modelData.kind === "FIRE" ? "■ ENDED" : "▼ OFF")
                                color: parent.parent.accentColor
                                font.pixelSize: 10; font.weight: Font.SemiBold; font.family: Theme.fontMono
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        // ════════════════ BOTTOM: LED legend ════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            color: Theme.bgSecondary
            border.color: Theme.border; border.width: 1

            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 22
                Text {
                    text: "LED FEEDBACK · WS2811 chain"
                    color: Theme.textDisabled
                    font.pixelSize: 10; font.weight: Font.SemiBold; font.letterSpacing: 0.6
                }
                Repeater {
                    model: [
                        { lbl: "DISARMED", col: Theme.textDisabled, desc: "off"           },
                        { lbl: "ARMED",    col: Theme.statusWarn,   desc: "blink orange"  },
                        { lbl: "FIRING",   col: Theme.statusCrit,   desc: "solid red"     }
                    ]
                    RowLayout {
                        spacing: 6
                        Rectangle { width: 8; height: 8; radius: 4; color: modelData.col }
                        Text { text: modelData.lbl; color: modelData.col; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 0.4 }
                        Text { text: "· " + modelData.desc; color: Theme.textDisabled; font.pixelSize: 10; font.family: Theme.fontMono }
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }
    }
}
