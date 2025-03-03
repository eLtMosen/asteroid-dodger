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
import Nemo.KeepAlive 1.1
import org.nemomobile.systemsettings 1.0

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
    property int shield: 2
    property int level: 1
    property int asteroidsPerLevel: 100
    property real asteroidDensity: 0.044 + (level - 1) * 0.004
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
    property var activeParticles: []
    property bool debugMode: false
    property real lastLargeAsteroidSpawn: 0
    property real lastObjectSpawn: 0
    property int spawnCooldown: 200
    property bool isGraceActive: false
    property bool isInvincibleActive: false

    onPausedChanged: {
        if (paused) {
            savedScrollSpeed = scrollSpeed
            scrollSpeed = 0
            if (comboActive) {
                comboMeterAnimation.pause()
            }
            comboHitboxAnimation.pause()
        } else {
            scrollSpeed = savedScrollSpeed
            if (comboActive) {
                comboMeterAnimation.resume()
            }
            if (scoreMultiplierTimer.running) {
                comboHitboxAnimation.resume()
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

    DisplaySettings {
        id: displaySettings
        onBrightnessChanged: {
            if (startBrightness != -1) {
                return
            }

            startBrightness = brightness
            displaySettings.brightness = displaySettings.maximumBrightness
        }
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
        property real lastFps: 60
        property var fpsHistory: []
        property real lastFpsUpdate: 0
        property real lastGraphUpdate: 0
        onTriggered: {
            var currentTime = Date.now()
            var deltaTime = lastFrameTime > 0 ? (currentTime - lastFrameTime) / 1000 : 0.016
            lastFrameTime = currentTime
            updateGame(deltaTime)
            if (!paused) {
                var deltaX = (accelerometer.reading.x - baselineX) * -2
                var newX = playerContainer.x + deltaX * playerSpeed
                playerContainer.x = Math.max(0, Math.min(root.width - player.width, newX))
            }
            var currentFps = deltaTime > 0 ? 1 / deltaTime : 60
            lastFps = currentFps
            if (debugMode && currentTime - lastFpsUpdate >= 500) {
                lastFpsUpdate = currentTime
                fpsDisplay.text = "FPS: " + Math.round(currentFps)
            }
            if (debugMode && currentTime - lastGraphUpdate >= 500) {
                lastGraphUpdate = currentTime
                var tempHistory = fpsHistory.slice()
                tempHistory.push(currentFps)
                if (tempHistory.length > 10) tempHistory.shift()
                fpsHistory = tempHistory
            }
        }
    }

    Timer {
        id: graceTimer
        interval: 1000
        running: isGraceActive && !paused
        repeat: false
        onTriggered: {
            isGraceActive = false
            invincible = false
            removePowerup("grace")
        }
        onRunningChanged: {
            if (running && !paused) {
                addPowerupBar("grace", 1000, "#FF69B4")
            }
        }
    }

    Timer {
        id: invincibilityTimer
        interval: 10000  // Restored to 10 seconds
        running: isInvincibleActive && !paused
        repeat: false
        onTriggered: {
            isInvincibleActive = false
            invincible = false
            removePowerup("invincibility")
        }
        onRunningChanged: {
            if (running && !paused) {
                addPowerupBar("invincibility", 10000, "#FF69B4")
            }
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
        interval: 100
        running: isShrinkActive && !paused
        repeat: true
        property real elapsed: 0
        onTriggered: {
            elapsed += interval
            var progress = Math.min(1.0, elapsed / 6000)
            player.width = Dims.l(5) + (Dims.l(10) - Dims.l(5)) * progress
            player.height = Dims.l(5) + (Dims.l(10) - Dims.l(5)) * progress
            playerHitbox.width = Dims.l(7) + (Dims.l(14) - Dims.l(7)) * progress
            playerHitbox.height = Dims.l(7) + (Dims.l(14) - Dims.l(7)) * progress
            if (elapsed >= 6000) {
                isShrinkActive = false
                elapsed = 0
                removePowerup("shrink")
                stop()
            }
        }
        onRunningChanged: {
            if (!running && !paused) {
                elapsed = 0
            }
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
                introTimer.phase = 1
                introTimer.start()
            }
        }
    }

    Timer {
        id: introTimer
        interval: 1000
        running: showingNow || showingSurvive
        repeat: true
        property int phase: showingNow ? 1 : showingSurvive ? 2 : 0
        onTriggered: {
            if (phase === 1) {
                showingNow = false
                showingSurvive = true
                surviveTransition.start()
                phase = 2
            } else if (phase === 2) {
                showingSurvive = false
                phase = 0
                stop()
            }
        }
        onRunningChanged: {
            if (!running) {
                phase = 0
            }
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

    Component {
        id: comboParticleComponent
        Text {
            id: particleText
            property int points: 1
            text: "+" + points
            color: {
                if (points <= 10) return "#00CC00"
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
                return "#FF69B4"
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
                    var index = activeParticles.indexOf(particleText)
                    if (index !== -1) {
                        activeParticles.splice(index, 1)
                    }
                    particleText.destroy()
                }
            }
            Component.onCompleted: {
                activeParticles.push(particleText)
                if (activeParticles.length > 4) {
                    var oldestParticle = activeParticles.shift()
                    if (oldestParticle) {
                        oldestParticle.destroy()
                    }
                }
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
                visible: flashAnimation.running
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
                id: objectContainer
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
                        running: (isGraceActive || isInvincibleActive) && !root.paused
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

                    SequentialAnimation on opacity {
                        id: comboHitboxAnimation
                        running: scoreMultiplierTimer.running && !root.paused
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.2; to: 0.4; duration: 500; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.4; to: 0.2; duration: 500; easing.type: Easing.InOutSine }
                        onStopped: {
                            comboHitbox.opacity = 0.2
                        }
                    }
                }
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


            Text {
                id: levelNumber
                text: level
                color: "#dddddd"
                font.pixelSize: Dims.l(4)
                font.bold: true
                anchors {
                    top: root.top
                    horizontalCenter: parent.horizontalCenter
                }
                z: 4
                visible: !gameOver && !calibrating && !showingNow && !showingSurvive
            }

            Item {
                id: shieldProgressBar
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                    bottomMargin: Dims.l(4)
                }
                width: Dims.l(28)
                height: Dims.l(2)
                visible: !gameOver && !calibrating && !showingNow && !showingSurvive
                z: 4

                Rectangle {
                    width: parent.width
                    height: parent.height
                    radius: Dims.l(1)
                    color: "#8B6914"
                    opacity: 0.5
                }

                Rectangle {
                    id: shieldFill
                    width: (shield / 20) * parent.width
                    height: parent.height
                    color: "#0000FF"
                    radius: Dims.l(1)
                    opacity: 0.5
                }
            }

            Text {
                id: shieldText
                text: shield === 1 ? "❤️" : shield
                color: shield === 1 ? "red" : "#FFFFFF"  // White when blinking starts, blue otherwise
                font.pixelSize: shield === 1 ? Dims.l(6) : Dims.l(4)  // Base size
                font.bold: true
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                }
                z: 4
                visible: !gameOver && !calibrating && !showingNow && !showingSurvive

                SequentialAnimation {
                    running: shield === 1 && !root.paused && !gameOver
                    loops: Animation.Infinite
                    ParallelAnimation {
                        ColorAnimation {  // Replaced NumberAnimation for color
                            target: shieldText
                            property: "color"
                            from: "white"
                            to: "#00FFFF"  // Bright blue
                            duration: 500
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            target: shieldText
                            property: "font.pixelSize"
                            from: Dims.l(6)
                            to: Dims.l(8)  // +2 size
                            duration: 500
                            easing.type: Easing.InOutSine
                        }
                    }
                    ParallelAnimation {
                        ColorAnimation {  // Replaced NumberAnimation for color
                            target: shieldText
                            property: "color"
                            from: "#00FFFF"
                            to: "white"
                            duration: 500
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            target: shieldText
                            property: "font.pixelSize"
                            from: Dims.l(8)
                            to: Dims.l(6)  // Back to original
                            duration: 500
                            easing.type: Easing.InOutSine
                        }
                    }
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
                font.pixelSize: Dims.l(12)
                anchors.centerIn: parent
                opacity: 0
                visible: !gameOver && !calibrating && !showingNow && !showingSurvive
                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.InOutQuad
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !gameOver && !calibrating && !showingNow && !showingSurvive
                    onClicked: {
                        paused = !paused
                        pauseText.opacity = paused ? 1.0 : 0.0
                    }
                }
            }

            Text {
                id: fpsDisplay
                text: "FPS: 60"
                color: "white"
                opacity: 0.5
                font.pixelSize: Dims.l(10)
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: fpsGraph.top
                }
                visible: debugMode && !gameOver && !calibrating && !showingNow && !showingSurvive
            }

            Rectangle {
                id: fpsGraph
                width: Dims.l(30)
                height: Dims.l(10)
                color: "#00000000"
                opacity: 0.5
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: debugToggle.top
                    topMargin: Dims.l(3)
                }
                visible: debugMode && !gameOver && !calibrating && !showingNow && !showingSurvive

                Row {
                    anchors.fill: parent
                    spacing: 0
                    Repeater {
                        model: 10
                        Rectangle {
                            width: fpsGraph.width / 10
                            height: {
                                var fps = index < gameTimer.fpsHistory.length ? gameTimer.fpsHistory[index] : 0
                                return Math.min(Dims.l(10), Math.max(0, (fps / 60) * Dims.l(10)))
                            }
                            color: {
                                var fps = index < gameTimer.fpsHistory.length ? gameTimer.fpsHistory[index] : 0
                                if (fps > 60) return "green"
                                else if (fps >= 50) return "orange"
                                else return "red"
                            }
                        }
                    }
                }
            }

            Text {
                id: debugToggle
                text: "Debug"
                color: "white"
                opacity: debugMode ? 1 : 0.5
                font.pixelSize: Dims.l(10)
                font.bold: debugMode
                anchors {
                    bottom: pauseText.top
                    horizontalCenter: parent.horizontalCenter
                    bottomMargin: Dims.l(4)
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.InOutQuad
                    }
                }
                visible: paused && !gameOver && !calibrating && !showingNow && !showingSurvive
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        debugMode = !debugMode
                    }
                }
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
                else {
                    opacity = 0
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
                        enabled: gameOver
                        onClicked: {
                            restartGame()
                            gameOver = false
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
    }

    function addPowerupBar(type, duration, color) {
        var existingIndex = activePowerups.findIndex(function(p) { return p.type === type })
        if (existingIndex !== -1) {
            var existing = activePowerups[existingIndex]
            if (existing.bar) {
                existing.bar.progress = 1.0
                existing.bar.startTimer()
            }
            return
        }

        var bar = progressBarComponent.createObject(powerupBars, {
            "fillColor": color,
            "duration": duration,
            "progress": 1.0
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
            }
        }
        for (i = 0; i < asteroidPool.length; i++) {
            var obj = asteroidPool[i]
            if (obj.visible) {
                obj.y += adjustedScrollSpeed
            }
        }

        for (i = 0; i < largeAsteroidPool.length; i++) {
            var largeObj = largeAsteroidPool[i]
            if (largeObj.visible && largeObj.y >= root.height) {
                largeObj.visible = false
            }
        }

        for (i = 0; i < asteroidPool.length; i++) {
            var obj = asteroidPool[i]
            if (obj.visible) {
                var objCenterX = obj.x + obj.width / 2
                var objCenterY = obj.y + obj.height / 2

                if (obj.x + obj.width >= playerContainer.x - Dims.l(5) &&
                    obj.x <= playerContainer.x + playerHitbox.width + Dims.l(5) &&
                    obj.y + obj.height >= playerContainer.y - Dims.l(5) &&
                    obj.y <= playerContainer.y + playerHitbox.height + Dims.l(5)) {
                    var dx = objCenterX - playerCenterX
                    var dy = objCenterY - playerCenterY
                    var distanceSquared = dx * dx + dy * dy

                    if (distanceSquared < maxDistanceSquared) {
                        if (obj.isAsteroid && isColliding(playerHitbox, obj) && !invincible) {
                            shield--
                            if (shield <= 0) {
                                gameOver = true
                                shield = 0
                                flashOverlay.triggerFlash("red")
                                comboCount = 0
                                comboActive = false
                                comboTimer.stop()
                                comboMeterAnimation.stop()
                                obj.visible = false
                                feedback.play()
                                continue
                            }
                            flashOverlay.triggerFlash("red")
                            comboCount = 0
                            comboActive = false
                            comboTimer.stop()
                            comboMeterAnimation.stop()
                            invincible = true
                            isGraceActive = true  // Trigger grace period
                            graceTimer.restart()
                            obj.visible = false
                            feedback.play()
                            continue
                        }

                        if (obj.isPowerup && isColliding(playerHitbox, obj)) {
                            shield = Math.min(20, shield + 1)
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
                            isInvincibleActive = true  // Trigger invincibility power-up
                            invincibilityTimer.restart()
                            flashOverlay.triggerFlash("#FF69B4")
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
                            flashOverlay.triggerFlash("#FFA500")
                            addPowerupBar("shrink", 6000, "#FFA500")
                            comboCount = 0
                            comboActive = false
                            comboTimer.stop()
                            comboMeterAnimation.stop()
                            obj.visible = false
                            continue
                        }

                        if (obj.isSlowMo && isColliding(playerHitbox, obj)) {
                            if (!isSlowMoActive) {
                                preSlowSpeed = scrollSpeed
                                scrollSpeed = preSlowSpeed / 2
                            }
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
                }

                if (obj.isAsteroid && (obj.y + obj.height / 2) > (playerContainer.y + player.height / 2) && !obj.passed) {
                    asteroidCount++
                    obj.passed = true
                    if (obj.x + obj.width >= playerContainer.x - comboHitbox.width / 2 - Dims.l(5) &&
                        obj.x <= playerContainer.x + comboHitbox.width / 2 + Dims.l(5) &&
                        obj.y + obj.height >= playerContainer.y - comboHitbox.height / 2 - Dims.l(5) &&
                        obj.y <= playerContainer.y + comboHitbox.height / 2 + Dims.l(5)) {
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
                    } else {
                        score += 1 * scoreMultiplier
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

        var currentTime = Date.now()
        if (!paused && currentTime - lastLargeAsteroidSpawn >= spawnCooldown && Math.random() < largeAsteroidDensity / 2) {
            spawnLargeAsteroid()
            lastLargeAsteroidSpawn = currentTime
        }

        if (!paused && currentTime - lastObjectSpawn >= spawnCooldown && Math.random() < asteroidDensity) {
            var isAsteroid = Math.random() < 0.96
            spawnObject(isAsteroid ? {isAsteroid: true} : {isAsteroid: false, isPowerup: true})
            lastObjectSpawn = currentTime
        }

        if (!paused && currentTime - lastObjectSpawn >= spawnCooldown && Math.random() < 0.0001) {
            spawnObject({isAsteroid: false, isInvincibility: true})
            lastObjectSpawn = currentTime
        }

        if (!paused && currentTime - lastObjectSpawn >= spawnCooldown && Math.random() < 0.0005) {
            spawnObject({isAsteroid: false, isSpeedBoost: true})
            lastObjectSpawn = currentTime
        }

        if (!paused && currentTime - lastObjectSpawn >= spawnCooldown && Math.random() < 0.0005) {
            spawnObject({isAsteroid: false, isScoreMultiplier: true})
            lastObjectSpawn = currentTime
        }

        if (!paused && currentTime - lastObjectSpawn >= spawnCooldown && Math.random() < 0.0005) {
            spawnObject({isAsteroid: false, isShrink: true})
            lastObjectSpawn = currentTime
        }

        if (!paused && currentTime - lastObjectSpawn >= spawnCooldown && Math.random() < 0.0003) {
            spawnObject({isAsteroid: false, isSlowMo: true})
            lastObjectSpawn = currentTime
        }
    }

    function spawnLargeAsteroid() {
        for (var i = 0; i < largeAsteroidPool.length; i++) {
            var obj = largeAsteroidPool[i]
            if (!obj.visible) {
                obj.x = Math.random() * (root.width - obj.width)
                obj.y = -obj.height - (Math.random() * Dims.l(28))
                obj.visible = true
                return
            }
        }
    }

    function spawnObject(properties) {
        for (var i = 0; i < asteroidPool.length; i++) {
            var obj = asteroidPool[i]
            if (!obj.visible) {
                if (obj.isAsteroid !== (properties.isAsteroid || false)) {
                    obj.isAsteroid = properties.isAsteroid || false
                    obj.isPowerup = properties.isPowerup || false
                    obj.isInvincibility = properties.isInvincibility || false
                    obj.isSpeedBoost = properties.isSpeedBoost || false
                    obj.isScoreMultiplier = properties.isScoreMultiplier || false
                    obj.isShrink = properties.isShrink || false
                    obj.isSlowMo = properties.isSlowMo || false
                }
                obj.x = Math.random() * (root.width - obj.width)
                obj.y = -obj.height - (Math.random() * Dims.l(28))
                obj.visible = true
                if (obj.passed) obj.passed = false
                if (obj.dodged) obj.dodged = false
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
        shield = 2
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
            asteroidPool[i].y = -asteroidPool[i].height - (Math.random() * Dims.l(28))
            asteroidPool[i].x = Math.random() * (root.width - asteroidPool[i].width)
            asteroidPool[i].passed = false
            asteroidPool[i].dodged = false
        }
        for (i = 0; i < largeAsteroidPool.length; i++) {
            largeAsteroidPool[i].visible = false
            largeAsteroidPool[i].y = -largeAsteroidPool[i].height - (Math.random() * Dims.l(28))
            largeAsteroidPool[i].x = Math.random() * (root.width - largeAsteroidPool[i].width)
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

        DisplayBlanking.preventBlanking = true

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

    Component.onDestruction: displaySettings.brightness = startBrightness
}
