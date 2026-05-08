import QtQuick
import QtQuick.Layouts
import PICODE

Rectangle {
    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: Theme.bgGradTop }
        GradientStop { position: 1.0; color: Theme.bgGradBottom }
    }

    function warnLabel(v) { return v === 0 ? "OK" : (v === 1 ? "WARNING" : "CRITICAL") }
    function warnColor(v) { return v === 0 ? Theme.statusOk : (v === 1 ? Theme.statusWarn : Theme.statusCrit) }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        // ── LEFT: Drone stats ─────────────────────────────────────── 280px ──
        Rectangle {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Theme.panelTop }
                GradientStop { position: 1.0; color: Theme.panelBottom }
            }
            border.color: Theme.border; border.width: 1

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1; leftMargin: 1; rightMargin: 1 }
                height: 1; color: Theme.borderSoft
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                SectionHeader { Layout.fillWidth: true; text: "DRONE"; accent: "yellow" }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: Theme.spaceMd
                    spacing: Theme.spaceSm

                    Repeater {
                        model: [
                            { lbl: "ALTITUDE",  val: GCSState.altitude.toFixed(1),     unit: "m" },
                            { lbl: "SPEED",     val: GCSState.groundSpeed.toFixed(1),  unit: "m/s" },
                            { lbl: "HEADING",   val: GCSState.heading.toFixed(0),      unit: "°" },
                            { lbl: "CLIMB",     val: (GCSState.verticalSpeed >= 0 ? "+" : "") + GCSState.verticalSpeed.toFixed(1), unit: "m/s" }
                        ]
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: modelData.lbl;  color: Theme.textDisabled;  font.pixelSize: Theme.fontSectionLabel; font.weight: Font.Medium; Layout.preferredWidth: 78; font.letterSpacing: 0.4 }
                            Text { text: modelData.val;  color: Theme.textPrimary;   font.pixelSize: Theme.fontValueSmall;   font.weight: Font.Bold;    Layout.fillWidth: true; font.family: Theme.fontMono }
                            Text { text: modelData.unit; color: Theme.textDisabled;  font.pixelSize: Theme.fontUnit }
                        }
                    }
                }

                SectionHeader { Layout.fillWidth: true; text: "MODE & ARM"; accent: "blue"; compact: true }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: Theme.spaceMd
                    spacing: Theme.spaceSm

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "MODE";  color: Theme.textDisabled; font.pixelSize: Theme.fontSectionLabel; font.weight: Font.Medium; Layout.preferredWidth: 42; font.letterSpacing: 0.4 }
                        Text { text: GCSState.flightMode; color: Theme.accentYellow; font.pixelSize: Theme.fontValueSmall; font.weight: Font.Bold; font.family: Theme.fontMono }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: Theme.spaceSm
                        Text { text: "ARMED"; color: Theme.textDisabled; font.pixelSize: Theme.fontSectionLabel; font.weight: Font.Medium; Layout.preferredWidth: 42; font.letterSpacing: 0.4 }
                        StatusDot { level: GCSState.droneArmed ? 2 : 0 }
                        Text {
                            text: GCSState.droneArmed ? "ARMED" : "DISARMED"
                            color: GCSState.droneArmed ? Theme.statusCrit : Theme.statusOk
                            font.pixelSize: Theme.fontValueSmall; font.weight: Font.Bold; font.family: Theme.fontMono
                            Behavior on color { ColorAnimation { duration: Theme.motionMedium } }
                        }
                    }
                }

                SectionHeader { Layout.fillWidth: true; text: "POWER"; accent: "blue"; compact: true }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: Theme.spaceMd
                    spacing: Theme.spaceSm

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "BATTERY";  color: Theme.textDisabled; font.pixelSize: Theme.fontSectionLabel; font.weight: Font.Medium; Layout.preferredWidth: 78; font.letterSpacing: 0.4 }
                        Text {
                            text: GCSState.batteryVoltage.toFixed(1) + "V"
                            color: GCSState.batteryPercent < 20 ? Theme.statusCrit
                                 : GCSState.batteryPercent < 40 ? Theme.statusWarn
                                 : Theme.textPrimary
                            font.pixelSize: Theme.fontValueSmall; font.weight: Font.Bold; font.family: Theme.fontMono
                            Behavior on color { ColorAnimation { duration: Theme.motionMedium } }
                        }
                        Item { Layout.fillWidth: true }
                        Text { text: GCSState.batteryPercent + "%"; color: Theme.textSecondary; font.pixelSize: Theme.fontSectionLabel; font.family: Theme.fontMono }
                    }

                    // Smooth battery bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 2
                        color: Theme.bgSunken
                        border.color: Theme.border; border.width: 1

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

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "EXTERNAL";  color: Theme.textDisabled; font.pixelSize: Theme.fontSectionLabel; font.weight: Font.Medium; Layout.preferredWidth: 78; font.letterSpacing: 0.4 }
                        Text { text: GCSState.extVoltage.toFixed(1) + "V"; color: Theme.textPrimary; font.pixelSize: Theme.fontValueSmall; font.weight: Font.Bold; font.family: Theme.fontMono }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        Rectangle { width: 1; Layout.fillHeight: true; color: Theme.border }

        // ── CENTER: Attitude HUD ──────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors { fill: parent; margins: 8 }
                spacing: 6

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Canvas {
                        id: hudCanvas
                        anchors.fill: parent

                        onPaint: {
                            var ctx = getContext("2d")
                            var w = width, h = height
                            var cx = w / 2, cy = h / 2
                            var pitch = GCSState.pitch
                            var roll  = GCSState.roll

                            ctx.clearRect(0, 0, w, h)

                            ctx.save()
                            ctx.beginPath(); ctx.rect(0, 0, w, h); ctx.clip()
                            ctx.translate(cx, cy)
                            ctx.rotate(-roll * Math.PI / 180)

                            var pOff = -pitch * 3

                            // Sky gradient (top → horizon)
                            var skyGrad = ctx.createLinearGradient(0, -h * 2, 0, pOff)
                            skyGrad.addColorStop(0, "#04101c")
                            skyGrad.addColorStop(1, "#0a2236")
                            ctx.fillStyle = skyGrad
                            ctx.fillRect(-w, -h * 2, w * 2, h * 2 + pOff)

                            // Ground gradient (horizon → bottom)
                            var grdGrad = ctx.createLinearGradient(0, pOff, 0, pOff + h * 2)
                            grdGrad.addColorStop(0, "#3a2010")
                            grdGrad.addColorStop(1, "#1a0d05")
                            ctx.fillStyle = grdGrad
                            ctx.fillRect(-w, pOff, w * 2, h * 2)

                            // Horizon line (glowing)
                            ctx.shadowColor = "rgba(127,214,255,0.5)"
                            ctx.shadowBlur = 6
                            ctx.strokeStyle = "#7fd6ff"
                            ctx.lineWidth = 2
                            ctx.beginPath()
                            ctx.moveTo(-w, pOff); ctx.lineTo(w, pOff)
                            ctx.stroke()
                            ctx.shadowBlur = 0

                            // Pitch ladder
                            for (var deg = -30; deg <= 30; deg += 5) {
                                if (deg === 0) continue
                                var ly = pOff - deg * 3
                                var lw = (deg % 10 === 0) ? 56 : 28
                                ctx.strokeStyle = "rgba(255,255,255,0.65)"
                                ctx.lineWidth = (deg % 10 === 0) ? 1.5 : 1
                                ctx.beginPath()
                                ctx.moveTo(-lw / 2, ly); ctx.lineTo(lw / 2, ly)
                                ctx.stroke()
                                if (deg % 10 === 0) {
                                    ctx.fillStyle = "rgba(255,255,255,0.7)"
                                    ctx.font = "bold 9px monospace"
                                    ctx.textAlign = "left"
                                    ctx.fillText(deg.toString(), lw / 2 + 5, ly + 3)
                                }
                            }
                            ctx.restore()

                            // Aircraft reticle
                            ctx.strokeStyle = "#e3d049"
                            ctx.lineWidth = 2.5
                            ctx.shadowColor = "rgba(227,208,73,0.4)"
                            ctx.shadowBlur = 4
                            ctx.beginPath(); ctx.moveTo(cx - 60, cy); ctx.lineTo(cx - 20, cy); ctx.stroke()
                            ctx.beginPath(); ctx.moveTo(cx - 20, cy); ctx.lineTo(cx - 20, cy + 12); ctx.stroke()
                            ctx.beginPath(); ctx.moveTo(cx + 20, cy); ctx.lineTo(cx + 60, cy); ctx.stroke()
                            ctx.beginPath(); ctx.moveTo(cx + 20, cy); ctx.lineTo(cx + 20, cy + 12); ctx.stroke()
                            ctx.fillStyle = "#e3d049"
                            ctx.beginPath(); ctx.arc(cx, cy, 4, 0, 2 * Math.PI); ctx.fill()
                            ctx.shadowBlur = 0

                            // Roll arc
                            var rad = Math.min(cx, cy) - 14
                            ctx.strokeStyle = "rgba(127,214,255,0.4)"
                            ctx.lineWidth = 1
                            ctx.beginPath()
                            ctx.arc(cx, cy, rad, -Math.PI * 0.75, -Math.PI * 0.25)
                            ctx.stroke()

                            // Roll arc tick marks at -45,-30,-15,0,15,30,45
                            var ticks = [-45, -30, -15, 0, 15, 30, 45]
                            for (var i = 0; i < ticks.length; i++) {
                                var a = (-90 + ticks[i]) * Math.PI / 180
                                var x1 = cx + Math.cos(a) * rad
                                var y1 = cy + Math.sin(a) * rad
                                var inner = ticks[i] === 0 ? rad - 8 : rad - 5
                                var x2 = cx + Math.cos(a) * inner
                                var y2 = cy + Math.sin(a) * inner
                                ctx.strokeStyle = "rgba(127,214,255,0.55)"
                                ctx.lineWidth = ticks[i] === 0 ? 2 : 1
                                ctx.beginPath()
                                ctx.moveTo(x1, y1); ctx.lineTo(x2, y2)
                                ctx.stroke()
                            }

                            // Roll pointer
                            ctx.save()
                            ctx.translate(cx, cy)
                            ctx.rotate(-roll * Math.PI / 180)
                            ctx.fillStyle = "#7fd6ff"
                            ctx.beginPath()
                            ctx.moveTo(0, -rad); ctx.lineTo(-5, -(rad - 10)); ctx.lineTo(5, -(rad - 10))
                            ctx.closePath(); ctx.fill()
                            ctx.restore()
                        }

                        Connections {
                            target: GCSState
                            function onDroneStateChanged() { hudCanvas.requestPaint() }
                        }
                    }

                    // Thin accent border around HUD
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: Qt.rgba(0.5, 0.84, 1.0, 0.22)
                        border.width: 1
                        radius: 3
                    }
                    // Corner brackets
                    Rectangle { anchors { top: parent.top; left: parent.left } width: 14; height: 1.5; color: Theme.accentBlue; opacity: 0.7 }
                    Rectangle { anchors { top: parent.top; left: parent.left } width: 1.5; height: 14; color: Theme.accentBlue; opacity: 0.7 }
                    Rectangle { anchors { top: parent.top; right: parent.right } width: 14; height: 1.5; color: Theme.accentBlue; opacity: 0.7 }
                    Rectangle { anchors { top: parent.top; right: parent.right } width: 1.5; height: 14; color: Theme.accentBlue; opacity: 0.7 }
                    Rectangle { anchors { bottom: parent.bottom; left: parent.left } width: 14; height: 1.5; color: Theme.accentBlue; opacity: 0.7 }
                    Rectangle { anchors { bottom: parent.bottom; left: parent.left } width: 1.5; height: 14; color: Theme.accentBlue; opacity: 0.7 }
                    Rectangle { anchors { bottom: parent.bottom; right: parent.right } width: 14; height: 1.5; color: Theme.accentBlue; opacity: 0.7 }
                    Rectangle { anchors { bottom: parent.bottom; right: parent.right } width: 1.5; height: 14; color: Theme.accentBlue; opacity: 0.7 }
                }

                // Attitude readouts
                RowLayout {
                    Layout.fillWidth: true
                    height: 44
                    spacing: 0

                    Repeater {
                        model: [
                            { lbl: "PITCH", val: (GCSState.pitch >= 0 ? "+" : "") + GCSState.pitch.toFixed(1) + "°" },
                            { lbl: "ROLL",  val: (GCSState.roll  >= 0 ? "+" : "") + GCSState.roll.toFixed(1)  + "°" },
                            { lbl: "YAW",   val: GCSState.yaw.toFixed(0) + "°" }
                        ]
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { Layout.alignment: Qt.AlignHCenter; text: modelData.lbl; color: Theme.textDisabled; font.pixelSize: 10; font.weight: Font.Medium; font.letterSpacing: 0.6 }
                            Text { Layout.alignment: Qt.AlignHCenter; text: modelData.val; color: Theme.accentBlue;   font.pixelSize: Theme.fontValueMedium; font.weight: Font.Bold; font.family: Theme.fontMono }
                        }
                    }
                }

            }
        }

        Rectangle { width: 1; Layout.fillHeight: true; color: Theme.border }

        // ── RIGHT: Case Overview ──────────────────────────────────── 400px ──
        Rectangle {
            Layout.preferredWidth: 400
            Layout.fillHeight: true
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Theme.panelTop }
                GradientStop { position: 1.0; color: Theme.panelBottom }
            }
            border.color: Theme.border; border.width: 1

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1; leftMargin: 1; rightMargin: 1 }
                height: 1; color: Theme.borderSoft
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                SectionHeader {
                    Layout.fillWidth: true
                    text: "CASE OVERVIEW"
                    accent: "yellow"

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8; height: 8; radius: 4
                            color: GCSState.worklightOn ? Theme.accentYellow : Theme.textDisabled
                            opacity: GCSState.worklightOn ? 1 : 0.4
                            Behavior on color { ColorAnimation { duration: Theme.motionMedium } }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: GCSState.worklightOn ? "WORKLIGHT" : "OFF"
                            color: GCSState.worklightOn ? Theme.accentYellow : Theme.textDisabled
                            font.pixelSize: Theme.fontMicro
                            font.family: Theme.fontMono
                            Behavior on color { ColorAnimation { duration: Theme.motionMedium } }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "· " + GCSState.alsLux.toFixed(0) + " lx"
                            color: Theme.textDisabled
                            font.pixelSize: Theme.fontMicro
                            font.family: Theme.fontMono
                        }
                    }
                }

                CaseView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }

    // ── BOTTOM: GCS state · Warnings · LoRa messages ─────────────── 148px ──
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 148
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Theme.panelTop }
            GradientStop { position: 1.0; color: Theme.panelBottom }
        }
        border.color: Theme.border; border.width: 1

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // GCS state column
            Item {
                Layout.preferredWidth: 320
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    SectionHeader { Layout.fillWidth: true; text: "GCS"; accent: "blue"; compact: true }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: Theme.spaceMd
                        Layout.rightMargin: Theme.spaceMd
                        Layout.topMargin: Theme.spaceSm
                        Layout.bottomMargin: Theme.spaceSm
                        spacing: 4

                        Repeater {
                            model: [
                                { lbl: "TELEMETRY",   dot: GCSState.mavlinkConnected ? 0 : 2,
                                  val: GCSState.mavlinkConnected ? "OK" : "NO LINK",
                                  col: GCSState.mavlinkConnected ? Theme.statusOk : Theme.statusCrit },
                                { lbl: "GPS",         dot: GCSState.gpsSats >= 6 ? 0 : (GCSState.gpsSats > 0 ? 1 : 2),
                                  val: GCSState.gpsSats + "  " + GCSState.gpsFixType,
                                  col: Theme.textPrimary },
                                { lbl: "AMBIENT",     dot: 0,
                                  val: GCSState.alsLux.toFixed(0) + " lux",
                                  col: Theme.textPrimary },
                                { lbl: "CPU",         dot: GCSState.tempCpuPi < 60 ? 0 : (GCSState.tempCpuPi < 80 ? 1 : 2),
                                  val: GCSState.tempCpuPi.toFixed(0) + "°C",
                                  col: Theme.textPrimary }
                            ]
                            RowLayout {
                                Layout.fillWidth: true; spacing: Theme.spaceSm
                                StatusDot { level: modelData.dot }
                                Text { text: modelData.lbl; color: Theme.textDisabled; font.pixelSize: 10; font.weight: Font.Medium; Layout.preferredWidth: 78; font.letterSpacing: 0.3 }
                                Text { text: modelData.val; color: modelData.col; font.pixelSize: Theme.fontValueSmall; font.weight: Font.SemiBold; Layout.fillWidth: true; font.family: Theme.fontMono }
                            }
                        }
                    }
                }
            }

            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.border }

            // Warnings grid
            Item {
                Layout.preferredWidth: 320
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    SectionHeader {
                        Layout.fillWidth: true
                        text: "WARNINGS"
                        accent: "crit"
                        compact: true
                        alert: GCSState.anyWarningActive
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: Theme.spaceSm
                        Layout.rightMargin: Theme.spaceSm
                        Layout.topMargin: Theme.spaceSm
                        Layout.bottomMargin: Theme.spaceSm
                        columns: 2
                        rowSpacing: 3
                        columnSpacing: 4

                        Repeater {
                            model: [
                                { lbl: "TEMPERATURE", level: GCSState.warnTemp },
                                { lbl: "SIGNAL",      level: GCSState.warnSignal },
                                { lbl: "DRONE",       level: GCSState.warnDrone },
                                { lbl: "GPS",         level: GCSState.warnGps },
                                { lbl: "LINK",        level: GCSState.warnLink },
                                { lbl: "NETWORK",     level: GCSState.warnNetwork }
                            ]

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 3
                                color: modelData.level === 0
                                       ? "transparent"
                                       : Qt.rgba(1, modelData.level === 1 ? 0.7 : 0.36, modelData.level === 1 ? 0.28 : 0.36, 0.07)
                                border.color: modelData.level === 0 ? Theme.border : warnColor(modelData.level)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.motionMedium } }
                                Behavior on border.color { ColorAnimation { duration: Theme.motionMedium } }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                    spacing: 4
                                    StatusDot { level: modelData.level }
                                    Text { text: modelData.lbl; color: Theme.textDisabled; font.pixelSize: 9; font.weight: Font.Medium; Layout.fillWidth: true; font.letterSpacing: 0.3 }
                                    Text {
                                        text: warnLabel(modelData.level)
                                        color: warnColor(modelData.level)
                                        font.pixelSize: 9; font.weight: Font.Bold; font.family: Theme.fontMono; font.letterSpacing: 0.3
                                        Behavior on color { ColorAnimation { duration: Theme.motionMedium } }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.border }

            // LoRa messages
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    SectionHeader {
                        Layout.fillWidth: true
                        text: "LORA MESSAGES"
                        accent: "yellow"
                        compact: true
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 1

                        Text {
                            anchors.centerIn: parent
                            visible: !GCSState.loraRecentMessages || GCSState.loraRecentMessages.length === 0
                            text: GCSState.loraConnected ? "Waiting for messages…" : "Link offline"
                            color: Theme.textDisabled
                            font.pixelSize: 10
                            font.family: Theme.fontMono
                        }

                        ListView {
                            anchors.fill: parent
                            clip: true
                            visible: GCSState.loraRecentMessages && GCSState.loraRecentMessages.length > 0
                            model: GCSState.loraRecentMessages
                            spacing: 1
                            verticalLayoutDirection: ListView.BottomToTop
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 18
                                color: index % 2 === 0 ? "transparent" : Qt.rgba(1, 1, 1, 0.02)
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                    spacing: 6
                                    Text {
                                        text: modelData.dir === "TX" ? "▲" : "▼"
                                        color: modelData.dir === "TX" ? Theme.accentYellow : Theme.accentBlue
                                        font.pixelSize: 10; font.weight: Font.Bold
                                        Layout.preferredWidth: 10
                                    }
                                    Text {
                                        text: Qt.formatDateTime(new Date(modelData.t || 0), "hh:mm:ss")
                                        color: Theme.textDisabled
                                        font.pixelSize: 9; font.family: Theme.fontMono
                                        Layout.preferredWidth: 52
                                    }
                                    Text {
                                        text: modelData.text || ""
                                        color: Theme.textPrimary
                                        font.pixelSize: 9; font.family: Theme.fontMono
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    }
}
