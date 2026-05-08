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

        BrandLogo {
            id: splashLogo
            variant: "both"
            width: 280
            height: 280
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -10
            opacity: 0
            scale: 0.94

            // Pulsing halo
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
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.0; to: 0.55; duration: 900; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.55; to: 0.0; duration: 900; easing.type: Easing.InOutQuad }
                }
            }
        }

        // Boot status line (small, monospaced, under the logo)
        Text {
            id: bootText
            anchors {
                top: splashLogo.bottom
                topMargin: 10
                horizontalCenter: parent.horizontalCenter
            }
            text: "INITIALIZING"
            color: Theme.textDisabled
            font.pixelSize: Theme.fontSectionLabel
            font.family: Theme.fontMono
            font.letterSpacing: 4.0
            font.weight: Font.Medium
            opacity: 0
        }

        // 3-dot loading indicator
        Row {
            anchors {
                top: bootText.bottom
                topMargin: 8
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 6
            opacity: bootText.opacity
            Repeater {
                model: 3
                Rectangle {
                    width: 5; height: 5; radius: 2.5
                    color: Theme.accentYellow
                    opacity: 0.25
                    SequentialAnimation on opacity {
                        running: splash.visible
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 200 }
                        NumberAnimation { to: 1.0; duration: 280 }
                        NumberAnimation { to: 0.25; duration: 380 }
                        PauseAnimation { duration: (2 - index) * 200 }
                    }
                }
            }
        }

        // Sequence: fade-in logo → settle → hold → fade-out splash
        SequentialAnimation {
            id: splashSeq
            running: true
            ParallelAnimation {
                NumberAnimation { target: splashLogo; property: "opacity"; from: 0; to: 1; duration: 450; easing.type: Easing.OutCubic }
                NumberAnimation { target: splashLogo; property: "scale"; from: 0.94; to: 1.0; duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }
            NumberAnimation { target: bootText; property: "opacity"; to: 0.85; duration: 250 }
            PauseAnimation { duration: 700 }
            ParallelAnimation {
                NumberAnimation { target: splashLogo; property: "scale"; to: 1.04; duration: 350; easing.type: Easing.InCubic }
                NumberAnimation { target: splash; property: "opacity"; to: 0; duration: 350; easing.type: Easing.InCubic }
            }
            ScriptAction { script: splash.visible = false }
        }

        // Block clicks while visible
        MouseArea { anchors.fill: parent; enabled: splash.visible }
    }
}
