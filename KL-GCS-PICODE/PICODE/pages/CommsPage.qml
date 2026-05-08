import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PICODE

Rectangle {
    id: root
    color: Theme.bgPrimary

    // ── LoRa RSSI history (in-memory rolling buffer) ──────────────────────────
    property var loraRssiHistory: []
    property var loraSnrHistory:  []

    Connections {
        target: GCSState
        function onLoraChanged() {
            var t = Date.now()
            var rss = loraRssiHistory.slice()
            rss.push({ t: t, v: GCSState.loraRssi })
            while (rss.length > 240) rss.shift()
            loraRssiHistory = rss

            var snr = loraSnrHistory.slice()
            snr.push({ t: t, v: GCSState.loraSnr })
            while (snr.length > 240) snr.shift()
            loraSnrHistory = snr
        }
    }

    function fixColor(fix) {
        if (fix === "3D" || fix === "RTK_FIXED" || fix === "RTK_FLOAT") return Theme.statusOk
        if (fix === "2D" || fix === "DGPS") return Theme.statusWarn
        return Theme.statusCrit
    }

    RowLayout {
        anchors.fill: parent
        spacing: 1

        // ════════════════════ LEFT: LoRa ════════════════════
        Flickable {
            Layout.fillHeight: true
            Layout.preferredWidth: 512
            contentWidth: width
            contentHeight: leftCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: leftCol
            width: parent.width
            spacing: 0

            // Header
            Item {
                Layout.fillWidth: true; height: 32
                Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 3; color: Theme.accentBlue }
                RowLayout {
                    anchors { fill: parent; leftMargin: 11; rightMargin: 10 }
                    Text {
                        text: "LORA LINK"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontPageTitle; font.weight: Font.SemiBold; font.letterSpacing: 0.8
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        width: dotConn.width + 14; height: 18; radius: 3
                        color: GCSState.loraConnected ? Theme.statusOkSoft : Theme.statusCritSoft
                        border.color: GCSState.loraConnected ? Theme.statusOk : Theme.statusCrit
                        border.width: 1
                        Text {
                            id: dotConn; anchors.centerIn: parent
                            text: GCSState.loraConnected ? "ONLINE" : "OFFLINE"
                            color: GCSState.loraConnected ? Theme.statusOk : Theme.statusCrit
                            font.pixelSize: 10; font.weight: Font.Bold; font.family: Theme.fontMono
                        }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

            // Top row: 3 stat cards (RSSI, SNR, Freq)
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                spacing: 1

                // RSSI big
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: Theme.bgSecondary; border.color: Theme.border; border.width: 1
                    ColumnLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 2
                        Text { text: "RSSI";  color: Theme.textDisabled; font.pixelSize: 10; font.weight: Font.SemiBold; font.letterSpacing: 0.6 }
                        Text {
                            text: GCSState.loraConnected ? GCSState.loraRssi : "--"
                            color: {
                                if (!GCSState.loraConnected) return Theme.textDisabled
                                if (GCSState.loraRssi > -90) return Theme.statusOk
                                if (GCSState.loraRssi > -110) return Theme.statusWarn
                                return Theme.statusCrit
                            }
                            font.pixelSize: Theme.fontValueLarge; font.weight: Font.Bold; font.family: Theme.fontMono
                        }
                        Text { text: "dBm"; color: Theme.textDisabled; font.pixelSize: 9; font.family: Theme.fontMono }
                    }
                }
                // SNR
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: Theme.bgSecondary; border.color: Theme.border; border.width: 1
                    ColumnLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 2
                        Text { text: "SNR"; color: Theme.textDisabled; font.pixelSize: 10; font.weight: Font.SemiBold; font.letterSpacing: 0.6 }
                        Text {
                            text: GCSState.loraConnected ? GCSState.loraSnr : "--"
                            color: GCSState.loraConnected ? Theme.accentBlue : Theme.textDisabled
                            font.pixelSize: Theme.fontValueLarge; font.weight: Font.Bold; font.family: Theme.fontMono
                        }
                        Text { text: "dB"; color: Theme.textDisabled; font.pixelSize: 9; font.family: Theme.fontMono }
                    }
                }
                // Freq + SF/BW chip
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: Theme.bgSecondary; border.color: Theme.border; border.width: 1
                    ColumnLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 2
                        Text { text: "FREQUENCY"; color: Theme.textDisabled; font.pixelSize: 10; font.weight: Font.SemiBold; font.letterSpacing: 0.6 }
                        Text {
                            text: GCSState.loraFrequencyMhz.toFixed(2)
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontValueMedium; font.weight: Font.Bold; font.family: Theme.fontMono
                        }
                        Text {
                            text: "MHz · SF" + GCSState.loraSpreadingFactor + " · " + GCSState.loraBandwidthKhz + "kHz · " + GCSState.loraTxPower + "dBm"
                            color: Theme.textDisabled; font.pixelSize: 9; font.family: Theme.fontMono
                        }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

            // Signal chart
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 168
                color: Theme.bgSecondary; border.color: Theme.border; border.width: 1
                ColumnLayout {
                    anchors { fill: parent; margins: 8 }
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true; spacing: 12
                        Text { text: "SIGNAL · 4 MIN"; color: Theme.textDisabled; font.pixelSize: 10; font.weight: Font.SemiBold; font.letterSpacing: 0.6; Layout.fillWidth: true }
                        RowLayout { spacing: 10
                            Rectangle { width: 8; height: 8; radius: 1; color: Theme.accentBlue }
                            Text { text: "RSSI"; color: Theme.textDisabled; font.pixelSize: 9; font.family: Theme.fontMono }
                            Rectangle { width: 8; height: 8; radius: 1; color: Theme.accentYellow }
                            Text { text: "SNR";  color: Theme.textDisabled; font.pixelSize: 9; font.family: Theme.fontMono }
                        }
                    }
                    TimeSeriesChart {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        windowMs: 4 * 60 * 1000
                        series: [
                            { color: Theme.accentBlue,   label: "RSSI", data: loraRssiHistory },
                            { color: Theme.accentYellow, label: "SNR",  data: loraSnrHistory }
                        ]
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

            // Throughput row
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                spacing: 1
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: Theme.bgSecondary; border.color: Theme.border; border.width: 1
                    RowLayout {
                        anchors { fill: parent; margins: 10 }
                        Text { text: "TX"; color: Theme.textDisabled; font.pixelSize: 10; font.weight: Font.SemiBold; Layout.preferredWidth: 24 }
                        Text { text: GCSState.loraTxPacketsPerSec + " p/s"; color: Theme.textPrimary; font.pixelSize: Theme.fontValueSmall; font.family: Theme.fontMono; font.weight: Font.SemiBold }
                        Item { Layout.fillWidth: true }
                        Text { text: (GCSState.loraTxBytes / 1024).toFixed(1) + " KB"; color: Theme.textDisabled; font.pixelSize: 10; font.family: Theme.fontMono }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: Theme.bgSecondary; border.color: Theme.border; border.width: 1
                    RowLayout {
                        anchors { fill: parent; margins: 10 }
                        Text { text: "RX"; color: Theme.textDisabled; font.pixelSize: 10; font.weight: Font.SemiBold; Layout.preferredWidth: 24 }
                        Text { text: GCSState.loraRxPacketsPerSec + " p/s"; color: Theme.textPrimary; font.pixelSize: Theme.fontValueSmall; font.family: Theme.fontMono; font.weight: Font.SemiBold }
                        Item { Layout.fillWidth: true }
                        Text { text: (GCSState.loraRxBytes / 1024).toFixed(1) + " KB"; color: Theme.textDisabled; font.pixelSize: 10; font.family: Theme.fontMono }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

            // Recent messages
            Item {
                Layout.fillWidth: true; height: 28
                Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 3; color: Theme.accentYellow }
                Text {
                    anchors { left: parent.left; leftMargin: 11; verticalCenter: parent.verticalCenter }
                    text: "RECENT MESSAGES"
                    color: Theme.textSecondary; font.pixelSize: Theme.fontSectionLabel; font.weight: Font.SemiBold; font.letterSpacing: 0.6
                }
                Text {
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: GCSState.loraRecentMessages.length + " msgs"
                    color: Theme.textDisabled; font.pixelSize: 10; font.family: Theme.fontMono
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }
            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(26, contentHeight)
                interactive: false
                clip: true
                model: GCSState.loraRecentMessages
                delegate: Rectangle {
                    width: ListView.view.width
                    height: 26
                    color: index % 2 === 0 ? Theme.bgPrimary : Theme.bgSecondary
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        spacing: 8
                        Text {
                            text: modelData.dir === "TX" ? "▲" : "▼"
                            color: modelData.dir === "TX" ? Theme.accentYellow : Theme.accentBlue
                            font.pixelSize: 11; font.weight: Font.Bold
                            Layout.preferredWidth: 14
                        }
                        Text {
                            text: Qt.formatDateTime(new Date(modelData.t || 0), "hh:mm:ss")
                            color: Theme.textDisabled; font.pixelSize: 10; font.family: Theme.fontMono
                            Layout.preferredWidth: 64
                        }
                        Text {
                            text: modelData.text || ""
                            color: Theme.textPrimary; font.pixelSize: 10; font.family: Theme.fontMono
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                    }
                }
            }
        }
        }

        Rectangle { width: 1; Layout.fillHeight: true; color: Theme.border }

        // ════════════════════ RIGHT: GPS module ════════════════════
        Flickable {
            Layout.fillHeight: true
            Layout.fillWidth: true
            contentWidth: width
            contentHeight: rightCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: rightCol
            width: parent.width
            spacing: 0

            // Header
            Item {
                Layout.fillWidth: true; height: 32
                Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 3; color: Theme.accentYellow }
                RowLayout {
                    anchors { fill: parent; leftMargin: 11; rightMargin: 10 }
                    Text {
                        text: "GPS MODULE"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontPageTitle; font.weight: Font.SemiBold; font.letterSpacing: 0.8
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        width: fixChip.width + 14; height: 18; radius: 3
                        color: Qt.rgba(fixColor(GCSState.modGpsFixType).r, fixColor(GCSState.modGpsFixType).g, fixColor(GCSState.modGpsFixType).b, 0.14)
                        border.color: fixColor(GCSState.modGpsFixType); border.width: 1
                        Text {
                            id: fixChip; anchors.centerIn: parent
                            text: GCSState.modGpsConnected ? GCSState.modGpsFixType : "OFFLINE"
                            color: fixColor(GCSState.modGpsFixType)
                            font.pixelSize: 10; font.weight: Font.Bold; font.family: Theme.fontMono
                        }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

            // Position grid
            GridLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                columns: 3; rowSpacing: 1; columnSpacing: 1

                // LAT
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: Theme.bgSecondary; border.color: Theme.border; border.width: 1
                    ColumnLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 2
                        Text { text: "LATITUDE";  color: Theme.textDisabled; font.pixelSize: 10; font.weight: Font.SemiBold; font.letterSpacing: 0.6 }
                        Text {
                            text: GCSState.modGpsConnected ? GCSState.modGpsLat.toFixed(6) : "--"
                            color: Theme.textPrimary
                            font.pixelSize: 18; font.weight: Font.Bold; font.family: Theme.fontMono
                        }
                        Text { text: "deg"; color: Theme.textDisabled; font.pixelSize: 9; font.family: Theme.fontMono }
                    }
                }
                // LON
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: Theme.bgSecondary; border.color: Theme.border; border.width: 1
                    ColumnLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 2
                        Text { text: "LONGITUDE"; color: Theme.textDisabled; font.pixelSize: 10; font.weight: Font.SemiBold; font.letterSpacing: 0.6 }
                        Text {
                            text: GCSState.modGpsConnected ? GCSState.modGpsLon.toFixed(6) : "--"
                            color: Theme.textPrimary
                            font.pixelSize: 18; font.weight: Font.Bold; font.family: Theme.fontMono
                        }
                        Text { text: "deg"; color: Theme.textDisabled; font.pixelSize: 9; font.family: Theme.fontMono }
                    }
                }
                // ALT
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: Theme.bgSecondary; border.color: Theme.border; border.width: 1
                    ColumnLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 2
                        Text { text: "ALTITUDE";  color: Theme.textDisabled; font.pixelSize: 10; font.weight: Font.SemiBold; font.letterSpacing: 0.6 }
                        Text {
                            text: GCSState.modGpsConnected ? GCSState.modGpsAlt.toFixed(1) : "--"
                            color: Theme.accentBlue
                            font.pixelSize: 24; font.weight: Font.Bold; font.family: Theme.fontMono
                        }
                        Text { text: "m MSL"; color: Theme.textDisabled; font.pixelSize: 9; font.family: Theme.fontMono }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

            // Sats / HDOP / Speed / Heading row
            GridLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                columns: 4; rowSpacing: 1; columnSpacing: 1

                Repeater {
                    model: [
                        { lbl: "SATS",    val: GCSState.modGpsConnected ? (GCSState.modGpsSats + "/" + GCSState.modGpsSatsTracked) : "--", unit: "used/seen", accent: Theme.accentYellow },
                        { lbl: "HDOP",    val: GCSState.modGpsConnected ? GCSState.modGpsHdop.toFixed(2) : "--", unit: "lower=better", accent: Theme.accentBlue },
                        { lbl: "SPEED",   val: GCSState.modGpsConnected ? GCSState.modGpsSpeed.toFixed(1) : "--", unit: "m/s", accent: Theme.accentBlue },
                        { lbl: "HEADING", val: GCSState.modGpsConnected ? GCSState.modGpsHeading.toFixed(0) + "°" : "--", unit: "true", accent: Theme.accentBlue }
                    ]
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        color: Theme.bgSecondary; border.color: Theme.border; border.width: 1
                        ColumnLayout {
                            anchors { fill: parent; margins: 8 }
                            spacing: 1
                            Text { text: modelData.lbl; color: Theme.textDisabled; font.pixelSize: 9; font.weight: Font.SemiBold; font.letterSpacing: 0.6 }
                            Text { text: modelData.val; color: modelData.accent; font.pixelSize: 18; font.weight: Font.Bold; font.family: Theme.fontMono }
                            Text { text: modelData.unit; color: Theme.textDisabled; font.pixelSize: 9; font.family: Theme.fontMono }
                        }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

            // Constellation header
            Item {
                Layout.fillWidth: true; height: 28
                Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 3; color: Theme.accentBlue }
                Text {
                    anchors { left: parent.left; leftMargin: 11; verticalCenter: parent.verticalCenter }
                    text: "CONSTELLATION"
                    color: Theme.textSecondary; font.pixelSize: Theme.fontSectionLabel; font.weight: Font.SemiBold; font.letterSpacing: 0.6
                }
                Text {
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: (GCSState.modGpsConstellation.length || 0) + " sats tracked"
                    color: Theme.textDisabled; font.pixelSize: 10; font.family: Theme.fontMono
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

            // SNR bar chart
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 220
                color: Theme.bgSecondary; border.color: Theme.border; border.width: 1

                Item {
                    anchors.fill: parent
                    anchors.margins: 8

                    Text {
                        anchors.centerIn: parent
                        visible: !GCSState.modGpsConnected || (GCSState.modGpsConstellation.length || 0) === 0
                        text: GCSState.modGpsConnected ? "Waiting for satellite data…" : "GPS module not connected"
                        color: Theme.textDisabled; font.pixelSize: 11
                    }

                    ListView {
                        anchors.fill: parent
                        orientation: ListView.Horizontal
                        spacing: 3
                        clip: true
                        visible: GCSState.modGpsConnected && (GCSState.modGpsConstellation.length || 0) > 0
                        model: GCSState.modGpsConstellation
                        delegate: Item {
                            width: 26
                            height: ListView.view.height
                            // Bar
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 14
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 18
                                height: Math.max(2, ((modelData.snr || 0) / 50) * (parent.height - 28))
                                radius: 2
                                color: (modelData.used || false)
                                       ? ((modelData.snr || 0) >= 30 ? Theme.statusOk : Theme.statusWarn)
                                       : Theme.textDisabled
                                opacity: (modelData.used || false) ? 1.0 : 0.5
                            }
                            // PRN
                            Text {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: (modelData.prn || "?")
                                color: Theme.textDisabled
                                font.pixelSize: 9; font.family: Theme.fontMono
                            }
                        }
                    }
                }
            }
        }
        }
    }
}
