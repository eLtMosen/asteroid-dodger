/*
 * Copyright (C) 2025 - Timo Könnecke <github.com/eLtMosen>
 *
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 2.1 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.15
import QtSensors 5.15
import Nemo.Ngf 1.0
import Nemo.Configuration 1.0
import QtQuick.Shapes 1.15
import org.asteroid.controls 1.0

Item {
    id: root
    anchors.fill: parent
    visible: true

    property real scrollSpeed: 1.6
    property real savedScrollSpeed: 0
    property real basePlayerSpeed: 1.2
    property real playerSpeed: basePlayerSpeed
    property int asteroidCount: 0
    property int score: 0
    property int lives: 2
    property int level: 1
    property int asteroidsPerLevel: 100
    property real asteroidDensity: 0.044 + (level - 1) * 0.00242
    property real largeAsteroidDensity: asteroidDensity / 2
    property bool gameOver: false
    property bool playerHit: false
    property bool paused: false
    property bool calibrating: false
    property bool showingNow: false
    property bool showingSurvive: false
    property real baselineX: 0
    property int calibrationTimer: 5
    property bool invincible: false
    property real closePassThreshold: Dims.l(10)
    property string flashColor: ""
    property int comboCount: 0
    property real lastDodgeTime: 0
    property bool comboActive: false
    property real scoreMultiplier: 1.0
    property real scoreMultiplierElapsed: 0
    property real preSlowSpeed: 0
    property bool isSlowMoActive: false
    property bool isSpeedBoostActive: false
    property bool isShrinkActive: false
    property var activePowerups: []

    property var asteroidPool: []
    property var largeAsteroidPool: []
    property int asteroidPoolSize: 40
    property int largeAsteroidPoolSize: 10
    property real lastFrameTime: 0

    onPausedChanged: {
        if (paused) {
            savedScrollSpeed = scrollSpeed
            scrollSpeed = 0
            if (comboActive) {
                comboMeterAnimation.pause()
            }
        } else {
            scrollSpeed = savedScrollSpeed
            if (comboActive) {
                comboMeterAnimation.resume()
            }
        }
    }

    onGameOverChanged: {
        if (gameOver) {
            if (score > highScore.value) {
                highScore.value = score
            }
            if (level > highLevel.value) {
                highLevel.value = level
            }
            clearPowerupBars()
        }
    }

    ConfigurationValue {
        id: highScore
        key: "/asteroid-dodger/highScore"
        defaultValue: 0
    }

    ConfigurationValue {
        id: highLevel
        key: "/asteroid-dodger/highLevel"
        defaultValue: 1
    }

    NonGraphicalFeedback {
        id: feedback
        event: "press"
    }

    Component {
        id: progressBarComponent
        Item {
            id: progressBar
            property real progress: 1.0
            property string fillColor: "#FFD700"
            property int duration: 0
            property var timer: null
            width: Dims.l(28)
            height: Dims.l(2)

            Rectangle {
                width: parent.width
                height: parent.height
                radius: Dims.l(1)
                color: "#8B6914"
                opacity: 0.5
            }

            Rectangle {
                id: fill
                width: parent.width * progress
                height: parent.height
                color: fillColor
                radius: Dims.l(1)
                opacity: 0.5
            }

            function startTimer() {
                if (timer) {
                    timer.destroy()
                }
                timer = Qt.createQmlObject(`
                    import QtQuick 2.15
                    Timer {
                        interval: 16
                        running: true
                        repeat: true
                        property real elapsed: 0
                        onTriggered: {
                            elapsed += interval
                            progress = Math.max(0, 1 - elapsed / duration)
                            if (progress <= 0) {
                                progressBar.destroy()
                            }
                        }
                    }
                `, progressBar, "powerupTimer")
            }

            onProgressChanged: {
                if (progress <= 0 && timer) {
                    timer.destroy()
                    progressBar.destroy()
                }
            }
        }
    }

    Timer {
        id: gameTimer
        interval: 16
        running: !gameOver && !calibrating && !showingNow && !showingSurvive
        repeat: true
        onTriggered: {
            var currentTime = Date.now()
            var deltaTime = lastFrameTime > 0 ? (currentTime - lastFrameTime) / 1000 : 0.016
            lastFrameTime = currentTime
            updateGame(deltaTime)
        }
    }

    Timer {
        id: graceTimer
        interval: 1000
        running: invincible && !paused
        repeat: false
        onTriggered: {
            invincible = false
            removePowerup("invincibility")
        }
    }

    Timer {
        id: speedBoostTimer
        interval: 3000
        running: isSpeedBoostActive && !paused
        repeat: false
        onTriggered: {
            playerSpeed = basePlayerSpeed
            isSpeedBoostActive = false
            removePowerup("speedBoost")
        }
    }

    Timer {
        id: scoreMultiplierTimer
        interval: 10000
        running: scoreMultiplier > 1.0 && !paused
        repeat: false
        onTriggered: {
            scoreMultiplier = 1.0
            scoreMultiplierElapsed = 0
            removePowerup("scoreMultiplier")
        }
    }

    Timer {
        id: slowMoTimer
        interval: 6000
        running: isSlowMoActive && !paused
        repeat: false
        onTriggered: {
            scrollSpeed = preSlowSpeed
            savedScrollSpeed = preSlowSpeed
            isSlowMoActive = false
            removePowerup("slowMo")
        }
    }

    Timer {
        id: shrinkTimer
        interval: 6000
        running: isShrinkActive && !paused
        repeat: false
        onTriggered: {
            isShrinkActive = false
            removePowerup("shrink")
        }
    }

    Timer {
        id: calibrationCountdownTimer
        interval: 1000
        running: calibrating
        repeat: true
        onTriggered: {
            calibrationTimer--
            if (calibrationTimer <= 0) {
                baselineX = accelerometer.reading.x
                calibrating = false
                showingNow = true
                feedback.play()
                nowTransition.start()
            }
        }
    }

    Timer {
        id: nowToSurviveTimer
        interval: 1000
        running: showingNow
        repeat: false
        onTriggered: {
            showingNow = false
            showingSurvive = true
            surviveTransition.start()
        }
    }

    Timer {
        id: surviveToGameTimer
        interval: 1000
        running: showingSurvive
        repeat: false
        onTriggered: {
            showingSurvive = false
        }
    }

    Timer {
        id: comboTimer
        interval: 2000
        running: comboActive && !paused
        repeat: false
        onTriggered: {
            comboCount = 0
            comboActive = false
        }
    }

    Timer {
        id: accelerometerTimer
        interval: 12
        running: !gameOver && !paused && !calibrating && !showingNow && !showingSurvive
        repeat: true
        onTriggered: {
            var deltaX = (accelerometer.reading.x - baselineX) * -2
            var newX = playerContainer.x + deltaX * playerSpeed
            playerContainer.x = Math.max(0, Math.min(root.width - player.width, newX))
        }
    }

    Component {
        id: comboParticleComponent
        Text {
            id: particleText
            property int points: 1
            text: "+" + points
            color: {
                if (points <= 10) return "#00CC00"  // Green
                if (points <= 20) {
                    var t = (points - 10) / 10
                    var r = Math.round(0x00 + t * (0xFF - 0x00))
                    var g = Math.round(0xCC + t * (0xD7 - 0xCC))
                    var b = Math.round(0x00 + t * (0x00 - 0x00))
                    return Qt.rgba(r / 255, g / 255, b / 255, 1)
                }
                if (points <= 40) {
                    var t = (points - 20) / 20
                    var r = Math.round(0xFF + t * (0xFF - 0xFF))
                    var g = Math.round(0xD7 + t * (0x69 - 0xD7))
                    var b = Math.round(0x00 + t * (0xB4 - 0x00))
                    return Qt.rgba(r / 255, g / 255, b / 255, 1)
                }
                return "#FF69B4"  // Pink beyond 40
            }
            font.pixelSize: {
                if (points <= 10) return Dims.l(4)
                if (points <= 20) {
                    var t = (points - 10) / 10
                    return (Dims.l(4) + t * (Dims.l(5) - Dims.l(4)))
                }
                if (points <= 40) {
                    var t = (points - 20) / 20
                    return (Dims.l(5) + t * (Dims.l(6) - Dims.l(5)))
                }
                if (points <= 100) {
                    var t = (points - 40) / 60
                    return (Dims.l(6) + t * (Dims.l(7) - Dims.l(6)))
                }
                return Dims.l(7)
            }
            z: 3
            opacity: 1

            SequentialAnimation {
                id: particleAnimation
                running: true
                ParallelAnimation {
                    NumberAnimation {
                        target: particleText
                        property: "x"
                        to: x + (x < playerContainer.x ? -Dims.l(8) : Dims.l(8))
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: particleText
                        property: "y"
                        to: y - Dims.l(7)
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: particleText
                        property: "y"
                        to: y + Dims.l(11)
                        duration: 600
                        easing.type: Easing.Linear
                    }
                    NumberAnimation {
                        target: particleText
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: 600
                        easing.type: Easing.Linear
                    }
                }
                onStopped: {
                    particleText.destroy()
                }
            }
        }
    }

    Component {
        id: shrinkAnimationComponent
        ParallelAnimation {
            running: isShrinkActive && !root.paused
            NumberAnimation {
                target: player
                property: "width"
                from: Dims.l(5)
                to: Dims.l(10)
                duration: 6000
                easing.type: Easing.Linear
            }
            NumberAnimation {
                target: player
                property: "height"
                from: Dims.l(5)
                to: Dims.l(10)
                duration: 6000
                easing.type: Easing.Linear
            }
            NumberAnimation {
                target: playerHitbox
                property: "width"
                from: Dims.l(7)
                to: Dims.l(14)
                duration: 6000
                easing.type: Easing.Linear
            }
            NumberAnimation {
                target: playerHitbox
                property: "height"
                from: Dims.l(7)
                to: Dims.l(14)
                duration: 6000
                easing.type: Easing.Linear
            }
            onStopped: {
                isShrinkActive = false
            }
        }
    }

    Item {
        id: gameArea
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "black"
        }

        Item {
            id: gameContent
            anchors.fill: parent
            layer.enabled: true

            Rectangle {
                id: flashOverlay
                anchors.fill: parent
                color: flashColor ? flashColor : "transparent"
                opacity: 0
                z: 5
                SequentialAnimation {
                    id: flashAnimation
                    running: false
                    NumberAnimation {
                        target: flashOverlay
                        property: "opacity"
                        from: 0.5
                        to: 0
                        duration: flashColor === "#8B6914" || flashColor === "#00FFFF" ? 6000 : 500
                        easing.type: Easing.OutQuad
                    }
                    onStopped: {
                        flashOverlay.opacity = 0
                        flashColor = ""
                    }
                }
                function triggerFlash(color) {
                    if (flashAnimation.running) {
                        flashAnimation.stop()
                    }
                    flashColor = color
                    opacity = 0.5
                    flashAnimation.start()
                }
            }

            Item {
                id: largeAsteroidContainer
                width: parent.width
                height: parent.height
                z: 0
                visible: !calibrating && !showingNow && !showingSurvive
            }

            Item {
                id: playerContainer
                x: root.width / 2
                y: root.height * 0.75
                z: 1
                visible: !calibrating && !showingNow && !showingSurvive

                Image {
                    id: player
                    width: Dims.l(10)
                    height: Dims.l(10)
                    source: "file:///usr/share/asteroid-launcher/watchfaces-img/asteroid-logo.svg"
                    anchors.centerIn: parent

                    SequentialAnimation on opacity {
                        running: invincible && !root.paused
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.2; duration: 500; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.2; to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                        onStopped: {
                            player.opacity = 1.0
                        }
                    }
                    opacity: 1.0

                    SequentialAnimation on rotation {
                        running: speedBoostTimer.running && !root.paused
                        loops: Animation.Infinite
                        NumberAnimation { from: -5; to: 5; duration: 200; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 5; to: -5; duration: 200; easing.type: Easing.InOutSine }
                        onStopped: {
                            player.rotation = 0
                        }
                    }
                }

                Shape {
                    id: playerHitbox
                    width: Dims.l(14)
                    height: Dims.l(14)
                    anchors.centerIn: parent
                    visible: false

                    ShapePath {
                        strokeWidth: -1
                        fillColor: "transparent"
                        startX: Dims.l(7); startY: 0
                        PathLine { x: Dims.l(14); y: Dims.l(7) }
                        PathLine { x: Dims.l(7); y: Dims.l(14) }
                        PathLine { x: 0; y: Dims.l(7) }
                        PathLine { x: Dims.l(7); y: 0 }
                    }
                }

                Shape {
                    id: comboHitbox
                    width: Dims.l(40)
                    height: Dims.l(40)
                    anchors.centerIn: parent
                    visible: comboActive
                    opacity: 0.2

                    ShapePath {
                        strokeWidth: Dims.l(1)
                        strokeColor: "#00CC00"
                        fillColor: "transparent"
                        startX: Dims.l(20); startY: Dims.l(10)
                        PathLine { x: Dims.l(30); y: Dims.l(20) }
                        PathLine { x: Dims.l(20); y: Dims.l(30) }
                        PathLine { x: Dims.l(10); y: Dims.l(20) }
                        PathLine { x: Dims.l(20); y: Dims.l(10) }
                    }
                }
            }

            Item {
                id: objectContainer
                width: parent.width
                height: parent.height
                z: 0
                visible: !calibrating && !showingNow && !showingSurvive
            }

            Item {
                id: progressBarsContainer
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: Dims.l(6)
                }
                z: 4
                visible: !gameOver && !calibrating && !showingNow && !showingSurvive

                Item {
                    id: levelProgressBar
                    width: Dims.l(28)
                    height: Dims.l(2)
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: parent.width
                        height: parent.height
                        radius: Dims.l(1)
                        color: "#8B6914"
                        opacity: 0.5
                    }

                    Rectangle {
                        id: progressFill
                        width: (asteroidCount / asteroidsPerLevel) * parent.width
                        height: parent.height
                        color: "#FFD700"
                        radius: Dims.l(1)
                        opacity: 0.5
                    }
                }

                Column {
                    id: powerupBars
                    anchors {
                        top: levelProgressBar.bottom
                        topMargin: Dims.l(1)
                        horizontalCenter: parent.horizontalCenter
                    }
                    spacing: Dims.l(1)
                }
            }

            Column {
                id: hudBottom
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                    margins: Dims.l(2)
                }
                spacing: Dims.l(1)
                visible: !gameOver && !calibrating && !showingNow && !showingSurvive
                Text {
                    text: "❤️ " + lives
                    color: "#dddddd"
                    font.pixelSize: Dims.l(6)
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Item {
                id: scoreArea
                z: 2
                visible: !gameOver && !calibrating && !showingNow && !showingSurvive
                Binding {
                    target: scoreArea
                    property: "x"
                    value: playerContainer.x + playerContainer.width / 2 - scoreText.width / 2
                    when: !gameOver && !paused && !calibrating && !showingNow && !showingSurvive
                }
                Binding {
                    target: scoreArea
                    property: "y"
                    value: playerContainer.y + playerContainer.height + Dims.l(6)
                    when: !gameOver && !paused && !calibrating && !showingNow && !showingSurvive
                }

                Rectangle {
                    id: comboMeter
                    property int maxWidth: Dims.l(13)
                    height: Dims.l(1)
                    width: 0
                    color: "green"
                    radius: height / 2
                    x: (scoreText.width - width) / 2
                    y: -height + Dims.l(1)
                    SequentialAnimation {
                        id: comboMeterAnimation
                        running: comboActive && !root.paused
                        NumberAnimation {
                            target: comboMeter
                            property: "width"
                            from: 0
                            to: comboMeter.maxWidth
                            duration: 50
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: comboMeter
                            property: "width"
                            from: comboMeter.maxWidth
                            to: 0
                            duration: 1950
                            easing.type: Easing.Linear
                        }
                        onStopped: {
                            comboMeter.width = 0
                        }
                    }
                }

                Text {
                    id: scoreText
                    text: score
                    color: scoreMultiplierTimer.running ? "#00CC00" : "#dddddd"
                    font.pixelSize: Dims.l(5)
                    font.bold: scoreMultiplierTimer.running
                }
            }

            Column {
                id: calibrationText
                anchors.centerIn: parent
                spacing: Dims.l(1)
                visible: calibrating
                opacity: showingNow ? 0 : 1
                Behavior on opacity {
                    NumberAnimation { duration: 500; easing.type: Easing.InOutQuad }
                }
                Text {
                    text: "Calibrating"
                    color: "white"
                    font.pixelSize: Dims.l(7)
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Hold your watch comfy"
                    color: "white"
                    font.pixelSize: Dims.l(4)
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: calibrationTimer + "s"
                    color: "white"
                    font.pixelSize: Dims.l(6)
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Text {
                id: nowText
                text: "NOW"
                color: "white"
                font.pixelSize: Dims.l(13)
                anchors.centerIn: parent
                visible: showingNow
                opacity: 0
                SequentialAnimation {
                    id: nowTransition
                    running: false
                    NumberAnimation { target: nowText; property: "opacity"; from: 0; to: 1; duration: 500 }
                    ParallelAnimation {
                        NumberAnimation { target: nowText; property: "font.pixelSize"; from: Dims.l(13); to: Dims.l(33); duration: 1000; easing.type: Easing.OutQuad }
                        NumberAnimation { target: nowText; property: "opacity"; from: 1; to: 0; duration: 1000; easing.type: Easing.OutQuad }
                    }
                }
            }

            Text {
                id: surviveText
                text: "SURVIVE"
                color: "orange"
                font.pixelSize: Dims.l(13)
                font.bold: true
                anchors.centerIn: parent
                visible: showingSurvive
                opacity: 0
                SequentialAnimation {
                    id: surviveTransition
                    running: false
                    NumberAnimation { target: surviveText; property: "opacity"; from: 0; to: 1; duration: 500 }
                    ParallelAnimation {
                        NumberAnimation { target: surviveText; property: "font.pixelSize"; from: Dims.l(13); to: Dims.l(33); duration: 1000; easing.type: Easing.OutQuad }
                        NumberAnimation { target: surviveText; property: "opacity"; from: 1; to: 0; duration: 1000; easing.type: Easing.OutQuad }
                    }
                }
            }

            Text {
                id: pauseText
                text: "Paused"
                color: "white"
                font.pixelSize: Dims.l(9)
                anchors.centerIn: parent
                visible: paused && !gameOver && !calibrating && !showingNow && !showingSurvive
            }

            Text {
                id: levelNumber
                text: level
                color: "#dddddd"
                font.pixelSize: Dims.l(4)
                font.bold: true
                anchors {
                    bottom: levelProgressBar.top
                    horizontalCenter: parent.horizontalCenter
                    bottomMargin: Dims.l(1)
                }
                z: 4
                visible: !gameOver && !calibrating && !showingNow && !showingSurvive
            }
        }

        Item {
            id: gameOverScreen
            anchors.centerIn: parent
            z: 5
            visible: gameOver
            opacity: 0
            Behavior on opacity {
                NumberAnimation { duration: 250 }
            }
            onVisibleChanged: {
                if (visible) {
                    opacity = 1
                }
            }

            Column {
                spacing: Dims.l(6)
                anchors.centerIn: parent

                Text {
                    id: gameOverText
                    text: "Game Over!"
                    color: "red"
                    font.pixelSize: Dims.l(8)
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Column {
                    spacing: Dims.l(1)
                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        spacing: Dims.l(2)
                        Text { text: "Score"; color: "#dddddd"; font.pixelSize: Dims.l(4); width: Dims.l(22); horizontalAlignment: Text.AlignHCenter }
                        Text { text: score; color: "white"; font.pixelSize: Dims.l(5); font.bold: true; width: Dims.l(11); horizontalAlignment: Text.AlignHCenter }
                    }
                    Row {
                        spacing: Dims.l(2)
                        Text { text: "Level"; color: "#dddddd"; font.pixelSize: Dims.l(4); width: Dims.l(22); horizontalAlignment: Text.AlignHCenter }
                        Text { text: level; color: "white"; font.pixelSize: Dims.l(5); font.bold: true; width: Dims.l(11); horizontalAlignment: Text.AlignHCenter }
                    }
                    Row {
                        spacing: Dims.l(2)
                        Text { text: "High Score"; color: "#dddddd"; font.pixelSize: Dims.l(4); width: Dims.l(22); horizontalAlignment: Text.AlignHCenter }
                        Text { text: highScore.value; color: "white"; font.pixelSize: Dims.l(5); font.bold: true; width: Dims.l(11); horizontalAlignment: Text.AlignHCenter }
                    }
                    Row {
                        spacing: Dims.l(2)
                        Text { text: "Max Level"; color: "#dddddd"; font.pixelSize: Dims.l(4); width: Dims.l(22); horizontalAlignment: Text.AlignHCenter }
                        Text { text: highLevel.value; color: "white"; font.pixelSize: Dims.l(5); font.bold: true; width: Dims.l(11); horizontalAlignment: Text.AlignHCenter }
                    }
                }

                Rectangle {
                    id: tryAgainButton
                    width: Dims.l(42)
                    height: Dims.l(14)
                    color: "green"
                    border.color: "white"
                    border.width: Dims.l(1)
                    radius: Dims.l(3)
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "Die Again"
                        color: "white"
                        font.pixelSize: Dims.l(6)
                        font.bold: true
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            restartGame()
                        }
                    }
                }
            }
        }

        Component {
            id: largeAsteroidComponent
            Rectangle {
                width: Dims.l(8 + Math.random() * 12)
                height: width
                x: Math.random() * (root.width - width)
                y: -height - (Math.random() * Dims.l(28))
                color: "#0e003d"
                opacity: 1 - Math.random() * 0.7
                radius: Dims.l(50)
                visible: false
            }
        }

        Component {
            id: objectComponent
            Item {
                property bool isAsteroid: true
                property bool isPowerup: false
                property bool isInvincibility: false
                property bool isSpeedBoost: false
                property bool isScoreMultiplier: false
                property bool isShrink: false
                property bool isSlowMo: false
                property bool passed: false
                property bool dodged: false
                width: isAsteroid ? Dims.l(3) : Dims.l(6)
                height: isAsteroid ? Dims.l(3) : Dims.l(6)
                x: Math.random() * (root.width - width)
                y: -height - (Math.random() * Dims.l(28))
                visible: false

                Shape {
                    id: asteroidShape
                    visible: isAsteroid && !dodged
                    property real sizeFactor: 0.8 + Math.random() * 0.4
                    width: Dims.l(3) * sizeFactor
                    height: Dims.l(3) * sizeFactor
                    anchors.centerIn: parent

                    ShapePath {
                        strokeWidth: -1
                        fillColor: {
                            var base = 230
                            var delta = Math.round(base * 0.22)
                            var rand = Math.round(base - delta + Math.random() * (2 * delta))
                            rand = Math.max(179, Math.min(255, rand))
                            var hex = rand.toString(16).padStart(2, '0')
                            return "#" + hex + hex + hex + "ff"
                        }
                        startX: asteroidShape.width * 0.5; startY: 0
                        PathLine { x: asteroidShape.width; y: asteroidShape.height * 0.5 }
                        PathLine { x: asteroidShape.width * 0.5; y: asteroidShape.height }
                        PathLine { x: 0; y: asteroidShape.height * 0.5 }
                        PathLine { x: asteroidShape.width * 0.5; y: 0 }
                    }
                }

                Text {
                    id: scoreText
                    visible: isAsteroid && dodged
                    text: "+1"
                    color: "#00CC00"
                    font.pixelSize: Dims.l(4)
                    anchors.centerIn: parent
                    Behavior on opacity {
                        NumberAnimation {
                            from: 1
                            to: 0
                            duration: 900
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                Text {
                    visible: !isAsteroid
                    text: "!"
                    color: {
                        if (isInvincibility) return "#FF69B4"
                        if (isSpeedBoost) return "#FFFF00"
                        if (isScoreMultiplier) return "#00CC00"
                        if (isShrink) return "#FFA500"
                        if (isSlowMo) return "#00FFFF"
                        return "#0087ff"
                    }
                    font.pixelSize: Dims.l(5)
                    font.bold: true
                    anchors.centerIn: parent
                }
            }
        }

        Accelerometer {
            id: accelerometer
            active: true
        }

        MouseArea {
            anchors.fill: parent
            enabled: !gameOver && !calibrating && !showingNow && !showingSurvive
            onClicked: {
                paused = !paused
            }
        }
    }

    function addPowerupBar(type, duration, color) {
        var existing = activePowerups.find(function(p) { return p.type === type })
        if (existing) {
            existing.bar.progress = 1.0
            existing.bar.startTimer()
            return
        }

        var bar = progressBarComponent.createObject(powerupBars, {
            "fillColor": color,
            "duration": duration
        })
        bar.startTimer()
        activePowerups.push({ type: type, bar: bar })
    }

    function removePowerup(type) {
        var index = activePowerups.findIndex(function(p) { return p.type === type })
        if (index !== -1) {
            var powerup = activePowerups[index]
            if (powerup.bar) {
                powerup.bar.destroy()
            }
            activePowerups.splice(index, 1)
        }
    }

    function clearPowerupBars() {
        for (var i = 0; i < activePowerups.length; i++) {
            if (activePowerups[i].bar) {
                activePowerups[i].bar.destroy()
            }
        }
        activePowerups = []
    }

    function updateGame(deltaTime) {
        var adjustedScrollSpeed = scrollSpeed * deltaTime * 60
        var largeAsteroidSpeed = adjustedScrollSpeed / 3

        var playerCenterX = playerContainer.x + playerHitbox.x + playerHitbox.width / 2
        var playerCenterY = playerContainer.y + playerHitbox.y + playerHitbox.height / 2
        var comboCenterX = playerContainer.x + comboHitbox.x + comboHitbox.width / 2
        var comboCenterY = playerContainer.y + comboHitbox.y + comboHitbox.height / 2
        var maxDistanceSquared = (playerHitbox.width + Dims.l(5)) * (playerHitbox.width + Dims.l(5))
        var comboDistanceSquared = (comboHitbox.width + Dims.l(5)) * (comboHitbox.width + Dims.l(5))

        for (var i = 0; i < largeAsteroidPool.length; i++) {
            var largeObj = largeAsteroidPool[i]
            if (largeObj.visible) {
                largeObj.y += largeAsteroidSpeed
                if (largeObj.y >= root.height) {
                    largeObj.visible = false
                }
            }
        }

        for (i = 0; i < asteroidPool.length; i++) {
            var obj = asteroidPool[i]
            if (obj.visible) {
                obj.y += adjustedScrollSpeed

                var objCenterX = obj.x + obj.width / 2
                var objCenterY = obj.y + obj.height / 2
                var dx = objCenterX - playerCenterX
                var dy = objCenterY - playerCenterY
                var distanceSquared = dx * dx + dy * dy

                if (distanceSquared < maxDistanceSquared) {
                    if (obj.isAsteroid && isColliding(playerHitbox, obj) && !invincible) {
                        lives--
                        flashOverlay.triggerFlash("red")
                        comboCount = 0
                        comboActive = false
                        comboTimer.stop()
                        comboMeterAnimation.stop()
                        invincible = true
                        graceTimer.restart()
                        obj.visible = false
                        feedback.play()
                        if (lives <= 0) {
                            gameOver = true
                        }
                        continue
                    }

                    if (obj.isPowerup && isColliding(playerHitbox, obj)) {
                        lives++
                        flashOverlay.triggerFlash("blue")
                        comboCount = 0
                        comboActive = false
                        comboTimer.stop()
                        comboMeterAnimation.stop()
                        obj.visible = false
                        continue
                    }

                    if (obj.isInvincibility && isColliding(playerHitbox, obj)) {
                        invincible = true
                        graceTimer.interval = 4000
                        graceTimer.restart()
                        flashOverlay.triggerFlash("#FF69B4")
                        addPowerupBar("invincibility", 4000, "#FF69B4")
                        comboCount = 0
                        comboActive = false
                        comboTimer.stop()
                        comboMeterAnimation.stop()
                        obj.visible = false
                        continue
                    }

                    if (obj.isSpeedBoost && isColliding(playerHitbox, obj) && !isSpeedBoostActive) {
                        playerSpeed = basePlayerSpeed * 2
                        isSpeedBoostActive = true
                        speedBoostTimer.restart()
                        flashOverlay.triggerFlash("#FFFF00")
                        addPowerupBar("speedBoost", 3000, "#FFFF00")
                        comboCount = 0
                        comboActive = false
                        comboTimer.stop()
                        comboMeterAnimation.stop()
                        obj.visible = false
                        continue
                    }

                    if (obj.isScoreMultiplier && isColliding(playerHitbox, obj)) {
                        scoreMultiplier = 2.0
                        scoreMultiplierElapsed = 0
                        scoreMultiplierTimer.restart()
                        flashOverlay.triggerFlash("#00CC00")
                        addPowerupBar("scoreMultiplier", 10000, "#00CC00")
                        comboCount = 0
                        comboActive = false
                        comboTimer.stop()
                        comboMeterAnimation.stop()
                        obj.visible = false
                        continue
                    }

                    if (obj.isShrink && isColliding(playerHitbox, obj)) {
                        player.width = Dims.l(5)
                        player.height = Dims.l(5)
                        playerHitbox.width = Dims.l(7)
                        playerHitbox.height = Dims.l(7)
                        isShrinkActive = true
                        shrinkTimer.restart()
                        shrinkAnimationComponent.createObject(root).start()
                        flashOverlay.triggerFlash("#FFA500")
                        addPowerupBar("shrink", 6000, "#FFA500")
                        comboCount = 0
                        comboActive = false
                        comboTimer.stop()
                        comboMeterAnimation.stop()
                        obj.visible = false
                        continue
                    }

                    if (obj.isSlowMo && isColliding(playerHitbox, obj) && !isSlowMoActive) {
                        preSlowSpeed = scrollSpeed
                        scrollSpeed = scrollSpeed / 2
                        savedScrollSpeed = scrollSpeed
                        isSlowMoActive = true
                        slowMoTimer.restart()
                        flashOverlay.triggerFlash("#00FFFF")
                        addPowerupBar("slowMo", 6000, "#00FFFF")
                        comboCount = 0
                        comboActive = false
                        comboTimer.stop()
                        comboMeterAnimation.stop()
                        obj.visible = false
                        continue
                    }
                }

                if (obj.isAsteroid && (obj.y + obj.height / 2) > (playerContainer.y + player.height / 2) && !obj.passed) {
                    asteroidCount++
                    obj.passed = true
                    var comboDx = objCenterX - comboCenterX
                    var comboDy = objCenterY - comboCenterY
                    var comboDistSquared = comboDx * comboDx + comboDy * comboDy
                    var isCombo = comboDistSquared < comboDistanceSquared && isColliding(comboHitbox, obj)
                    var basePoints = isCombo ? 2 : 1
                    var currentTime = Date.now()

                    if (isCombo) {
                        if (currentTime - lastDodgeTime <= 2000) {
                            comboCount++
                        } else {
                            comboCount = 1
                        }
                        lastDodgeTime = currentTime
                        comboActive = true
                        comboTimer.restart()
                        comboMeterAnimation.restart()
                        score += basePoints * comboCount * scoreMultiplier
                        var particle = comboParticleComponent.createObject(gameArea, {
                            "x": obj.x,
                            "y": obj.y,
                            "points": basePoints * comboCount * scoreMultiplier
                        })
                    } else {
                        score += basePoints * scoreMultiplier
                        obj.dodged = true
                    }

                    if (asteroidCount >= asteroidsPerLevel) {
                        levelUp()
                    }
                }

                if (obj.y >= root.height) {
                    obj.visible = false
                }
            }
        }

        if (scoreMultiplierTimer.running) {
            scoreMultiplierElapsed += deltaTime
        }

        if (!paused && Math.random() < largeAsteroidDensity / 2) {
            spawnLargeAsteroid()
        }

        if (!paused && Math.random() < asteroidDensity) {
            var isAsteroid = Math.random() < 0.96
            spawnObject(isAsteroid ? {isAsteroid: true} : {isAsteroid: false, isPowerup: true})
        }

        if (!paused && Math.random() < 0.0001) {
            spawnObject({isAsteroid: false, isInvincibility: true})
        }

        if (!paused && Math.random() < 0.0005) {
            spawnObject({isAsteroid: false, isSpeedBoost: true})
        }

        if (!paused && Math.random() < 0.0005) {
            spawnObject({isAsteroid: false, isScoreMultiplier: true})
        }

        if (!paused && Math.random() < 0.0005) {
            spawnObject({isAsteroid: false, isShrink: true})
        }

        if (!paused && Math.random() < 0.0003) {
            spawnObject({isAsteroid: false, isSlowMo: true})
        }
    }

    function spawnLargeAsteroid() {
        for (var i = 0; i < largeAsteroidPool.length; i++) {
            var obj = largeAsteroidPool[i]
            if (!obj.visible) {
                obj.width = Dims.l(8 + Math.random() * 12)
                obj.height = obj.width
                obj.x = Math.random() * (root.width - obj.width)
                obj.y = -obj.height - (Math.random() * Dims.l(28))
                obj.opacity = 1 - Math.random() * 0.7
                obj.visible = true
                return
            }
        }
    }

    function spawnObject(properties) {
        for (var i = 0; i < asteroidPool.length; i++) {
            var obj = asteroidPool[i]
            if (!obj.visible) {
                obj.isAsteroid = properties.isAsteroid || false
                obj.isPowerup = properties.isPowerup || false
                obj.isInvincibility = properties.isInvincibility || false
                obj.isSpeedBoost = properties.isSpeedBoost || false
                obj.isScoreMultiplier = properties.isScoreMultiplier || false
                obj.isShrink = properties.isShrink || false
                obj.isSlowMo = properties.isSlowMo || false
                obj.passed = false
                obj.dodged = false
                obj.width = obj.isAsteroid ? Dims.l(3) : Dims.l(6)
                obj.height = obj.isAsteroid ? Dims.l(3) : Dims.l(6)
                obj.x = Math.random() * (root.width - obj.width)
                obj.y = -obj.height - (Math.random() * Dims.l(28))
                obj.visible = true
                return
            }
        }
    }

    function isColliding(hitbox, obj) {
        var hitboxCenterX = hitbox.x + playerContainer.x + hitbox.width / 2
        var hitboxCenterY = hitbox.y + playerContainer.y + hitbox.height / 2
        var halfWidth = hitbox.width / 2
        var halfHeight = hitbox.height / 2

        var objCenterX = obj.x + obj.width / 2
        var objCenterY = obj.y + obj.height / 2

        var dx = Math.abs(objCenterX - hitboxCenterX)
        var dy = Math.abs(objCenterY - hitboxCenterY)

        return (dx / halfWidth + dy / halfHeight) <= 1
    }

    function levelUp() {
        asteroidCount = 0
        level++
        scrollSpeed += 0.1
        savedScrollSpeed = scrollSpeed
        flashOverlay.triggerFlash("#8B6914")
    }

    function restartGame() {
        score = 0
        lives = 2
        level = 1
        asteroidCount = 0
        scrollSpeed = 1.6
        savedScrollSpeed = scrollSpeed
        asteroidDensity = 0.044
        gameOver = false
        paused = false
        playerHit = false
        invincible = false
        playerSpeed = basePlayerSpeed
        calibrating = false
        calibrationTimer = 5
        showingNow = false
        showingSurvive = false
        comboCount = 0
        comboActive = false
        lastDodgeTime = 0
        scoreMultiplier = 1.0
        scoreMultiplierElapsed = 0
        preSlowSpeed = 0
        isSlowMoActive = false
        isSpeedBoostActive = false
        isShrinkActive = false
        player.width = Dims.l(10)
        player.height = Dims.l(10)
        playerHitbox.width = Dims.l(14)
        playerHitbox.height = Dims.l(14)
        clearPowerupBars()
        nowText.font.pixelSize = Dims.l(13)
        nowText.opacity = 0
        surviveText.font.pixelSize = Dims.l(13)
        surviveText.opacity = 0
        playerContainer.x = root.width / 2 - player.width / 2
        gameOverScreen.opacity = 0
        lastFrameTime = 0

        for (var i = 0; i < asteroidPool.length; i++) {
            asteroidPool[i].visible = false
            asteroidPool[i].y = -asteroidPool[i].height
        }
        for (i = 0; i < largeAsteroidPool.length; i++) {
            largeAsteroidPool[i].visible = false
            largeAsteroidPool[i].y = -largeAsteroidPool[i].height
        }

        var spawnTimer = Qt.createQmlObject('
            import QtQuick 2.15
            Timer {
                interval: 200
                repeat: true
                running: true
                property int count: 0
                onTriggered: {
                    if (count < 5) {
                        spawnObject({isAsteroid: true})
                    }
                    if (count < 3) {
                        spawnLargeAsteroid()
                    }
                    count++
                    if (count >= 5) {
                        stop()
                        destroy()
                    }
                }
            }
        ', root, "spawnTimer")
    }

    Component.onCompleted: {
        for (var i = 0; i < asteroidPoolSize; i++) {
            var obj = objectComponent.createObject(objectContainer)
            obj.visible = false
            obj.y = -obj.height
            asteroidPool.push(obj)
        }
        for (i = 0; i < largeAsteroidPoolSize; i++) {
            var largeObj = largeAsteroidComponent.createObject(largeAsteroidContainer)
            largeObj.visible = false
            largeObj.y = -largeObj.height
            largeAsteroidPool.push(largeObj)
        }

        calibrating = true
        var spawnTimer = Qt.createQmlObject('
            import QtQuick 2.15
            Timer {
                interval: 200
                repeat: true
                running: true
                property int count: 0
                onTriggered: {
                    if (count < 5) {
                        spawnObject({isAsteroid: true})
                    }
                    if (count < 3) {
                        spawnLargeAsteroid()
                    }
                    count++
                    if (count >= 5) {
                        stop()
                        destroy()
                    }
                }
            }
        ', root, "spawnTimer")
    }
}
