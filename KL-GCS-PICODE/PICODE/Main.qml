import QtQuick
import PICODE

Window {
    id: root
    property int  screenIndex: 0
    property string initialPage: "dash"
    property string currentPage: initialPage

    screen: Qt.application.screens[screenIndex] ?? Qt.application.screens[0]
    x: screen.virtualX
    y: screen.virtualY
    width:  1024
    height: 600
    visible: true
    color: Theme.bgPrimary

    Rectangle {
        anchors.fill: parent
        color: Theme.bgPrimary
    }

    StatusBar {
        id: statusBar
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: Theme.statusBarH
        onQuickPanelToggled: quickPanel.toggle()
    }

    Loader {
        id: pageLoader
        anchors {
            top: statusBar.bottom
            bottom: navBar.top
            left: parent.left
            right: parent.right
        }
        source: {
            switch (root.currentPage) {
                case "dash":    return "pages/DashPage.qml"
                case "drone":   return "pages/DronePage.qml"
                case "camera":  return "pages/CameraPage.qml"
                case "map":     return "pages/MapPage.qml"
                case "mission": return "pages/MissionPage.qml"
                case "params":  return "pages/ParamsPage.qml"
                case "payload": return "pages/PayloadPage.qml"
                case "periph":  return "pages/PeriphPage.qml"
                case "comms":   return "pages/CommsPage.qml"
                case "case":    return "pages/CasePage.qml"
                default:        return "pages/DashPage.qml"
            }
        }
    }

    NavBar {
        id: navBar
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        height: Theme.navBarH
        currentPage: root.currentPage
        onTabClicked: (pageKey) => root.currentPage = pageKey
    }

    QuickPanel {
        id: quickPanel
        anchors.fill: parent
        visible: false
        z: 10
        onBrandLogoRequested: {
            if (visible) toggle()
            root.showBootSplash()
        }
    }

    function showBootSplash() {
        splash.opacity = 1.0
        splash.visible = true
        logoBlock.opacity = 0
        logoBlock.scale = 1.0
        checkList.opacity = 0
        footerBlock.opacity = 0
        backdrop.opacity = 0
        progressFill.width = 0
        splashSeq.restart()
    }

    function dismissSplash() {
        splashSeq.stop()
        splashDismissAnim.restart()
    }

    NumberAnimation {
        id: splashDismissAnim
        target: splash
        property: "opacity"
        to: 0
        duration: 240
        easing.type: Easing.InCubic
        onStopped: splash.visible = false
    }

    ConfirmOverlay {
        id: hwArmConfirm
        title: "ARM DRONE"
        body: "Physical ARM switch activated. Arming will enable motors. Ensure the area is clear."
        confirmLabel: "ARM"
        destructive: true
        onConfirmed: GCSState.sendArmDisarm(true)
    }

    Connections {
        target: GCSState
        function onArmSwitchToggled(on) {
            if (on && GCSState.keyUnlocked && !GCSState.droneArmed)
                hwArmConfirm.open()
        }
        function onKeyStateChanged() {
            if (!GCSState.keyUnlocked && !splash.visible)
                root.showBootSplash()
        }
    }

    // ── BOOT SPLASH ─────────────────────────────────────────────────────────
    Rectangle {
        id: splash
        anchors.fill: parent
        z: 100
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Theme.bgGradTop }
            GradientStop { position: 1.0; color: Theme.bgGradBottom }
        }
        opacity: 1.0

        readonly property int peripheralCount: {
            var n = 0
            var arr = GCSState.peripherals
            for (var i = 0; i < arr.length; ++i)
                if (arr[i] && arr[i].online) ++n
            return n
        }

        // Technical backdrop — vertical grid + slow scan line
        Item {
            id: backdrop
            anchors.fill: parent
            opacity: 0.0

            Row {
                anchors.fill: parent
                Repeater {
                    model: 16
                    Item {
                        width: backdrop.width / 16
                        height: backdrop.height
                        Rectangle {
                            anchors.right: parent.right
                            width: 1
                            height: parent.height
                            color: Theme.borderSoft
                        }
                    }
                }
            }

            // Soft radial vignette to keep edges quiet
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.0) }
                    GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.0) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.35) }
                }
            }

            // Slow scan sweep
            Rectangle {
                id: scanLine
                width: backdrop.width
                height: 1
                color: Theme.accentYellow
                opacity: 0.16
                NumberAnimation on y {
                    running: splash.visible
                    loops: Animation.Infinite
                    from: 0
                    to: backdrop.height
                    duration: 2600
                    easing.type: Easing.InOutQuad
                }
            }
        }

        // Logo + tagline
        Column {
            id: logoBlock
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.16
            spacing: 16
            opacity: 0

            BrandLogo {
                id: splashLogo
                variant: "both"
                width: 220
                height: 220
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 1.05
                    height: parent.height * 1.05
                    radius: width / 2
                    color: Theme.accentYellowGlow
                    opacity: 0.0
                    z: -1
                    SequentialAnimation on opacity {
                        running: splash.visible
                        loops: 1
                        NumberAnimation { from: 0.0; to: 0.45; duration: 1100; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 0.45; to: 0.0; duration: 1100; easing.type: Easing.InOutQuad }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "GROUND  CONTROL  STATION"
                color: Theme.textSecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSectionLabel
                font.letterSpacing: 6.0
                font.weight: Font.Medium
            }
        }

        // System check list
        Column {
            id: checkList
            anchors.top: logoBlock.bottom
            anchors.topMargin: 32
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            width: 380
            opacity: 0

            // "SYSTEM CHECK" header rule
            Item {
                width: parent.width
                height: 18
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    width: parent.width * 0.30
                    height: 1
                    color: Theme.border
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    width: parent.width * 0.30
                    height: 1
                    color: Theme.border
                }
                Text {
                    anchors.centerIn: parent
                    text: "SYSTEM CHECK"
                    color: Theme.textDisabled
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontMicro
                    font.letterSpacing: 3.0
                    font.weight: Font.Medium
                }
            }

            Repeater {
                model: ["pico", "mavlink", "modgps", "lora", "periph"]
                delegate: Item {
                    id: row
                    width: 380
                    height: 22
                    opacity: 0

                    readonly property bool ok: {
                        switch (modelData) {
                        case "pico":    return GCSState.picoConnected
                        case "mavlink": return GCSState.mavlinkConnected
                        case "modgps":  return GCSState.modGpsConnected
                        case "lora":    return GCSState.loraConnected
                        case "periph":  return splash.peripheralCount > 0
                        }
                        return false
                    }
                    readonly property string label: {
                        switch (modelData) {
                        case "pico":    return "PICO LINK"
                        case "mavlink": return "MAVLINK"
                        case "modgps":  return "MODULE GPS"
                        case "lora":    return "LORA"
                        case "periph":  return "PERIPHERALS"
                        }
                        return ""
                    }
                    readonly property string detail: {
                        switch (modelData) {
                        case "pico":    return GCSState.picoConnected   ? "ONLINE"  : "WAITING"
                        case "mavlink": return GCSState.mavlinkConnected ? "LOCKED" : "STANDBY"
                        case "modgps":  return GCSState.modGpsConnected ? "ONLINE"  : "STANDBY"
                        case "lora":    return GCSState.loraConnected   ? "ONLINE"  : "STANDBY"
                        case "periph":  return splash.peripheralCount + " ACTIVE"
                        }
                        return ""
                    }

                    StatusDot {
                        id: dot
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        level: row.ok ? 0 : -1
                        Behavior on level { NumberAnimation { duration: Theme.motionFast } }
                    }
                    Text {
                        anchors.left: dot.right
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.label
                        color: Theme.textPrimary
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontValueSmall
                        font.letterSpacing: 1.5
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.detail
                        color: row.ok ? Theme.statusOk : Theme.textDisabled
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontMicro
                        font.letterSpacing: 2.0
                        font.weight: Font.Medium
                        Behavior on color { ColorAnimation { duration: Theme.motionMedium } }
                    }

                    SequentialAnimation on opacity {
                        running: splash.visible
                        PauseAnimation { duration: 650 + index * 110 }
                        NumberAnimation { to: 1.0; duration: 220; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        // Progress bar + footer
        Column {
            id: footerBlock
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
            anchors.horizontalCenter: parent.horizontalCenter
            width: 380
            spacing: 10
            opacity: 0

            Item {
                width: parent.width
                height: 3
                Rectangle {
                    anchors.fill: parent
                    color: Theme.bgSunken
                    radius: 1
                }
                Rectangle {
                    id: progressFill
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 0
                    radius: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(0.89, 0.82, 0.29, 0.55) }
                        GradientStop { position: 1.0; color: Theme.accentYellow }
                    }
                    NumberAnimation on width {
                        running: splash.visible
                        from: 0
                        to: footerBlock.width
                        duration: 2050
                        easing.type: Easing.InOutCubic
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "PICODE GCS  ·  KL-SYSTEMS  ·  v1.0"
                color: Theme.textDisabled
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontMicro
                font.letterSpacing: 3.0
            }
        }

        // Choreography: backdrop → logo → checks/footer (tap to dismiss)
        SequentialAnimation {
            id: splashSeq
            running: true
            NumberAnimation { target: backdrop;    property: "opacity"; to: 1.0; duration: 280 }
            NumberAnimation { target: logoBlock;   property: "opacity"; from: 0; to: 1; duration: 480; easing.type: Easing.OutCubic }
            ParallelAnimation {
                NumberAnimation { target: checkList;   property: "opacity"; to: 1; duration: 250 }
                NumberAnimation { target: footerBlock; property: "opacity"; to: 1; duration: 250 }
            }
        }

        // Tap anywhere to dismiss; block all other clicks while visible
        MouseArea {
            anchors.fill: parent
            enabled: splash.visible
            onClicked: root.dismissSplash()
        }
    }
}
