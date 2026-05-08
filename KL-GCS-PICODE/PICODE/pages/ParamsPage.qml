import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PICODE

Rectangle {
    id: root
    color: Theme.bgPrimary

    property string searchText: ""
    property string editParamName: ""
    property double editParamValue: 0.0
    property string editInputText: ""

    // ── Per-param value history (in-memory, last N samples) ──────────────────
    // Map: name -> array of {t, v}
    property var paramHistory: ({})
    readonly property int historyLimit: 80

    Connections {
        target: GCSState
        function onParamsChanged() {
            var t = Date.now()
            var h = paramHistory
            var changed = false
            for (var i = 0; i < GCSState.params.length; i++) {
                var p = GCSState.params[i]
                if (!p || !p.name) continue
                var v = parseFloat(p.value)
                if (isNaN(v)) continue
                var arr = h[p.name] ? h[p.name].slice() : []
                var last = arr.length > 0 ? arr[arr.length - 1] : null
                if (!last || Math.abs(last.v - v) > 1e-9 || (t - last.t) > 30000) {
                    arr.push({ t: t, v: v })
                    if (arr.length > historyLimit) arr.shift()
                    h[p.name] = arr
                    changed = true
                }
            }
            if (changed) paramHistory = h
        }
    }

    // ── Group definitions ────────────────────────────────────────────────────
    readonly property var groupDefs: [
        { label: "ATTITUDE / TUNING",  prefixes: ["ATC_", "TUNE"],     accent: Theme.accentYellow },
        { label: "MOTORS",             prefixes: ["MOT_"],             accent: Theme.accentYellow },
        { label: "BATTERY",            prefixes: ["BATT"],             accent: Theme.accentBlue   },
        { label: "GPS / COMPASS",      prefixes: ["GPS_", "COMPASS"],  accent: Theme.accentBlue   },
        { label: "RADIO / RC",         prefixes: ["RC_", "SERIAL"],    accent: Theme.accentBlue   },
        { label: "FAILSAFE",           prefixes: ["FS_", "FENCE"],     accent: Theme.statusWarn   },
        { label: "OTHER",              prefixes: [],                   accent: Theme.textDisabled }
    ]

    property var collapsedGroups: ({})

    function paramMatchesGroup(name, group) {
        if (group.prefixes.length === 0) {
            // OTHER: anything not matched by an earlier group
            for (var g = 0; g < groupDefs.length - 1; g++) {
                var gd = groupDefs[g]
                for (var i = 0; i < gd.prefixes.length; i++) {
                    if (name.indexOf(gd.prefixes[i]) === 0) return false
                }
            }
            return true
        }
        for (var j = 0; j < group.prefixes.length; j++) {
            if (name.indexOf(group.prefixes[j]) === 0) return true
        }
        return false
    }

    function paramsInGroup(group) {
        var out = []
        var s = searchText.toUpperCase()
        for (var i = 0; i < GCSState.params.length; i++) {
            var p = GCSState.params[i]
            var n = p.name ? p.name.toString() : ""
            if (!paramMatchesGroup(n, group)) continue
            if (s && n.toUpperCase().indexOf(s) < 0) continue
            out.push(p)
        }
        return out
    }

    function dirtyCount() {
        var n = 0
        for (var i = 0; i < GCSState.params.length; i++)
            if (GCSState.params[i].dirty) n++
        return n
    }

    function fmtValue(v) {
        if (v === undefined || v === null) return "--"
        var f = parseFloat(v)
        if (isNaN(f)) return v.toString()
        if (Math.abs(f) >= 1000) return f.toFixed(1)
        if (Math.abs(f) >= 1)    return f.toFixed(3)
        return f.toFixed(4)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ══════════════ TOP TOOLBAR ══════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: Theme.bgSecondary
            border.color: Theme.border
            border.width: 1

            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 10

                Text {
                    text: "PARAMS"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontPageTitle; font.weight: Font.Bold; font.letterSpacing: 1.2
                }

                // Stats chip
                Rectangle {
                    width: countLbl.width + 16; height: 26; radius: 3
                    color: Theme.bgElevated; border.color: Theme.border; border.width: 1
                    Text {
                        id: countLbl
                        anchors.centerIn: parent
                        text: GCSState.params.length + " params · " + dirtyCount() + " dirty"
                        color: dirtyCount() > 0 ? Theme.statusWarn : Theme.textDisabled
                        font.pixelSize: 10; font.family: Theme.fontMono; font.weight: Font.SemiBold
                    }
                }

                // Search
                Rectangle {
                    Layout.fillWidth: true
                    height: 38
                    radius: 4
                    color: Theme.bgElevated; border.color: searchInput.activeFocus ? Theme.accentBlue : Theme.border
                    border.width: 1
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        spacing: 8
                        Text { text: "⌕"; color: Theme.textDisabled; font.pixelSize: 14 }
                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            text: searchText
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSectionLabel; font.family: Theme.fontMono
                            onTextChanged: searchText = text
                            clip: true
                        }
                        Text {
                            visible: searchText.length > 0
                            text: "✕"
                            color: Theme.textDisabled; font.pixelSize: 12
                            MouseArea { anchors.fill: parent; onClicked: { searchText = ""; searchInput.text = "" } }
                        }
                    }
                }

                BigButton {
                    label: "REFRESH"
                    Layout.preferredWidth: 130; Layout.preferredHeight: 38
                    onClicked: GCSState.sendParamRefresh()
                }
                BigButton {
                    label: "WRITE"
                    active: dirtyCount() > 0
                    Layout.preferredWidth: 130; Layout.preferredHeight: 38
                    onClicked: { if (dirtyCount() > 0) writeConfirm.open() }
                }
            }
        }

        // ══════════════ EMPTY STATE ══════════════
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: GCSState.params.length === 0
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                Text {
                    text: "No parameters loaded"
                    color: Theme.textDisabled
                    font.pixelSize: Theme.fontPageTitle; font.weight: Font.SemiBold; font.letterSpacing: 0.8
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: "Press REFRESH to download from drone."
                    color: Theme.textDisabled
                    font.pixelSize: Theme.fontSectionLabel
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // ══════════════ GROUPED LIST ══════════════
        ListView {
            id: groupList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: GCSState.params.length > 0
            clip: true
            model: groupDefs
            spacing: 0

            delegate: Column {
                width: groupList.width

                property var groupItems: paramsInGroup(modelData)
                property bool collapsed: collapsedGroups[modelData.label] === true
                property bool hasMatches: groupItems.length > 0

                visible: hasMatches

                // Group header
                Rectangle {
                    width: parent.width
                    height: 34
                    color: Theme.bgSecondary
                    border.color: Theme.border
                    border.width: 1

                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 3
                        color: modelData.accent
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 11; rightMargin: 10 }
                        spacing: 8

                        Text {
                            text: parent.parent.collapsed ? "▶" : "▼"
                            color: modelData.accent
                            font.pixelSize: 10; font.weight: Font.Bold
                            Layout.preferredWidth: 12
                        }

                        Text {
                            text: modelData.label
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSectionLabel
                            font.weight: Font.SemiBold
                            font.letterSpacing: 0.6
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: gcLbl.width + 12; height: 18; radius: 3
                            color: Theme.bgElevated; border.color: Theme.border; border.width: 1
                            Text {
                                id: gcLbl
                                anchors.centerIn: parent
                                text: groupItems.length + (groupItems.length === 1 ? " param" : " params")
                                color: Theme.textDisabled
                                font.pixelSize: 9; font.family: Theme.fontMono
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            var c = collapsedGroups
                            c[modelData.label] = !c[modelData.label]
                            collapsedGroups = ({})
                            for (var k in c) collapsedGroups[k] = c[k]
                        }
                    }
                }

                // Group rows
                Repeater {
                    model: parent.collapsed ? [] : parent.groupItems
                    delegate: Rectangle {
                        width: groupList.width
                        height: 48
                        color: index % 2 === 0 ? Theme.bgPrimary : Theme.bgSecondary

                        // Dirty edge bar
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: 3
                            color: modelData.dirty ? Theme.statusWarn : "transparent"
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                            spacing: 8

                            // Name
                            Text {
                                text: modelData.name
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSectionLabel; font.family: Theme.fontMono
                                font.weight: Font.Medium
                                Layout.preferredWidth: 200
                                elide: Text.ElideRight
                            }

                            // Sparkline
                            TimeSeriesChart {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                sparkline: true
                                series: [{
                                    color: modelData.dirty ? Theme.statusWarn : Theme.accentBlue,
                                    data: paramHistory[modelData.name] || []
                                }]
                            }

                            // Value
                            Text {
                                text: fmtValue(modelData.value)
                                color: modelData.dirty ? Theme.statusWarn : Theme.textPrimary
                                font.pixelSize: Theme.fontValueSmall; font.weight: Font.SemiBold
                                font.family: Theme.fontMono
                                Layout.preferredWidth: 96
                                horizontalAlignment: Text.AlignRight
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        editParamName  = modelData.name
                                        editParamValue = parseFloat(modelData.value) || 0.0
                                        editInputText  = editParamValue.toFixed(4)
                                        paramEditOverlay.visible = true
                                    }
                                }
                            }

                            // ± buttons
                            Rectangle {
                                width: 36; height: 36; radius: 4
                                color: decMa.pressed ? Theme.bgElevated : "transparent"
                                border.color: Theme.border; border.width: 1
                                Text { anchors.centerIn: parent; text: "−"; color: Theme.textSecondary; font.pixelSize: 16; font.weight: Font.Bold }
                                MouseArea {
                                    id: decMa; anchors.fill: parent
                                    onClicked: {
                                        var step = Math.abs(parseFloat(modelData.value)) >= 1 ? 0.1 : 0.01
                                        var newV = parseFloat(modelData.value) - step
                                        GCSState.setParamDirty(modelData.name, Math.round(newV * 10000) / 10000)
                                    }
                                }
                            }
                            Rectangle {
                                width: 36; height: 36; radius: 4
                                color: incMa.pressed ? Theme.bgElevated : "transparent"
                                border.color: Theme.border; border.width: 1
                                Text { anchors.centerIn: parent; text: "+"; color: Theme.accentYellow; font.pixelSize: 16; font.weight: Font.Bold }
                                MouseArea {
                                    id: incMa; anchors.fill: parent
                                    onClicked: {
                                        var step = Math.abs(parseFloat(modelData.value)) >= 1 ? 0.1 : 0.01
                                        var newV = parseFloat(modelData.value) + step
                                        GCSState.setParamDirty(modelData.name, Math.round(newV * 10000) / 10000)
                                    }
                                }
                            }
                        }

                        // Bottom hairline
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 1
                            color: Theme.border
                            opacity: 0.4
                        }
                    }
                }
            }
        }
    }

    // ══════════════ EDIT OVERLAY ══════════════
    Rectangle {
        id: paramEditOverlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: false
        z: 50

        MouseArea { anchors.fill: parent; onClicked: paramEditOverlay.visible = false }

        Rectangle {
            anchors.centerIn: parent
            width: 480; height: 340
            color: Theme.bgSecondary; border.color: Theme.border; border.width: 1; radius: 8

            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 10

                Text { text: editParamName; color: Theme.textPrimary; font.pixelSize: 16; font.weight: Font.SemiBold; font.family: Theme.fontMono }
                Text { text: "Current:  " + editParamValue.toFixed(4); color: Theme.textSecondary; font.pixelSize: Theme.fontSectionLabel }

                // Mini history graph
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 80
                    color: Theme.bgElevated; border.color: Theme.border; border.width: 1; radius: 4
                    TimeSeriesChart {
                        anchors { fill: parent; margins: 4 }
                        sparkline: true
                        series: [{
                            color: Theme.accentBlue,
                            data: paramHistory[editParamName] || []
                        }]
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !(paramHistory[editParamName] && paramHistory[editParamName].length > 1)
                        text: "no history yet"
                        color: Theme.textDisabled; font.pixelSize: 10
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                Rectangle {
                    Layout.fillWidth: true; height: 52; radius: 4
                    color: Theme.bgElevated; border.color: Theme.accentBlue; border.width: 1
                    TextInput {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: editInputText
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontValueSmall; font.weight: Font.SemiBold; font.family: Theme.fontMono
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        validator: DoubleValidator { }
                        onTextChanged: editInputText = text
                        clip: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 8

                    BigButton {
                        label: "CANCEL"
                        Layout.fillWidth: true; Layout.preferredHeight: 56
                        onClicked: paramEditOverlay.visible = false
                    }

                    BigButton {
                        label: "SET"
                        active: true
                        Layout.fillWidth: true; Layout.preferredHeight: 56
                        onClicked: {
                            var v = parseFloat(editInputText)
                            if (!isNaN(v)) GCSState.setParamDirty(editParamName, v)
                            paramEditOverlay.visible = false
                        }
                    }
                }
            }
        }
    }

    ConfirmOverlay {
        id: writeConfirm
        title: "WRITE PARAMS TO DRONE"
        body: dirtyCount() + " changed parameter(s) will be sent to the drone. Ensure the drone is disarmed before writing critical params."
        confirmLabel: "WRITE"
        destructive: false
        onConfirmed: {
            for (var i = 0; i < GCSState.params.length; i++) {
                var p = GCSState.params[i]
                if (p.dirty) GCSState.sendParamWrite(p.name, p.value)
            }
        }
    }
}
