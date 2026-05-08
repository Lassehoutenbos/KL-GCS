import QtQuick
import QtQuick.Layouts
import PICODE

Item {
    id: caseView
    implicitHeight: 520
    signal sensorDetailsRequested(var sensor)
    property int selectedSensor: -1
    property var minTemps: []
    property var maxTemps: []

    readonly property real svgAspect: 1200 / 1600  // 0.75 (portrait)

    function valueForSensorKey(sensorKey) {
        if (sensorKey === "tempCpuPi") return GCSState.tempCpuPi
        if (sensorKey === "tempCaseA") return GCSState.tempCaseA
        if (sensorKey === "tempCaseB") return GCSState.tempCaseB
        if (sensorKey === "tempCaseC") return GCSState.tempCaseC
        if (sensorKey === "tempCaseD") return GCSState.tempCaseD
        if (sensorKey === "batteryVoltage") return GCSState.batteryVoltage
        if (sensorKey === "extVoltage") return GCSState.extVoltage
        if (sensorKey === "alsLux") return GCSState.alsLux
        if (sensorKey === "brightnessScreenL") return GCSState.brightnessScreenL
        if (sensorKey === "brightnessScreenR") return GCSState.brightnessScreenR
        if (sensorKey === "brightnessLed") return GCSState.brightnessLed
        if (sensorKey === "brightnessTft") return GCSState.brightnessTft
        if (sensorKey === "brightnessBtnLeds") return GCSState.brightnessBtnLeds
        if (sensorKey === "mavlinkConnected") return GCSState.mavlinkConnected
        if (sensorKey === "picoConnected") return GCSState.picoConnected
        if (sensorKey === "droneArmed") return GCSState.droneArmed
        if (sensorKey === "keyUnlocked") return GCSState.keyUnlocked
        if (sensorKey === "worklightOn") return GCSState.worklightOn
        if (sensorKey === "anyWarningActive") return GCSState.anyWarningActive
        if (sensorKey === "warnTemp") return GCSState.warnTemp
        if (sensorKey === "warnSignal") return GCSState.warnSignal
        if (sensorKey === "warnDrone") return GCSState.warnDrone
        if (sensorKey === "warnGps") return GCSState.warnGps
        if (sensorKey === "warnLink") return GCSState.warnLink
        if (sensorKey === "warnNetwork") return GCSState.warnNetwork
        if (sensorKey === "peripheralCount") return GCSState.peripherals.length
        return NaN
    }

    function sensorValid(type, sensorKey, value) {
        if (type === "bool") return value !== undefined && value !== null
        if (type === "text") return value !== undefined && value !== null && ("" + value).length > 0
        if (sensorKey === "tempCpuPi") return !isNaN(value)
        if (type === "temp") return !isNaN(value) && value > -274
        if (type === "number" || type === "voltage" || type === "percent") return !isNaN(value)
        return value !== undefined && value !== null && !isNaN(value)
    }

    readonly property var sensors: {
        var cfg = GCSState.caseTwinHotspots
        var out = []
        for (var i = 0; i < cfg.length; i++) {
            var row = cfg[i]
            var sensorKey = row.sensorKey !== undefined ? row.sensorKey : row.sensor_key
            var t = valueForSensorKey(sensorKey)
            var metricType = row.metricType !== undefined ? row.metricType : (row.type !== undefined ? row.type : "temp")
            var okMax = row.okMax !== undefined ? row.okMax : (row.ok_max !== undefined ? row.ok_max : 60)
            var warnMax = row.warnMax !== undefined ? row.warnMax : (row.warn_max !== undefined ? row.warn_max : 80)
            var warnMin = row.warnMin !== undefined ? row.warnMin : row.warn_min
            var critMin = row.critMin !== undefined ? row.critMin : row.crit_min
            var decimals = row.decimals !== undefined ? row.decimals : (metricType === "temp" || metricType === "voltage" ? 1 : 0)
            var unit = row.unit !== undefined ? row.unit : (metricType === "temp" ? "°C" : (metricType === "voltage" ? "V" : ""))
            out.push({
                id: row.id,
                label: row.label,
                sensorKey: sensorKey,
                value: t,
                valid: sensorValid(metricType, sensorKey, t),
                cx: row.xNorm !== undefined ? row.xNorm : row.x_norm,
                cy: row.yNorm !== undefined ? row.yNorm : row.y_norm,
                type: metricType,
                unit: unit,
                decimals: decimals,
                okMax: okMax,
                warnMax: warnMax,
                warnMin: warnMin,
                critMin: critMin,
                trueLabel: row.trueLabel !== undefined ? row.trueLabel : row.true_label,
                falseLabel: row.falseLabel !== undefined ? row.falseLabel : row.false_label,
                invert: row.invert === true
            })
        }
        return out
    }

    function resetMinMaxBuffers() {
        var mins = []
        var maxs = []
        for (var i = 0; i < sensors.length; i++) {
            mins.push(9999)
            maxs.push(-9999)
        }
        minTemps = mins
        maxTemps = maxs
    }

    function sensorLevel(sensor) {
        if (!sensor.valid) return -1
        var value = sensor.value

        if (sensor.type === "bool") {
            var active = !!value
            if (sensor.invert === true) active = !active
            return active ? 0 : 2
        }

        if (sensor.critMin !== undefined && value < sensor.critMin) return 2
        if (sensor.warnMin !== undefined && value < sensor.warnMin) return 1
        if (sensor.warnMax !== undefined && value >= sensor.warnMax) return 2
        if (sensor.okMax !== undefined && value >= sensor.okMax) return 1
        return 0
    }

    function sensorDisplayValue(sensor) {
        if (!sensor.valid) return "—"

        if (sensor.type === "bool") {
            var active = !!sensor.value
            if (sensor.invert === true) active = !active
            return active ? (sensor.trueLabel || "ON") : (sensor.falseLabel || "OFF")
        }

        if (typeof sensor.value === "number")
            return sensor.value.toFixed(sensor.decimals !== undefined ? sensor.decimals : 0) + (sensor.unit || "")

        return "" + sensor.value
    }

    function levelColor(level) {
        if (level === 2) return Theme.statusCrit
        if (level === 1) return Theme.statusWarn
        if (level === 0) return Theme.statusOk
        return Theme.textDisabled
    }

    Connections {
        target: GCSState
        function onSensorChanged() {
            var mins = minTemps.slice()
            var maxs = maxTemps.slice()
            while (mins.length < sensors.length) mins.push(9999)
            while (maxs.length < sensors.length) maxs.push(-9999)

            for (var i = 0; i < sensors.length; i++) {
                var s = sensors[i]
                if (s.valid && typeof s.value === "number") {
                    if (s.value < mins[i]) mins[i] = s.value
                    if (s.value > maxs[i]) maxs[i] = s.value
                }
            }
            minTemps = mins
            maxTemps = maxs
        }

        function onCaseTwinConfigChanged() {
            resetMinMaxBuffers()
            if (selectedSensor >= sensors.length) selectedSensor = -1
        }
    }

    function getMinMax(index) {
        var minV = index < minTemps.length ? minTemps[index] : 9999
        var maxV = index < maxTemps.length ? maxTemps[index] : -9999
        return { min: minV, max: maxV }
    }

    Component.onCompleted: resetMinMaxBuffers()

    // Aspect-fit container — child positions are relative to the painted SVG box,
    // so hotspots track the image even when the container is wider/taller than the fit.
    Item {
        id: stage
        anchors.centerIn: parent
        readonly property real fitH: parent.height
        readonly property real fitW: fitH * caseView.svgAspect
        width: Math.min(fitW, parent.width)
        height: width / caseView.svgAspect

        Image {
            id: caseImage
            anchors.fill: parent
            source: "qrc:/qt/qml/PICODE/assets/svg/case_twin.svg"
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 2400
            smooth: true
            asynchronous: true
        }

        Repeater {
            model: sensors

            Item {
                required property int index
                required property var modelData
                x: modelData.cx * stage.width - width / 2
                y: modelData.cy * stage.height - height / 2
                width: 16; height: 16
                z: 5

                readonly property int lvl: sensorLevel(modelData)
                readonly property color col: levelColor(lvl)

                Rectangle {
                    visible: parent.lvl >= 1
                    anchors.centerIn: parent
                    width: 28; height: 28; radius: 14
                    color: "transparent"
                    border.color: parent.col
                    border.width: 1.5
                    SequentialAnimation on opacity {
                        running: parent.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.7; to: 0.1; duration: 800 }
                        NumberAnimation { from: 0.1; to: 0.7; duration: 800 }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 18; height: 18; radius: 9
                    color: Qt.rgba(parent.col.r, parent.col.g, parent.col.b, 0.22)
                    border.color: parent.col
                    border.width: 1
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 8; height: 8; radius: 4
                    color: parent.col
                }

                Rectangle {
                    visible: caseView.selectedSensor === parent.index
                    anchors.centerIn: parent
                    width: 32; height: 32; radius: 16
                    color: "transparent"
                    border.color: Theme.accentYellow
                    border.width: 2
                }

                MouseArea {
                    anchors.centerIn: parent
                    width: 36; height: 36
                    onClicked: {
                        if (caseView.selectedSensor === parent.index) caseView.selectedSensor = -1
                        else caseView.selectedSensor = parent.index
                    }
                }
            }
        }

        Repeater {
            model: sensors

            Item {
                required property int index
                required property var modelData
                x: modelData.cx * stage.width + 10
                y: modelData.cy * stage.height - 11
                width: Math.max(valueText.implicitWidth, nameText.implicitWidth) + 8
                height: valueText.implicitHeight + nameText.implicitHeight + 2
                z: 4

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(Theme.bgPrimary.r, Theme.bgPrimary.g, Theme.bgPrimary.b, 0.72)
                    radius: 2
                }

                Text {
                    id: valueText
                    x: 4; y: 0
                    text: sensorDisplayValue(modelData)
                    color: levelColor(sensorLevel(modelData))
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.family: "monospace"
                }

                Text {
                    id: nameText
                    x: 4; y: valueText.implicitHeight
                    text: modelData.label
                    color: Theme.textDisabled
                    font.pixelSize: 8
                    font.weight: Font.Medium
                    font.letterSpacing: 0.3
                }
            }
        }
    }

    Rectangle {
        id: detailOverlay
        visible: selectedSensor >= 0 && selectedSensor < sensors.length
        width: 200; height: 120; radius: 6
        color: Theme.bgElevated
        border.color: Theme.accentYellow
        border.width: 1
        z: 30

        x: visible ? Math.min(Math.max(stage.x + sensors[selectedSensor].cx * stage.width - 100, 8),
                              caseView.width - 208) : 0
        y: visible ? Math.max(stage.y + sensors[selectedSensor].cy * stage.height - 130, 4) : 0

        Behavior on x { NumberAnimation { duration: 100 } }
        Behavior on y { NumberAnimation { duration: 100 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            Text {
                text: detailOverlay.visible ? sensors[selectedSensor].label : ""
                color: Theme.accentYellow
                font.pixelSize: Theme.fontSectionLabel
                font.weight: Font.SemiBold
            }

            Text {
                text: detailOverlay.visible && sensors[selectedSensor].valid
                      ? sensorDisplayValue(sensors[selectedSensor])
                      : "—"
                color: Theme.textPrimary
                font.pixelSize: 22
                font.weight: Font.Bold
                font.family: "monospace"
            }

            RowLayout {
                spacing: 12
                Text {
                    property var mm: detailOverlay.visible && selectedSensor >= 0 ? getMinMax(selectedSensor) : { min: 0, max: 0 }
                    property int dec: detailOverlay.visible && selectedSensor >= 0 && sensors[selectedSensor] ? (sensors[selectedSensor].decimals !== undefined ? sensors[selectedSensor].decimals : 0) : 0
                    property string unitText: detailOverlay.visible && selectedSensor >= 0 && sensors[selectedSensor] ? (sensors[selectedSensor].unit || "") : ""
                    text: mm.min < 9999 ? ("MIN " + mm.min.toFixed(dec) + unitText) : "MIN —"
                    color: Theme.textSecondary
                    font.pixelSize: 9
                    font.family: "monospace"
                }
                Text {
                    property var mm: detailOverlay.visible && selectedSensor >= 0 ? getMinMax(selectedSensor) : { min: 0, max: 0 }
                    property int dec: detailOverlay.visible && selectedSensor >= 0 && sensors[selectedSensor] ? (sensors[selectedSensor].decimals !== undefined ? sensors[selectedSensor].decimals : 0) : 0
                    property string unitText: detailOverlay.visible && selectedSensor >= 0 && sensors[selectedSensor] ? (sensors[selectedSensor].unit || "") : ""
                    text: mm.max > -9999 ? ("MAX " + mm.max.toFixed(dec) + unitText) : "MAX —"
                    color: Theme.textSecondary
                    font.pixelSize: 9
                    font.family: "monospace"
                }
                Text {
                    property int lvl: detailOverlay.visible && selectedSensor >= 0 ? sensorLevel(sensors[selectedSensor]) : -1
                    text: lvl === 0 ? "OK" : (lvl === 1 ? "WARN" : (lvl === 2 ? "CRIT" : "—"))
                    color: levelColor(lvl)
                    font.pixelSize: 9
                    font.weight: Font.Bold
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                radius: 4
                color: Theme.bgSecondary
                border.color: Theme.border
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "MEER INFO"
                    color: Theme.textPrimary
                    font.pixelSize: 10
                    font.weight: Font.SemiBold
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (detailOverlay.visible && selectedSensor >= 0 && selectedSensor < sensors.length)
                            caseView.sensorDetailsRequested(sensors[selectedSensor])
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: { if (selectedSensor >= 0) selectedSensor = -1 }
    }
}
