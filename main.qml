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

Item {
    id: root
    anchors.fill: parent
    visible: true

    // --- Game Mechanics ---
    property bool initializationComplete: false
    property bool calibrating: false
    property int calibrationTimer: 5
    property bool comboActive: false
    property int comboCount: 0
    property real closePassThreshold: dimsFactor * 10
    property bool debugMode: false
    property bool gameOver: false
    property bool invincible: false
    property bool isGraceActive: false
    property bool isInvincibleActive: false
    property bool isShrinkActive: false
    property bool isSlowMoActive: false
    property bool isSpeedBoostActive: false
    property real lastDodgeTime: 0
    property int level: 1
    property bool paused: false
    property bool playerHit: false
    property int score: 0
    property real scoreMultiplier: 1.0
    property real scoreMultiplierElapsed: 0
    property int shield: 2
    property bool showingNow: false
    property bool showingSurvive: false
    property bool isAutoFireActive: false  // AutoFire active state
    property real autoFireElapsed: 0       // Track AutoFire duration

    // --- Object Spawning and Pools ---
    property var activeLaser: null
    property var activeParticles: []
    property var activePowerups: []
    property var activeShots: []  // New: Track AutoFire shots
    property int asteroidCount: 0
    property real asteroidDensity: 0.08 + (level - 1) * 0.02
    property var asteroidPool: []
    property int asteroidPoolSize: 40
    property int asteroidsPerLevel: 100
    property real largeAsteroidDensity: asteroidDensity / 3
    property var largeAsteroidPool: []
    property int largeAsteroidPoolSize: 10
    property real lastAsteroidSpawn: 0
    property real lastLargeAsteroidSpawn: 0
    property real lastLaserSwipeSpawn: 0
    property real lastObjectSpawn: 0
    property int spawnCooldown: Math.max(100, 200 - (level - 1) * 2)

    // --- Visual and Timing Settings ---
    property real baselineX: 0
    property real dimsFactor: Dims.l(100) / 100
    property string flashColor: ""
    property real lastFrameTime: 0
    property real playerSpeed: basePlayerSpeed
    property real basePlayerSpeed: 1.2
    property real preSlowSpeed: 0
    property real savedScrollSpeed: 0
    property real scrollSpeed: 1.6

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

    Item {
        id: preloader
        anchors.fill: parent
        visible: false  // Hidden, only for preloading

        Rectangle {
            id: preloadFlash
            anchors.fill: parent
            SequentialAnimation {
                id: preloadFlashAnimation
                NumberAnimation {
                    target: preloadFlash
                    property: "opacity"
                    from: 0.5
                    to: 0
                    duration: 500
                    easing.type: Easing.OutQuad
                }
                onStopped: {
                    preloadFlash.opacity = 0
                }
            }
        }

        Image {
            id: preloadPlayer
            width: dimsFactor * 10
            height: dimsFactor * 10
            source: "file:///usr/share/asteroid-launcher/watchfaces-img/asteroid-logo.svg"
            SequentialAnimation on opacity {
                NumberAnimation { from: 1.0; to: 0.2; duration: 500; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.2; to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                onStopped: {
                    preloadPlayer.opacity = 1.0
                }
            }
        }

        NonGraphicalFeedback {
            id: preloadFeedback
            event: "short"
        }

        Component.onCompleted: {
            preloadFlashAnimation.start()
            preloadFeedback.play()
        }
    }

    Component {
        id: progressBarComponent
        Item {
            id: progressBar
            property real progress: 1.0
            property string fillColor: "#FFD700"
            property string bgColor: "#45220A"
            property int duration: 0
            property var timer: null
            width: dimsFactor * 28
            height: dimsFactor * 2

            Rectangle {
                width: parent.width
                height: parent.height
                radius: dimsFactor * 1
                color: bgColor
                opacity: 1.0
            }

            Rectangle {
                id: fill
                width: parent.width * progress
                height: parent.height
                color: fillColor
                radius: dimsFactor * 1
                opacity: 1.0
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
        property real smoothedX: 0
        property real smoothingFactor: 0.5

        onTriggered: {
            var currentTime = Date.now()
            var deltaTime = lastFrameTime > 0 ? (currentTime - lastFrameTime) / 1000 : 0.016
            if (deltaTime > 0.033) deltaTime = 0.033  // Cap at ~30 FPS
            lastFrameTime = currentTime
            updateGame(deltaTime)

            if (!paused) {
                var rawX = accelerometer.reading.x
                smoothedX = smoothedX + smoothingFactor * (rawX - smoothedX)
                var deltaX = (smoothedX - baselineX) * -2
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
        interval: 2000
        running: isGraceActive && !paused
        repeat: false
        onTriggered: {
            isGraceActive = false
            invincible = false
            removePowerup("grace")
        }
        onRunningChanged: {
            if (running && !paused) {
                addPowerupBar("grace", 2000, "#FF69B4", "#8B374F")
            }
        }
    }

    Timer {
        id: invincibilityTimer
        interval: 10000
        running: isInvincibleActive && !paused
        repeat: false
        onTriggered: {
            isInvincibleActive = false
            invincible = false
            removePowerup("invincibility")
        }
        onRunningChanged: {
            if (running && !paused) {
                addPowerupBar("invincibility", 10000, "#FF69B4", "#8B374F")
            }
        }
    }

    Timer {
        id: speedBoostTimer
        interval: 6000
        running: isSpeedBoostActive && !paused
        repeat: false
        onTriggered: {
            playerSpeed = basePlayerSpeed
            isSpeedBoostActive = false
            removePowerup("speedBoost")
        }
        onRunningChanged: {
            if (running && !paused) {
                addPowerupBar("speedBoost", 6000, "#FFFF00", "#8B8B00")
            }
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
        onRunningChanged: {
            if (running && !paused) {
                addPowerupBar("scoreMultiplier", 10000, "#00CC00", "#006600")
            }
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
        onRunningChanged: {
            if (running && !paused) {
                addPowerupBar("slowMo", 6000, "#00FFFF", "#008B8B")
            }
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
            player.width = dimsFactor * 5 + (dimsFactor * 10 - dimsFactor * 5) * progress
            player.height = dimsFactor * 5 + (dimsFactor * 10 - dimsFactor * 5) * progress
            playerHitbox.width = dimsFactor * 7 + (dimsFactor * 14 - dimsFactor * 7) * progress
            playerHitbox.height = dimsFactor * 7 + (dimsFactor * 14 - dimsFactor * 7) * progress
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
            if (running && !paused) {
                addPowerupBar("shrink", 6000, "#FFA500", "#8B5A00")
            }
        }
    }

    Timer {
        id: calibrationCountdownTimer
        interval: 1000
        running: calibrating
        repeat: true
        property bool initializationDone: false  // Track loading completion
        onTriggered: {
            calibrationTimer--
            if (calibrationTimer <= 0 && initializationDone) {
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

    Timer {
        id: autoFireTimer
        interval: 6000 / 30  // ~200ms per shot
        running: isAutoFireActive && !paused
        repeat: true
        property int shotCount: 0
        onTriggered: {
            if (shotCount < 30) {
                var shot = autoFireShotComponent.createObject(gameArea, {
                    "x": playerContainer.x + playerHitbox.x + playerHitbox.width / 2 - dimsFactor * 0.5,
                    "y": playerContainer.y + playerHitbox.y
                })
                activeShots.push(shot)
                shotCount++
            }
            if (shotCount >= 30) {
                isAutoFireActive = false
                shotCount = 0
                stop()
                removePowerup("autoFire")
            }
        }
        onRunningChanged: {
            if (running && !paused) {
                addPowerupBar("autoFire", 6000, "#800080", "#4B004B")
                shotCount = 0
            }
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
                if (points <= 10) return dimsFactor * 4
                if (points <= 20) {
                    var t = (points - 10) / 10
                    return (dimsFactor * 4 + t * (dimsFactor * 5 - dimsFactor * 4))
                }
                if (points <= 40) {
                    var t = (points - 20) / 20
                    return (dimsFactor * 5 + t * (dimsFactor * 6 - dimsFactor * 5))
                }
                if (points <= 100) {
                    var t = (points - 40) / 60
                    return (dimsFactor * 6 + t * (dimsFactor * 7 - dimsFactor * 6))
                }
                return dimsFactor * 7
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
                        to: x + (x < playerContainer.x ? -dimsFactor * 8 : dimsFactor * 8)
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: particleText
                        property: "y"
                        to: y - dimsFactor * 7
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: particleText
                        property: "y"
                        to: y + dimsFactor * 11
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

    Component {
        id: laserSwipeComponent
        Rectangle {
            id: laserRect
            width: root.width
            height: dimsFactor * 1
            color: "red"
            x: 0
            y: playerContainer ? playerContainer.y : root.height * 0.75  // Start at player position
            z: 2
            visible: true

            PropertyAnimation {
                id: laserAnimation
                target: laserRect
                property: "y"
                from: laserRect.y
                to: -laserRect.height
                duration: 1000  // 1 second sweep
                running: true
                onStopped: {
                    if (root.activeLaser === laserRect) {
                        root.activeLaser = null
                    }
                    destroyTimer.start()
                }
            }

            Timer {
                id: destroyTimer
                interval: 1
                repeat: false
                onTriggered: {
                    parent.destroy()
                }
            }
        }
    }

    Component {
        id: autoFireShotComponent
        Rectangle {
            width: dimsFactor * 1
            height: dimsFactor * 5
            color: "#800080"
            z: 2
            visible: true
            property real speed: scrollSpeed * 5
        }
    }

    Item {
        id: gameArea
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "black"
            layer.enabled: true
            clip: true
        }

        Rectangle {
            id: flashOverlay
            anchors.fill: parent
            color: flashColor ? flashColor : "transparent"
            opacity: 0
            visible: opacity > 0
            property string flashColor: ""
            function triggerFlash(color) {
                flashColor = color
                flashAnimation.restart()
            }
            NumberAnimation {
                id: flashAnimation
                target: flashOverlay
                property: "opacity"
                from: 0.5
                to: 0
                duration: flashOverlay.flashColor === "#8B6914" || flashOverlay.flashColor === "#00FFFF" ? 6000 : 500
                easing.type: Easing.OutQuad
            }
        }

        Item {
            id: gameContent
            anchors.fill: parent

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
                    width: dimsFactor * 10
                    height: dimsFactor * 10
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
                    width: dimsFactor * 14
                    height: dimsFactor * 14
                    anchors.centerIn: parent
                    visible: false

                    ShapePath {
                        strokeWidth: -1
                        fillColor: "transparent"
                        startX: dimsFactor * 7; startY: 0
                        PathLine { x: dimsFactor * 14; y: dimsFactor * 7 }
                        PathLine { x: dimsFactor * 7; y: dimsFactor * 14 }
                        PathLine { x: 0; y: dimsFactor * 7 }
                        PathLine { x: dimsFactor * 7; y: 0 }
                    }
                }

                Shape {
                    id: comboHitbox
                    width: dimsFactor * 40
                    height: dimsFactor * 40
                    anchors.centerIn: parent
                    visible: comboActive
                    opacity: 0.2

                    ShapePath {
                        strokeWidth: dimsFactor * 1
                        strokeColor: "#00CC00"
                        fillColor: "transparent"
                        startX: dimsFactor * 20; startY: dimsFactor * 10
                        PathLine { x: dimsFactor * 30; y: dimsFactor * 20 }
                        PathLine { x: dimsFactor * 20; y: dimsFactor * 30 }
                        PathLine { x: dimsFactor * 10; y: dimsFactor * 20 }
                        PathLine { x: dimsFactor * 20; y: dimsFactor * 10 }
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
                    topMargin: dimsFactor * 6
                }
                z: 4
                visible: !gameOver && !calibrating && !showingNow && !showingSurvive

                Item {
                    id: levelProgressBar
                    width: dimsFactor * 28
                    height: dimsFactor * 2
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: parent.width
                        height: parent.height
                        radius: dimsFactor * 1
                        color: "#45220A"
                        opacity: 1.0
                    }

                    Rectangle {
                        id: progressFill
                        width: (asteroidCount / asteroidsPerLevel) * parent.width
                        height: parent.height
                        color: "#FFD700"
                        radius: dimsFactor * 1
                        opacity: 1.0
                    }
                }

                Column {
                    id: powerupBars
                    anchors {
                        top: levelProgressBar.bottom
                        topMargin: dimsFactor * 1
                        horizontalCenter: parent.horizontalCenter
                    }
                    spacing: dimsFactor * 1
                }
            }

            Text {
                id: levelNumber
                text: level
                color: "#dddddd"
                font.pixelSize: dimsFactor * 9
                font.family: "Fyodor"
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
                    bottomMargin: dimsFactor * 4
                }
                width: dimsFactor * 28
                height: dimsFactor * 2
                visible: !gameOver && !calibrating && !showingNow && !showingSurvive
                z: 4

                Rectangle {
                    width: parent.width
                    height: parent.height
                    radius: dimsFactor * 1
                    color: "#002346"
                    opacity: 1.0
                }

                Rectangle {
                    id: shieldFill
                    width: (shield / 10) * parent.width
                    height: parent.height
                    color: "#0087FF"
                    radius: dimsFactor * 1
                    opacity: 1.0
                }
            }

            Text {
                id: shieldText
                text: shield === 1 ? "❤️" : shield
                color: shield === 1 ? "red" : "#FFFFFF"
                font.pixelSize: shield === 1 ? dimsFactor * 8 : dimsFactor * 8  // Static size
                font.family: "Fyodor"
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                }
                z: 4
                visible: !gameOver && !calibrating && !showingNow && !showingSurvive
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
                    value: playerContainer.y + playerContainer.height + dimsFactor * 6
                    when: !gameOver && !paused && !calibrating && !showingNow && !showingSurvive
                }

                Rectangle {
                    id: comboMeter
                    property int maxWidth: dimsFactor * 13
                    height: dimsFactor * 1
                    width: 0
                    color: "green"
                    radius: height / 2
                    x: (scoreText.width - width) / 2
                    y: -height + dimsFactor * 1
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
                    font.pixelSize: dimsFactor * 5
                    font.bold: scoreMultiplierTimer.running
                }
            }

            Item {
                id: titleText
                anchors {
                    top: parent.top
                    topMargin: dimsFactor * 4
                    horizontalCenter: parent.horizontalCenter
                }
                z: 4
                visible: calibrating

                Text {
                    text: "v1.4\nAsteroid Dodger"
                    color: "#dddddd"
                    font.family: "Fyodor"
                    font.pixelSize: dimsFactor * 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Item {
                id: calibrationContainer
                anchors.fill: parent
                visible: calibrating

                Column {
                    id: calibrationText
                    anchors {
                        verticalCenter: parent.verticalCenter
                        horizontalCenter: parent.horizontalCenter
                    }
                    spacing: dimsFactor * 1
                    opacity: showingNow ? 0 : 1
                    Behavior on opacity {
                        NumberAnimation { duration: 500; easing.type: Easing.InOutQuad }
                    }
                    Text {
                        text: "Calibrating"
                        color: "white"
                        font.pixelSize: dimsFactor * 9
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: "Hold your watch comfy"
                        color: "white"
                        font.pixelSize: dimsFactor * 6
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: calibrationTimer + "s"
                        color: "white"
                        font.pixelSize: dimsFactor * 9
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: calibrating
                    onClicked: {
                        baselineX = accelerometer.reading.x
                        calibrating = false
                        calibrationCountdownTimer.stop()
                        showingNow = true
                        feedback.play()
                        nowTransition.start()
                        introTimer.phase = 1
                        introTimer.start()
                    }
                }
            }

            Text {
                id: nowText
                text: "NOW"
                color: "white"
                font.pixelSize: dimsFactor * 24
                font.family: "Fyodor"
                anchors.centerIn: parent
                visible: showingNow
                opacity: 0
                SequentialAnimation {
                    id: nowTransition
                    running: false
                    NumberAnimation { target: nowText; property: "opacity"; from: 0; to: 1; duration: 500 }
                    ParallelAnimation {
                        NumberAnimation { target: nowText; property: "font.pixelSize"; from: dimsFactor * 24; to: dimsFactor * 48; duration: 1000; easing.type: Easing.OutQuad }
                        NumberAnimation { target: nowText; property: "opacity"; from: 1; to: 0; duration: 1000; easing.type: Easing.OutQuad }
                    }
                }
            }

            Text {
                id: surviveText
                text: "SURVIVE"
                color: "orange"
                font.pixelSize: dimsFactor * 24
                font.family: "Fyodor"
                anchors.centerIn: parent
                visible: showingSurvive
                opacity: 0
                SequentialAnimation {
                    id: surviveTransition
                    running: false
                    NumberAnimation { target: surviveText; property: "opacity"; from: 0; to: 1; duration: 500 }
                    ParallelAnimation {
                        NumberAnimation { target: surviveText; property: "font.pixelSize"; from: dimsFactor * 24; to: dimsFactor * 48; duration: 1000; easing.type: Easing.OutQuad }
                        NumberAnimation { target: surviveText; property: "opacity"; from: 1; to: 0; duration: 1000; easing.type: Easing.OutQuad }
                    }
                }
            }

            Text {
                id: pauseText
                text: "Paused"
                color: "white"
                font.pixelSize: dimsFactor * 22
                font.family: "Fyodor"
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
                font.pixelSize: dimsFactor * 10
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: fpsGraph.top
                }
                visible: debugMode && !gameOver && !calibrating && !showingNow && !showingSurvive
            }

            Rectangle {
                id: fpsGraph
                width: dimsFactor * 30
                height: dimsFactor * 10
                color: "#00000000"
                opacity: 0.5
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: debugToggle.top
                    topMargin: dimsFactor * 3
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
                                return Math.min(dimsFactor * 10, Math.max(0, (fps / 60) * dimsFactor * 10))
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
                font.pixelSize: dimsFactor * 10
                font.bold: debugMode
                anchors {
                    bottom: pauseText.top
                    horizontalCenter: parent.horizontalCenter
                    bottomMargin: dimsFactor * 4
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
                } else {
                    opacity = 0
                }
            }

            Column {
                spacing: Math.round(dimsFactor * 6 * 1.2)
                anchors.centerIn: parent

                Text {
                    id: gameOverText
                    text: "Game Over!"
                    color: "red"
                    font.pixelSize: Math.round(dimsFactor * 8 * 1.2)
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Column {
                    spacing: Math.round(dimsFactor * 1 * 1.2)
                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        spacing: Math.round(dimsFactor * 2 * 1.2)
                        Text { text: "Score"; color: "#dddddd"; font.pixelSize: Math.round(dimsFactor * 4 * 1.2); width: Math.round(dimsFactor * 22 * 1.2); horizontalAlignment: Text.AlignHCenter }
                        Text { text: score; color: "white"; font.pixelSize: Math.round(dimsFactor * 5 * 1.2); font.bold: true; width: Math.round(dimsFactor * 11 * 1.2); horizontalAlignment: Text.AlignHCenter }
                    }
                    Row {
                        spacing: Math.round(dimsFactor * 2 * 1.2)
                        Text { text: "Level"; color: "#dddddd"; font.pixelSize: Math.round(dimsFactor * 4 * 1.2); width: Math.round(dimsFactor * 22 * 1.2); horizontalAlignment: Text.AlignHCenter }
                        Text { text: level; color: "white"; font.pixelSize: Math.round(dimsFactor * 5 * 1.2); font.bold: true; width: Math.round(dimsFactor * 11 * 1.2); horizontalAlignment: Text.AlignHCenter }
                    }
                    Row {
                        spacing: Math.round(dimsFactor * 2 * 1.2)
                        Text { text: "High Score"; color: "#dddddd"; font.pixelSize: Math.round(dimsFactor * 4 * 1.2); width: Math.round(dimsFactor * 22 * 1.2); horizontalAlignment: Text.AlignHCenter }
                        Text { text: highScore.value; color: "white"; font.pixelSize: Math.round(dimsFactor * 5 * 1.2); font.bold: true; width: Math.round(dimsFactor * 11 * 1.2); horizontalAlignment: Text.AlignHCenter }
                    }
                    Row {
                        spacing: Math.round(dimsFactor * 2 * 1.2)
                        Text { text: "Max Level"; color: "#dddddd"; font.pixelSize: Math.round(dimsFactor * 4 * 1.2); width: Math.round(dimsFactor * 22 * 1.2); horizontalAlignment: Text.AlignHCenter }
                        Text { text: highLevel.value; color: "white"; font.pixelSize: Math.round(dimsFactor * 5 * 1.2); font.bold: true; width: Math.round(dimsFactor * 11 * 1.2); horizontalAlignment: Text.AlignHCenter }
                    }
                }

                Rectangle {
                    id: tryAgainButton
                    width: Math.round(dimsFactor * 42 * 1.2)
                    height: Math.round(dimsFactor * 14 * 1.2)
                    color: "green"
                    border.color: "white"
                    border.width: Math.round(dimsFactor * 1 * 1.2)
                    radius: Math.round(dimsFactor * 3 * 1.2)
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "Die Again"
                        color: "white"
                        font.pixelSize: Math.round(dimsFactor * 6 * 1.2)
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
                width: dimsFactor * (8 + Math.random() * 12)
                height: width
                x: Math.random() * (root.width - width)
                y: -height - (Math.random() * dimsFactor * 28)
                color: {
                    var t = Math.random()
                    var r = Math.round((0x0e + t * (0x2a - 0x0e)) * 0.42)
                    var g = Math.round((0x00 + t * (0x00 - 0x00)) * 0.42)
                    var b = Math.round((0x3d + t * (0x9b - 0x3d)) * 0.42)
                    return Qt.rgba(r / 255, g / 255, b / 255, 1)
                }
                opacity: 1.0
                radius: dimsFactor * 50
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
            property bool isLaserSwipe: false
            property bool isAutoFire: false
            property bool passed: false
            property bool dodged: false
            width: isAsteroid ? dimsFactor * 3 : dimsFactor * 6
            height: isAsteroid ? dimsFactor * 3 : dimsFactor * 6
            x: Math.random() * (root.width - width)
            y: -height - (Math.random() * dimsFactor * 28)
            visible: false

            Shape {
                id: asteroidShape
                visible: isAsteroid && !dodged
                property real sizeFactor: 0.8 + Math.random() * 0.4
                width: dimsFactor * 3 * sizeFactor
                height: dimsFactor * 3 * sizeFactor
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
                font.pixelSize: dimsFactor * 4
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
                    if (isLaserSwipe) return "red"
                    if (isAutoFire) return "#800080"
                    return "#0087ff"
                }
                font.pixelSize: dimsFactor * 6
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

    function addPowerupBar(type, duration, color, bgColor) {
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
            "bgColor": bgColor,
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
        if (!playerContainer || !playerHitbox || !gameArea) return

        var adjustedScrollSpeed = scrollSpeed * deltaTime * 60
        var largeAsteroidSpeed = adjustedScrollSpeed / 3
        var currentTime = Date.now()
        var coarseRange = root.height  // Only check objects within screen height

        var playerCenterX = playerContainer.x + playerHitbox.x + playerHitbox.width / 2
        var playerCenterY = playerContainer.y + playerHitbox.y + playerHitbox.height / 2
        var comboCenterX = playerContainer.x + comboHitbox.x + comboHitbox.width / 2
        var comboCenterY = playerContainer.y + comboHitbox.y + comboHitbox.height / 2
        var maxDistanceSquared = (playerHitbox.width + dimsFactor * 5) * (playerHitbox.width + dimsFactor * 5)
        var comboDistanceSquared = (comboHitbox.width + dimsFactor * 5) * (comboHitbox.width + dimsFactor * 5)

        // Update shots efficiently
        for (var i = activeShots.length - 1; i >= 0; i--) {
            var shot = activeShots[i]
            if (shot) {
                shot.y -= shot.speed * deltaTime * 60
                if (shot.y <= -shot.height) {
                    shot.destroy()
                    activeShots.splice(i, 1)
                }
            }
        }

        // Move large asteroids (single pass)
        for (i = largeAsteroidPool.length - 1; i >= 0; i--) {
            var largeObj = largeAsteroidPool[i]
            if (largeObj.visible) {
                largeObj.y += largeAsteroidSpeed
                if (largeObj.y >= root.height) largeObj.visible = false
            }
        }

        // Move and check asteroids/power-ups (single pass)
        for (i = asteroidPool.length - 1; i >= 0; i--) {
            var obj = asteroidPool[i]
            if (!obj.visible) continue

            obj.y += adjustedScrollSpeed
            if (obj.y >= root.height) {
                obj.visible = false
                continue
            }
            if (obj.y + obj.height < -coarseRange || obj.y > root.height + coarseRange) continue  // Skip far objects

            var objCenterX = obj.x + obj.width / 2
            var objCenterY = obj.y + obj.height / 2
            var dx = objCenterX - playerCenterX
            var dy = objCenterY - playerCenterY
            var distanceSquared = dx * dx + dy * dy

            if (distanceSquared < maxDistanceSquared &&
                obj.x + obj.width >= playerContainer.x - dimsFactor * 5 &&
                obj.x <= playerContainer.x + playerHitbox.width + dimsFactor * 5 &&
                obj.y + obj.height >= playerContainer.y - dimsFactor * 5 &&
                obj.y <= playerContainer.y + playerHitbox.height + dimsFactor * 5) {
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
                    isGraceActive = true
                    graceTimer.restart()
                    obj.visible = false
                    feedback.play()
                    continue
                }
                if (obj.isPowerup && isColliding(playerHitbox, obj)) {
                    shield = Math.min(10, shield + 1)
                    flashOverlay.triggerFlash("blue")
                    obj.visible = false
                    continue
                }
                if (obj.isInvincibility && isColliding(playerHitbox, obj)) {
                    invincible = true
                    isInvincibleActive = true
                    invincibilityTimer.restart()
                    flashOverlay.triggerFlash("#FF69B4")
                    obj.visible = false
                    continue
                }
                if (obj.isSpeedBoost && isColliding(playerHitbox, obj) && !isSpeedBoostActive) {
                    playerSpeed = basePlayerSpeed * 2
                    isSpeedBoostActive = true
                    speedBoostTimer.restart()
                    flashOverlay.triggerFlash("#FFFF00")
                    addPowerupBar("speedBoost", 6000, "#FFFF00", "#8B8B00")
                    obj.visible = false
                    continue
                }
                if (obj.isScoreMultiplier && isColliding(playerHitbox, obj)) {
                    scoreMultiplier = 2.0
                    scoreMultiplierElapsed = 0
                    scoreMultiplierTimer.restart()
                    flashOverlay.triggerFlash("#00CC00")
                    addPowerupBar("scoreMultiplier", 10000, "#00CC00", "#006600")
                    obj.visible = false
                    continue
                }
                if (obj.isShrink && isColliding(playerHitbox, obj)) {
                    player.width = dimsFactor * 5
                    player.height = dimsFactor * 5
                    playerHitbox.width = dimsFactor * 7
                    playerHitbox.height = dimsFactor * 7
                    isShrinkActive = true
                    shrinkTimer.restart()
                    flashOverlay.triggerFlash("#FFA500")
                    addPowerupBar("shrink", 6000, "#FFA500", "#8B5A00")
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
                    addPowerupBar("slowMo", 6000, "#00FFFF", "#008B8B")
                    obj.visible = false
                    continue
                }
                if (obj.isLaserSwipe && isColliding(playerHitbox, obj)) {
                    flashOverlay.triggerFlash("red")
                    if (!activeLaser) {
                        activeLaser = laserSwipeComponent.createObject(gameArea)
                        addPowerupBar("laserSwipe", 2000, "red", "#8B0000")
                    }
                    obj.visible = false
                    continue
                }
                if (obj.isAutoFire && isColliding(playerHitbox, obj)) {
                    flashOverlay.triggerFlash("#800080")
                    if (!isAutoFireActive) {
                        var shot = autoFireShotComponent.createObject(gameArea, {
                            "x": playerContainer.x + playerHitbox.x + playerHitbox.width / 2 - dimsFactor * 0.5,
                            "y": playerContainer.y + playerHitbox.y
                        })
                        activeShots.push(shot)
                        isAutoFireActive = true
                        autoFireTimer.start()
                    } else {
                        autoFireTimer.restart()  // Extend duration if active
                    }
                    obj.visible = false
                    continue
                }
            }

            if (obj.isAsteroid && (obj.y + obj.height / 2) > playerCenterY && !obj.passed) {
                asteroidCount++
                obj.passed = true
                if (obj.x + obj.width >= playerContainer.x - comboHitbox.width / 2 - dimsFactor * 5 &&
                    obj.x <= playerContainer.x + comboHitbox.width / 2 + dimsFactor * 5 &&
                    obj.y + obj.height >= playerContainer.y - comboHitbox.height / 2 - dimsFactor * 5 &&
                    obj.y <= playerContainer.y + comboHitbox.height / 2 + dimsFactor * 5) {
                    var comboDx = objCenterX - comboCenterX
                    var comboDy = objCenterY - comboCenterY
                    var comboDistSquared = comboDx * comboDx + comboDy * comboDy
                    var isCombo = comboDistSquared < comboDistanceSquared && isColliding(comboHitbox, obj)
                    var basePoints = isCombo ? 2 : 1

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
        }

        // Check shot collisions with asteroids and power-ups
        for (var s = activeShots.length - 1; s >= 0; s--) {
            var shot = activeShots[s]
            if (!shot || !shot.visible) continue

            var buffer = dimsFactor * 2.5  // Total width ~6 (1 + 2.5 left + 2.5 right)
            for (var j = asteroidPool.length - 1; j >= 0; j--) {
                var obj = asteroidPool[j]
                if (obj && obj.visible) {
                    if (shot.x - buffer < obj.x + obj.width &&
                        shot.x + shot.width + buffer > obj.x &&
                        shot.y < obj.y + obj.height &&
                        shot.y + shot.height > obj.y) {
                        if (obj.isAsteroid) {
                            score += 100 * scoreMultiplier
                            var objX = obj.x
                            var objY = obj.y
                            obj.visible = false
                            var particle = comboParticleComponent.createObject(gameArea, {
                                "x": objX,
                                "y": objY,
                                "points": 100 * scoreMultiplier
                            })
                            activeParticles.push(particle)
                        } else {
                            obj.visible = false
                        }
                        shot.destroy()
                        activeShots.splice(s, 1)
                        break
                    }
                }
            }
        }

        // Laser swipe effect
        if (activeLaser && activeLaser.visible) {
            for (i = asteroidPool.length - 1; i >= 0; i--) {
                var obj = asteroidPool[i]
                if (obj && obj.visible && obj !== activeLaser &&
                    obj.y <= activeLaser.y + activeLaser.height && obj.y + obj.height >= activeLaser.y &&
                    obj.x + obj.width >= 0 && obj.x <= root.width) {
                    if (obj.isAsteroid) {
                        score += 10 * scoreMultiplier
                        var objX = obj.x
                        var objY = obj.y
                        obj.visible = false
                        var particle = comboParticleComponent.createObject(gameArea, {
                            "x": objX,
                            "y": objY,
                            "points": 10 * scoreMultiplier
                        })
                    } else {
                        obj.visible = false
                    }
                }
            }
        }

        // Update timers
        if (scoreMultiplierTimer.running) scoreMultiplierElapsed += deltaTime
        if (isAutoFireActive) autoFireElapsed += deltaTime

        // Spawning logic
        var powerupBaseChance = asteroidDensity * 0.008
        if (!paused && currentTime - lastLargeAsteroidSpawn >= spawnCooldown && Math.random() < largeAsteroidDensity / 2) {
            spawnLargeAsteroid()
            lastLargeAsteroidSpawn = currentTime
        }
        if (!paused && currentTime - lastAsteroidSpawn >= spawnCooldown && Math.random() < asteroidDensity) {
            spawnObject({isAsteroid: true})
            lastAsteroidSpawn = currentTime
        }
        if (!paused && currentTime - lastObjectSpawn >= spawnCooldown && Math.random() < powerupBaseChance * 1.4) {
            spawnObject({isAsteroid: false, isPowerup: true})
            lastObjectSpawn = currentTime
        }
        if (!paused && currentTime - lastObjectSpawn >= spawnCooldown && Math.random() < powerupBaseChance * 0.5) {
            spawnObject({isAsteroid: false, isInvincibility: true})
            lastObjectSpawn = currentTime
        }
        if (!paused && currentTime - lastObjectSpawn >= spawnCooldown && Math.random() < powerupBaseChance * 0.8) {
            spawnObject({isAsteroid: false, isSpeedBoost: true})
            lastObjectSpawn = currentTime
        }
        if (!paused && currentTime - lastObjectSpawn >= spawnCooldown && Math.random() < powerupBaseChance * 1.0) {
            spawnObject({isAsteroid: false, isScoreMultiplier: true})
            lastObjectSpawn = currentTime
        }
        if (!paused && currentTime - lastObjectSpawn >= spawnCooldown && Math.random() < powerupBaseChance * 1.0) {
            spawnObject({isAsteroid: false, isShrink: true})
            lastObjectSpawn = currentTime
        }
        if (!paused && currentTime - lastObjectSpawn >= spawnCooldown && Math.random() < powerupBaseChance * 1.0) {
            spawnObject({isAsteroid: false, isSlowMo: true})
            lastObjectSpawn = currentTime
        }
        if (!paused && currentTime - lastObjectSpawn >= spawnCooldown && Math.random() < powerupBaseChance * 0.6) {
            spawnObject({isAsteroid: false, isLaserSwipe: true})
            lastObjectSpawn = currentTime
        }
        if (!paused && currentTime - lastObjectSpawn >= spawnCooldown && Math.random() < powerupBaseChance * 1.2) {
            spawnObject({isAsteroid: false, isAutoFire: true})
            lastObjectSpawn = currentTime
        }
    }

    function spawnLargeAsteroid() {
        for (var i = 0; i < largeAsteroidPool.length; i++) {
            var obj = largeAsteroidPool[i]
            if (!obj.visible) {
                obj.x = Math.random() * (root.width - obj.width)
                obj.y = -obj.height - (Math.random() * dimsFactor * 28)
                obj.visible = true
                return
            }
        }
    }

    function spawnObject(properties) {
        for (var i = 0; i < asteroidPool.length; i++) {
            var obj = asteroidPool[i]
            if (!obj.visible) {
                if (obj.isAsteroid !== (properties.isAsteroid || false) ||
                    obj.isPowerup !== (properties.isPowerup || false) ||
                    obj.isInvincibility !== (properties.isInvincibility || false) ||
                    obj.isSpeedBoost !== (properties.isSpeedBoost || false) ||
                    obj.isScoreMultiplier !== (properties.isScoreMultiplier || false) ||
                    obj.isShrink !== (properties.isShrink || false) ||
                    obj.isSlowMo !== (properties.isSlowMo || false) ||
                    obj.isLaserSwipe !== (properties.isLaserSwipe || false) ||
                    obj.isAutoFire !== (properties.isAutoFire || false)) {  // New condition
                    obj.isAsteroid = properties.isAsteroid || false
                    obj.isPowerup = properties.isPowerup || false
                    obj.isInvincibility = properties.isInvincibility || false
                    obj.isSpeedBoost = properties.isSpeedBoost || false
                    obj.isScoreMultiplier = properties.isScoreMultiplier || false
                    obj.isShrink = properties.isShrink || false
                    obj.isSlowMo = properties.isSlowMo || false
                    obj.isLaserSwipe = properties.isLaserSwipe || false
                    obj.isAutoFire = properties.isAutoFire || false  // New property
                }
                obj.x = Math.random() * (root.width - obj.width)
                obj.y = -obj.height - (Math.random() * dimsFactor * 28)
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
        asteroidDensity = 0.08
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
        player.width = dimsFactor * 10
        player.height = dimsFactor * 10
        playerHitbox.width = dimsFactor * 14
        playerHitbox.height = dimsFactor * 14
        clearPowerupBars()
        nowText.font.pixelSize = dimsFactor * 13
        nowText.opacity = 0
        surviveText.font.pixelSize = dimsFactor * 13
        surviveText.opacity = 0
        playerContainer.x = root.width / 2 - player.width / 2
        gameOverScreen.opacity = 0
        lastFrameTime = 0
        flashOverlay.opacity = 0
        flashOverlay.color = "transparent"
        flashColor = ""
        if (flashAnimation.running) flashAnimation.stop()

        for (var i = 0; i < asteroidPool.length; i++) {
            asteroidPool[i].visible = false
            asteroidPool[i].y = -asteroidPool[i].height - (Math.random() * dimsFactor * 28)
            asteroidPool[i].x = Math.random() * (root.width - asteroidPool[i].width)
            asteroidPool[i].passed = false
            asteroidPool[i].dodged = false
        }
        for (i = 0; i < largeAsteroidPool.length; i++) {
            largeAsteroidPool[i].visible = false
            largeAsteroidPool[i].y = -largeAsteroidPool[i].height - (Math.random() * dimsFactor * 28)
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
                    if (count < 3) {
                        spawnObject({isAsteroid: true})
                    }
                    if (count < 2) {
                        spawnLargeAsteroid()
                    }
                    count++
                    if (count >= 3) {
                        stop()
                        destroy()
                    }
                }
            }
        ', root, "spawnTimer")
    }


    function initializeGame() {
        var asteroidPoolTimer = Qt.createQmlObject('
            import QtQuick 2.15
            Timer {
                interval: 10  // Small chunks for responsiveness
                repeat: true
                running: true
                property int index: 0
                onTriggered: {
                    if (index < asteroidPoolSize) {
                        var obj = objectComponent.createObject(objectContainer)
                        obj.visible = false
                        obj.y = -obj.height
                        asteroidPool.push(obj)
                        index++
                    } else {
                        stop()
                        destroy()
                        initializeLargeAsteroids()
                    }
                }
            }
        ', root, "asteroidPoolTimer")
    }

    function initializeLargeAsteroids() {
        var largeAsteroidPoolTimer = Qt.createQmlObject('
            import QtQuick 2.15
            Timer {
                interval: 10
                repeat: true
                running: true
                property int index: 0
                onTriggered: {
                    if (index < largeAsteroidPoolSize) {
                        var largeObj = largeAsteroidComponent.createObject(largeAsteroidContainer)
                        largeObj.visible = false
                        largeObj.y = -largeObj.height
                        largeAsteroidPool.push(largeObj)
                        index++
                    } else {
                        stop()
                        destroy()
                        finishInitialization()
                    }
                }
            }
        ', root, "largeAsteroidPoolTimer")
    }

    function finishInitialization() {
        DisplayBlanking.preventBlanking = true
        calibrationCountdownTimer.initializationDone = true

        // Preload a combo particle
        var preloadParticle = comboParticleComponent.createObject(gameArea, {
            "x": -dimsFactor * 10,  // Offscreen
            "y": -dimsFactor * 10,
            "points": 1
        })
        preloadParticle.destroy(100)  // Destroy after 100ms to cache it

        // Preload a power-up bar (mimics grace period)
        addPowerupBar("preload", 100, "#FF69B4", "#8B374F")
        removePowerup("preload")  // Remove immediately after adding

        // Initial spawn
        var spawnTimer = Qt.createQmlObject('
            import QtQuick 2.15
            Timer {
                interval: 200
                repeat: true
                running: true
                property int count: 0
                onTriggered: {
                    if (count < 3) {
                        spawnObject({isAsteroid: true})
                    }
                    if (count < 2) {
                        spawnLargeAsteroid()
                    }
                    count++
                    if (count >= 3) {
                        stop()
                        destroy()
                    }
                }
            }
        ', root, "spawnTimer")
    }

    // Start calibration and initialization immediately
    Component.onCompleted: {
        calibrating = true  // Show calibration screen instantly
        initializeGame()    // Start async loading
    }
}
