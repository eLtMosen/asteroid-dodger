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
import QtGraphicalEffects 1.15
import QtQuick.Shapes 1.15

Item {
    id: root
    anchors.fill: parent
    visible: true

    property real scrollSpeed: 1.6
    property real savedScrollSpeed: 0  // Store speed when pausing
    property int basePlayerSpeed: 1
    property real playerSpeed: basePlayerSpeed
    property int asteroidCount: 0
    property int score: 0
    property int lives: 2
    property int level: 1
    property int asteroidsPerLevel: 100
    property real asteroidDensity: 0.044 + (level - 1) * 0.002
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
    property real closePassThreshold: 36
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

    // Object pools
    property var asteroidPool: []
    property var largeAsteroidPool: []
    property int asteroidPoolSize: 40
    property int largeAsteroidPoolSize: 10

    // Delta-time tracking
    property real lastFrameTime: 0

    onPausedChanged: {
        console.log("Paused state changed to:", paused)
        if (paused) {
            savedScrollSpeed = scrollSpeed
            scrollSpeed = 0  // Stop movement
            if (comboActive) {
                comboMeterAnimation.pause()
            }
        } else {
            scrollSpeed = savedScrollSpeed  // Restore movement
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
        }
    }

    Timer {
        id: slowMoTimer
        interval: 6000
        running: isSlowMoActive && !paused
        repeat: false
        onTriggered: {
            scrollSpeed = preSlowSpeed
            savedScrollSpeed = preSlowSpeed  // Update saved speed too
            isSlowMoActive = false
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
            color: "#00CC00"
            font.pixelSize: 16
            z: 3
            opacity: 1

            SequentialAnimation {
                id: particleAnimation
                running: !root.paused
                ParallelAnimation {
                    NumberAnimation {
                        target: particleText
                        property: "x"
                        to: x + (x < playerContainer.x ? -30 : 30)
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: particleText
                        property: "y"
                        to: y - 25
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: particleText
                        property: "y"
                        to: y + 40
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
            }

            Timer {
                interval: 1000
                running: true
                repeat: false
                onTriggered: {
                    destroy()
                }
            }
        }
    }

    Component {
        id: shrinkAnimationComponent
        ParallelAnimation {
            running: !root.paused
            NumberAnimation { target: player; property: "width"; to: 36; duration: 6000; easing.type: Easing.Linear }
            NumberAnimation { target: player; property: "height"; to: 36; duration: 6000; easing.type: Easing.Linear }
            NumberAnimation { target: playerHitbox; property: "width"; to: 50; duration: 6000; easing.type: Easing.Linear }
            NumberAnimation { target: playerHitbox; property: "height"; to: 50; duration: 6000; easing.type: Easing.Linear }
            onStopped: { isShrinkActive = false }
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
            layer.effect: FastBlur {
                id: blurEffect
                radius: gameOver ? 24 : 0
                Behavior on radius {
                    NumberAnimation { duration: 500 }
                }
            }

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
                        flashColor = ""
                    }
                }
                function triggerFlash(color) {
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
                    width: 36
                    height: 36
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

                    ColorOverlay {
                        anchors.fill: parent
                        source: player
                        color: "#FFFF0080"
                        visible: speedBoostTimer.running
                    }
                }

                Shape {
                    id: playerHitbox
                    width: 50
                    height: 50
                    anchors.centerIn: parent
                    visible: false

                    ShapePath {
                        strokeWidth: -1
                        fillColor: "transparent"
                        startX: 25; startY: 0
                        PathLine { x: 50; y: 25 }
                        PathLine { x: 25; y: 50 }
                        PathLine { x: 0; y: 25 }
                        PathLine { x: 25; y: 0 }
                    }
                }

                Shape {
                    id: comboHitbox
                    width: 144
                    height: 144
                    anchors.centerIn: parent
                    visible: comboActive
                    opacity: 0.2

                    ShapePath {
                        strokeWidth: 2
                        strokeColor: "#00CC00"
                        fillColor: "transparent"
                        startX: 72; startY: 36
                        PathLine { x: 108; y: 72 }
                        PathLine { x: 72; y: 108 }
                        PathLine { x: 36; y: 72 }
                        PathLine { x: 72; y: 36 }
                    }
                }
            }

            Item {
                id: objectContainer
                width: parent.width
                height: parent.height
                z: 1
                visible: !calibrating && !showingNow && !showingSurvive
            }

            Rectangle {
                id: levelProgressBar
                width: 100
                height: 6
                radius: 3
                color: "#8B6914"
                opacity: 0.5
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    margins: 22
                }
                z: 4
                visible: !gameOver && !calibrating && !showingNow && !showingSurvive

                Rectangle {
                    id: progressFill
                    width: asteroidCount
                    height: parent.height
                    color: "#FFD700"
                    radius: 3
                }
            }

            Column {
                id: hudBottom
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                    margins: 6
                }
                spacing: 5
                visible: !gameOver && !calibrating && !showingNow && !showingSurvive
                Text {
                    text: "❤️ " + lives
                    color: "#dddddd"
                    font.pixelSize: 20
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
                    value: playerContainer.y + playerContainer.height + 20
                    when: !gameOver && !paused && !calibrating && !showingNow && !showingSurvive
                }

                Rectangle {
                    id: comboMeter
                    property int maxWidth: 48
                    height: 3
                    width: 0
                    color: "green"
                    radius: height / 2
                    x: (scoreText.width - width) / 2
                    y: -height + 3
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
                    font.pixelSize: 18
                    font.bold: scoreMultiplierTimer.running
                }
            }

            Column {
                id: calibrationText
                anchors.centerIn: parent
                spacing: 5
                visible: calibrating
                opacity: showingNow ? 0 : 1
                Behavior on opacity {
                    NumberAnimation { duration: 500; easing.type: Easing.InOutQuad }
                }
                Text {
                    text: "Calibrating"
                    color: "white"
                    font.pixelSize: 26
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Hold your watch comfy"
                    color: "white"
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: calibrationTimer + "s"
                    color: "white"
                    font.pixelSize: 20
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Text {
                id: nowText
                text: "NOW"
                color: "white"
                font.pixelSize: 48
                anchors.centerIn: parent
                visible: showingNow
                opacity: 0
                SequentialAnimation {
                    id: nowTransition
                    running: false
                    NumberAnimation { target: nowText; property: "opacity"; from: 0; to: 1; duration: 500 }
                    ParallelAnimation {
                        NumberAnimation { target: nowText; property: "font.pixelSize"; from: 48; to: 120; duration: 1000; easing.type: Easing.OutQuad }
                        NumberAnimation { target: nowText; property: "opacity"; from: 1; to: 0; duration: 1000; easing.type: Easing.OutQuad }
                    }
                }
            }

            Text {
                id: surviveText
                text: "SURVIVE"
                color: "orange"
                font.pixelSize: 48
                font.bold: true
                anchors.centerIn: parent
                visible: showingSurvive
                opacity: 0
                SequentialAnimation {
                    id: surviveTransition
                    running: false
                    NumberAnimation { target: surviveText; property: "opacity"; from: 0; to: 1; duration: 500 }
                    ParallelAnimation {
                        NumberAnimation { target: surviveText; property: "font.pixelSize"; from: 48; to: 120; duration: 1000; easing.type: Easing.OutQuad }
                        NumberAnimation { target: surviveText; property: "opacity"; from: 1; to: 0; duration: 1000; easing.type: Easing.OutQuad }
                    }
                }
            }

            Text {
                id: pauseText
                text: "Paused"
                color: "white"
                font.pixelSize: 32
                anchors.centerIn: parent
                visible: paused && !gameOver && !calibrating && !showingNow && !showingSurvive
            }

            Text {
                id: levelNumber
                text: level
                color: "#dddddd"
                font.pixelSize: 14
                font.bold: true
                anchors {
                    bottom: levelProgressBar.top
                    horizontalCenter: parent.horizontalCenter
                    bottomMargin: 4
                }
                z: 2
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
                spacing: 20
                anchors.centerIn: parent

                Text {
                    id: gameOverText
                    text: "Game Over!"
                    color: "red"
                    font.pixelSize: 28
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Column {
                    spacing: 4
                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        spacing: 8
                        Text { text: "Score"; color: "#dddddd"; font.pixelSize: 16; width: 80; horizontalAlignment: Text.AlignHCenter }
                        Text { text: score; color: "white"; font.pixelSize: 18; font.bold: true; width: 40; horizontalAlignment: Text.AlignHCenter }
                    }
                    Row {
                        spacing: 8
                        Text { text: "Level"; color: "#dddddd"; font.pixelSize: 16; width: 80; horizontalAlignment: Text.AlignHCenter }
                        Text { text: level; color: "white"; font.pixelSize: 18; font.bold: true; width: 40; horizontalAlignment: Text.AlignHCenter }
                    }
                    Row {
                        spacing: 8
                        Text { text: "High Score"; color: "#dddddd"; font.pixelSize: 16; width: 80; horizontalAlignment: Text.AlignHCenter }
                        Text { text: highScore.value; color: "white"; font.pixelSize: 18; font.bold: true; width: 40; horizontalAlignment: Text.AlignHCenter }
                    }
                    Row {
                        spacing: 8
                        Text { text: "Max Level"; color: "#dddddd"; font.pixelSize: 16; width: 80; horizontalAlignment: Text.AlignHCenter }
                        Text { text: highLevel.value; color: "white"; font.pixelSize: 18; font.bold: true; width: 40; horizontalAlignment: Text.AlignHCenter }
                    }
                }

                Rectangle {
                    id: tryAgainButton
                    width: 150
                    height: 50
                    color: "green"
                    border.color: "white"
                    border.width: 2
                    radius: 10
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "Die Again"
                        color: "white"
                        font.pixelSize: 20
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
                width: 30 + Math.random() * 30
                height: width
                x: Math.random() * (root.width - width)
                y: -height
                color: "#0e003d"
                opacity: 1 - Math.random() * 0.7
                radius: 180
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
                width: isAsteroid ? 10 : 18
                height: isAsteroid ? 10 : 18
                x: Math.random() * (root.width - width)
                y: -height
                visible: false

                Shape {
                    id: asteroidShape
                    visible: isAsteroid && !dodged
                    property real sizeFactor: 0.8 + Math.random() * 0.4
                    width: 10 * sizeFactor
                    height: 10 * sizeFactor
                    anchors.centerIn: parent

                    ShapePath {
                        strokeWidth: -1
                        fillColor: {
                            var base = 230
                            var delta = Math.round(base * 0.2)
                            var rand = Math.round(base - delta + Math.random() * (2 * delta))
                            rand = Math.max(184, Math.min(255, rand))
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
                    font.pixelSize: 16
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
                    font.pixelSize: 18
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

    function updateGame(deltaTime) {
        var adjustedScrollSpeed = scrollSpeed * deltaTime * 60
        var largeAsteroidSpeed = adjustedScrollSpeed / 3

        var playerCenterX = playerContainer.x + playerHitbox.x + playerHitbox.width / 2
        var playerCenterY = playerContainer.y + playerHitbox.y + playerHitbox.height / 2
        var comboCenterX = playerContainer.x + comboHitbox.x + comboHitbox.width / 2
        var comboCenterY = playerContainer.y + comboHitbox.y + comboHitbox.height / 2
        var maxDistanceSquared = (playerHitbox.width + 18) * (playerHitbox.width + 18)
        var comboDistanceSquared = (comboHitbox.width + 18) * (comboHitbox.width + 18)

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
                        comboCount = 0
                        comboActive = false
                        comboTimer.stop()
                        comboMeterAnimation.stop()
                        obj.visible = false
                        continue
                    }

                    if (obj.isShrink && isColliding(playerHitbox, obj) && !isShrinkActive) {
                        player.width = 18
                        player.height = 18
                        playerHitbox.width = 25
                        playerHitbox.height = 25
                        isShrinkActive = true
                        flashOverlay.triggerFlash("#FFA500")
                        comboCount = 0
                        comboActive = false
                        comboTimer.stop()
                        comboMeterAnimation.stop()
                        shrinkAnimationComponent.createObject(root).start()
                        obj.visible = false
                        continue
                    }

                    if (obj.isSlowMo && isColliding(playerHitbox, obj) && !isSlowMoActive) {
                        preSlowSpeed = scrollSpeed
                        scrollSpeed = scrollSpeed / 2
                        savedScrollSpeed = scrollSpeed  // Update saved speed
                        isSlowMoActive = true
                        slowMoTimer.restart()
                        flashOverlay.triggerFlash("#00FFFF")
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

        if (Math.random() < 0.0005) {
            spawnObject({isAsteroid: false, isSpeedBoost: true})
        }

        if (Math.random() < 0.0005) {
            spawnObject({isAsteroid: false, isScoreMultiplier: true})
        }

        if (Math.random() < 0.0005) {
            spawnObject({isAsteroid: false, isShrink: true})
        }

        if (Math.random() < 0.0003) {
            spawnObject({isAsteroid: false, isSlowMo: true})
        }
    }

    function spawnLargeAsteroid() {
        for (var i = 0; i < largeAsteroidPool.length; i++) {
            var obj = largeAsteroidPool[i]
            if (!obj.visible) {
                obj.width = 30 + Math.random() * 30
                obj.height = obj.width
                obj.x = Math.random() * (root.width - obj.width)
                obj.y = -obj.height - (Math.random() * 100)  // Random offset up to 100 pixels above
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
                obj.width = obj.isAsteroid ? 10 : 18
                obj.height = obj.isAsteroid ? 10 : 18
                obj.x = Math.random() * (root.width - obj.width)
                obj.y = -obj.height - (Math.random() * 100)  // Random offset up to 100 pixels above
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
        savedScrollSpeed = scrollSpeed  // Update saved speed on level up
        flashOverlay.triggerFlash("#8B6914")
    }

    function restartGame() {
        score = 0
        lives = 2
        level = 1
        asteroidCount = 0
        scrollSpeed = 1.6
        savedScrollSpeed = scrollSpeed  // Reset saved speed
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
        nowText.font.pixelSize = 48
        nowText.opacity = 0
        surviveText.font.pixelSize = 48
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

        for (var j = 0; j < 5; j++) {
            spawnObject({isAsteroid: true})
        }
        for (j = 0; j < 3; j++) {
            spawnLargeAsteroid()
        }
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

    // Stagger initial spawns over a short period
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
