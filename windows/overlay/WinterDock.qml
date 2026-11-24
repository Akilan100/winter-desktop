import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property real screenW
    required property real screenH

    readonly property var modeLabels: ["Snow", "Leaves", "Rain", "Blossom"]
    readonly property var modeIcons: ["❄", "🍂", "🌧", "🌸"]

    implicitWidth: StateStore.dockCollapsed ? 48 : (dockRow.implicitWidth + 32)
    implicitHeight: 50
    width: implicitWidth
    height: implicitHeight

    Behavior on width {
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }

    // Soft ambient drop shadow behind the floating pill
    Rectangle {
        anchors.fill: pillBody
        anchors.topMargin: 5
        anchors.bottomMargin: -5
        anchors.leftMargin: -3
        anchors.rightMargin: -3
        radius: pillBody.radius + 3
        color: Qt.rgba(0, 0, 0, 0.45)
    }

    Rectangle {
        id: pillBody
        anchors.fill: parent
        radius: 25
        color: Qt.rgba(0.06, 0.08, 0.14, 0.93)
        border.color: Qt.rgba(0.75, 0.88, 1.0, 0.24)
        border.width: 1.2
        clip: true

        // Subtle top glass sheen
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            height: 1
            color: Qt.rgba(1, 1, 1, 0.20)
        }

        // Collapsed snowflake chip
        Item {
            anchors.fill: parent
            visible: StateStore.dockCollapsed

            Text {
                anchors.centerIn: parent
                text: "❄"
                color: "#93c5fd"
                font.pixelSize: 20
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    StateStore.dockCollapsed = false;
                    StateStore.save();
                }
            }
        }

        // Expanded dock row with generous spacing between every button
        Row {
            id: dockRow
            anchors.centerIn: parent
            visible: !StateStore.dockCollapsed
            spacing: 10

            // Collapse / Brand button
            Rectangle {
                width: 34
                height: 34
                radius: 17
                anchors.verticalCenter: parent.verticalCenter
                color: colMa.containsMouse ? Qt.rgba(0.58, 0.77, 0.99, 0.24) : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: colMa.containsMouse ? Qt.rgba(0.58, 0.77, 0.99, 0.48) : Qt.rgba(1, 1, 1, 0.10)
                scale: colMa.containsMouse ? 1.05 : 1.0

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: "❄"
                    color: "#93c5fd"
                    font.pixelSize: 16
                }

                MouseArea {
                    id: colMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        StateStore.dockCollapsed = true;
                        StateStore.activeCard = "";
                        StateStore.save();
                    }
                }
            }

            // Divider 1
            Rectangle {
                width: 1
                height: 22
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.14)
            }

            // Snowball button (also created by sweeping mouse or right-clicking snow!)
            Rectangle {
                width: sbRow.implicitWidth + 24
                height: 34
                radius: 17
                anchors.verticalCenter: parent.verticalCenter
                color: sbMa.containsMouse ? Qt.rgba(0.88, 0.95, 1.0, 0.22) : Qt.rgba(1, 1, 1, 0.07)
                border.width: 1
                border.color: sbMa.containsMouse ? Qt.rgba(0.88, 0.95, 1.0, 0.45) : Qt.rgba(1, 1, 1, 0.09)
                scale: sbMa.containsMouse ? 1.03 : 1.0

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Row {
                    id: sbRow
                    anchors.centerIn: parent
                    spacing: 7
                    Rectangle {
                        width: 12; height: 12; radius: 6
                        anchors.verticalCenter: parent.verticalCenter
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#ffffff" }
                            GradientStop { position: 1.0; color: "#cbd5e1" }
                        }
                    }
                    Text {
                        text: "Snowball"
                        color: "#f8fafc"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: sbMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const offset = (StateStore.snowballs.length % 5) * 54;
                        StateStore.addSnowball(Math.round(root.screenW * 0.45 + offset), root.screenH - 8, 22, "", 0);
                    }
                }
            }

            // Snowman button
            Rectangle {
                width: smRow.implicitWidth + 24
                height: 34
                radius: 17
                anchors.verticalCenter: parent.verticalCenter
                readonly property bool isActive: StateStore.activeCard === "snowman"
                color: isActive ? "#2563eb" : (smMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07))
                border.width: 1
                border.color: isActive ? "#60a5fa" : (smMa.containsMouse ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.09))
                scale: smMa.containsMouse ? 1.03 : 1.0

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Row {
                    id: smRow
                    anchors.centerIn: parent
                    spacing: 7
                    Text { text: "⛄"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: "Snowman"
                        color: "#f8fafc"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: smMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (StateStore.snowmen.length === 0) {
                            StateStore.addSnowman(root.screenW, root.screenH);
                        } else if (StateStore.activeCard === "snowman") {
                            StateStore.addSnowman(root.screenW, root.screenH);
                        } else {
                            StateStore.selectedSnowmanIdx = 0;
                            StateStore.activeCard = "snowman";
                        }
                    }
                }
            }

            // Tree button
            Rectangle {
                width: trRow.implicitWidth + 24
                height: 34
                radius: 17
                anchors.verticalCenter: parent.verticalCenter
                readonly property bool isActive: StateStore.activeCard === "tree"
                color: isActive ? "#16a34a" : (trMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07))
                border.width: 1
                border.color: isActive ? "#4ade80" : (trMa.containsMouse ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.09))
                scale: trMa.containsMouse ? 1.03 : 1.0

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Row {
                    id: trRow
                    anchors.centerIn: parent
                    spacing: 7
                    Text { text: "🎄"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: "Tree"
                        color: "#f8fafc"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: trMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (StateStore.trees.length === 0) {
                            StateStore.addTree(root.screenW, root.screenH);
                        } else if (StateStore.activeCard === "tree") {
                            StateStore.addTree(root.screenW, root.screenH);
                        } else {
                            StateStore.selectedTreeIdx = 0;
                            StateStore.activeCard = "tree";
                        }
                    }
                }
            }

            // Star & Decor button
            Rectangle {
                width: dcRow.implicitWidth + 24
                height: 34
                radius: 17
                anchors.verticalCenter: parent.verticalCenter
                readonly property bool isActive: StateStore.activeCard === "decor"
                color: isActive ? "#ca8a04" : (dcMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07))
                border.width: 1
                border.color: isActive ? "#facc15" : (dcMa.containsMouse ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.09))
                scale: dcMa.containsMouse ? 1.03 : 1.0

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Row {
                    id: dcRow
                    anchors.centerIn: parent
                    spacing: 7
                    Text { text: "✨"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: "Decor"
                        color: "#f8fafc"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: dcMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        StateStore.activeCard = (StateStore.activeCard === "decor") ? "" : "decor";
                    }
                }
            }

            // Yellow Bulldozer / Snowplow button
            Rectangle {
                width: plRow.implicitWidth + 24
                height: 34
                radius: 17
                anchors.verticalCenter: parent.verticalCenter
                color: StateStore.plowActive ? "#ca8a04" : (plMa.containsMouse ? Qt.rgba(0.98, 0.80, 0.08, 0.24) : Qt.rgba(1, 1, 1, 0.07))
                border.width: 1
                border.color: StateStore.plowActive ? "#facc15" : (plMa.containsMouse ? Qt.rgba(0.98, 0.80, 0.08, 0.45) : Qt.rgba(1, 1, 1, 0.09))
                scale: plMa.containsMouse ? 1.03 : 1.0

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Row {
                    id: plRow
                    anchors.centerIn: parent
                    spacing: 7
                    Text { text: "🚜"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: "Plow"
                        color: "#fef08a"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: plMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: StateStore.triggerSnowplow()
                }
            }

            // Santa Sleigh button
            Rectangle {
                width: snRow.implicitWidth + 24
                height: 34
                radius: 17
                anchors.verticalCenter: parent.verticalCenter
                color: StateStore.santaActive ? "#dc2626" : (snMa.containsMouse ? Qt.rgba(0.94, 0.27, 0.27, 0.24) : Qt.rgba(1, 1, 1, 0.07))
                border.width: 1
                border.color: StateStore.santaActive ? "#f87171" : (snMa.containsMouse ? Qt.rgba(0.94, 0.27, 0.27, 0.45) : Qt.rgba(1, 1, 1, 0.09))
                scale: snMa.containsMouse ? 1.03 : 1.0

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Row {
                    id: snRow
                    anchors.centerIn: parent
                    spacing: 7
                    Text { text: "🎅"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: "Santa"
                        color: "#fecaca"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: snMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: StateStore.triggerSanta()
                }
            }

            // Divider 2
            Rectangle {
                width: 1
                height: 22
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.14)
            }

            // Layer toggle (Over Windows vs Desktop Layer)
            Rectangle {
                width: lyRow.implicitWidth + 24
                height: 34
                radius: 17
                anchors.verticalCenter: parent.verticalCenter
                color: lyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)
                border.width: 1
                border.color: lyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.09)
                scale: lyMa.containsMouse ? 1.03 : 1.0

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Row {
                    id: lyRow
                    anchors.centerIn: parent
                    spacing: 7
                    Text { text: StateStore.behindWindows ? "🖼" : "🪟"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: StateStore.behindWindows ? "Behind" : "On Top"
                        color: "#e2e8f0"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: lyMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        StateStore.behindWindows = !StateStore.behindWindows;
                        StateStore.save();
                    }
                }
            }

            // Weather mode cycle (Snowhush)
            Rectangle {
                width: mdRow.implicitWidth + 24
                height: 34
                radius: 17
                anchors.verticalCenter: parent.verticalCenter
                color: mdMa.containsMouse ? Qt.rgba(0.22, 0.74, 0.97, 0.24) : Qt.rgba(0.22, 0.74, 0.97, 0.11)
                border.width: 1
                border.color: mdMa.containsMouse ? Qt.rgba(0.49, 0.83, 0.99, 0.48) : Qt.rgba(0.49, 0.83, 0.99, 0.22)
                scale: mdMa.containsMouse ? 1.03 : 1.0

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Row {
                    id: mdRow
                    anchors.centerIn: parent
                    spacing: 7
                    Text {
                        text: root.modeIcons[StateStore.snowMode] || "❄"
                        font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: (root.modeLabels[StateStore.snowMode] || "Snow") + " " + StateStore.snowIntensity + "%"
                        color: "#bae6fd"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: mdMa
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            const nextInt = StateStore.snowIntensity === 50 ? 75 : (StateStore.snowIntensity === 75 ? 100 : 50);
                            StateStore.setSnowhushIntensity(nextInt);
                        } else {
                            const nextMode = (StateStore.snowMode + 1) % 4;
                            StateStore.setSnowhushMode(nextMode);
                        }
                    }
                }
            }

            // Turn Off completely
            Rectangle {
                width: offRow.implicitWidth + 22
                height: 34
                radius: 17
                anchors.verticalCenter: parent.verticalCenter
                color: offMa.containsMouse ? Qt.rgba(0.94, 0.27, 0.27, 0.40) : Qt.rgba(0.94, 0.27, 0.27, 0.18)
                border.width: 1
                border.color: offMa.containsMouse ? Qt.rgba(0.99, 0.65, 0.65, 0.58) : Qt.rgba(0.94, 0.27, 0.27, 0.32)
                scale: offMa.containsMouse ? 1.03 : 1.0

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Row {
                    id: offRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "⏻"; color: "#fecaca"; font.pixelSize: 13; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Off"; color: "#fecaca"; font.pixelSize: 13; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    id: offMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: StateStore.quitAll()
                }
            }
        }
    }
}
