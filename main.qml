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
    property real closePassThreshold: 36 // Kept for reference, not used
    property string flashColor: ""
    property int comboCount: 0
    property real lastDodgeTime: 0
    property bool comboActive: false
    property real scoreMultiplier: 1.0
    property real scoreMultiplierElapsed: 0
    property real preSlowSpeed: 0 // Temporary storage for slow motion
    property bool isSlowMoActive: false
    property bool isSpeedBoostActive: false
    property bool isShrinkActive: false

    onPausedChanged: {
        if (paused && comboActive) {
            comboMeterAnimation.pause()
        } else if (!paused && comboActive) {
            comboMeterAnimation.resume()
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
        running: !gameOver && !paused && !calibrating && !showingNow && !showingSurvive
        repeat: true
        onTriggered: updateGame()
    }

    Timer {
        id: graceTimer
        interval: 1000
        running: invincible
        repeat: false
        onTriggered: {
            invincible = false
        }
    }

    Timer {
        id: speedBoostTimer
        interval: 3000
        running: false
        repeat: false
        onTriggered: {
            playerSpeed = basePlayerSpeed
            isSpeedBoostActive = false
        }
    }

    Timer {
        id: scoreMultiplierTimer
        interval: 10000
        running: false
        repeat: false
        onTriggered: {
            scoreMultiplier = 1.0
            scoreMultiplierElapsed = 0
        }
    }

    Timer {
        id: slowMoTimer
        interval: 4000
        running: false
        repeat: false
        onTriggered: {
            scrollSpeed = preSlowSpeed
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
            color: "#00CC00" // Green for combos
            font.pixelSize: 16
            z: 3
            opacity: 1

            SequentialAnimation {
                id: particleAnimation
                running: true
                ParallelAnimation { // 45° burst
                    NumberAnimation {
                        target: particleText
                        property: "x"
                        to: x + (x < playerContainer.x ? -30 : 30) // Sideways burst
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: particleText
                        property: "y"
                        to: y - 25 // Upward burst
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }
                ParallelAnimation { // Scroll down and fade
                    NumberAnimation {
                        target: particleText
                        property: "y"
                        to: y + 40 // Downward drift after burst
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
                radius: gameOver ? 16 : 0
                Behavior on radius {
                    NumberAnimation { duration: 250 }
                }
            }

            Rectangle {
                id: flashOverlay
                anchors.fill: parent
                color: flashColor ? flashColor : "transparent"
                opacity: 0
                z: 4
                SequentialAnimation {
                    id: flashAnimation
                    running: false
                    NumberAnimation {
                        target: flashOverlay
                        property: "opacity"
                        from: 0.5
                        to: 0
                        duration: flashColor === "#8B6914" || flashColor === "#00FFFF" ? 4000 : 500
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
                z: 2
                visible: !calibrating && !showingNow && !showingSurvive

                Image {
                    id: player
                    width: 36
                    height: 36
                    source: "file:///usr/share/asteroid-launcher/watchfaces-img/asteroid-logo.svg"
                    anchors.centerIn: parent

                    SequentialAnimation on opacity {
                        running: invincible
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.2; duration: 500; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.2; to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                        onStopped: {
                            player.opacity = 1.0
                        }
                    }
                    opacity: 1.0

                    SequentialAnimation on rotation {
                        running: speedBoostTimer.running
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
                        strokeWidth: 0
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

                    SequentialAnimation on opacity {
                        id: comboHitboxAnimation
                        running: comboActive
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.1; to: 0.3; duration: 500; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.3; to: 0.1; duration: 500; easing.type: Easing.InOutSine }
                        onStopped: {
                            comboHitbox.opacity = 0
                        }
                    }
                    opacity: 0
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
                z: 2
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
                    property int maxWidth: scoreText.width * 1.5
                    height: 3
                    width: 0
                    color: "green"
                    radius: height / 2
                    x: (scoreText.width - width) / 2
                    y: -height + 3
                    SequentialAnimation {
                        id: comboMeterAnimation
                        running: comboActive && !paused
                        NumberAnimation {
                            target: comboMeter
                            property: "width"
                            from: 0
                            to: comboMeter.maxWidth
                            duration: 100
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: comboMeter
                            property: "width"
                            from: comboMeter.maxWidth
                            to: 0
                            duration: 2000
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
            z: 3
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
            Text {
                text: "●"
                property real shade: 34/255 - Math.random() * (26/255)
                color: Qt.rgba(shade, shade, shade, 1)
                font.pixelSize: 26 + Math.random() * 18
                x: Math.random() * (root.width - width)
                y: -height
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

                Image {
                    id: asteroidImage
                    visible: isAsteroid && !dodged
                    width: 10
                    height: 10
                    source: "qrc:/asteroid-dodger-star.svg"
                    anchors.centerIn: parent
                }

                Text {
                    id: scoreText
                    visible: isAsteroid && dodged
                    text: "+1"
                    color: "#00CC00" // Green for +1
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

    function updateGame() {
        for (var i = largeAsteroidContainer.children.length - 1; i >= 0; i--) {
            var largeObj = largeAsteroidContainer.children[i]
            largeObj.y += scrollSpeed / 5
            if (largeObj.y >= root.height) {
                largeObj.destroy()
            }
        }

        for (i = objectContainer.children.length - 1; i >= 0; i--) {
            var obj = objectContainer.children[i]
            obj.y += scrollSpeed

            if (obj.isAsteroid && isColliding(playerHitbox, obj) && !invincible) {
                lives--
                flashOverlay.triggerFlash("red")
                comboCount = 0
                comboActive = false
                comboTimer.stop()
                comboMeterAnimation.stop()
                invincible = true
                graceTimer.interval = 1000
                graceTimer.restart()
                obj.destroy()
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
                obj.destroy()
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
                obj.destroy()
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
                obj.destroy()
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
                obj.destroy()
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
                obj.destroy()
                continue
            }

            if (obj.isSlowMo && isColliding(playerHitbox, obj) && !isSlowMoActive) {
                preSlowSpeed = scrollSpeed
                scrollSpeed = scrollSpeed / 2
                isSlowMoActive = true
                slowMoTimer.restart()
                flashOverlay.triggerFlash("#00FFFF")
                comboCount = 0
                comboActive = false
                comboTimer.stop()
                comboMeterAnimation.stop()
                obj.destroy()
                continue
            }

            if (obj.isAsteroid && (obj.y + obj.height / 2) > (playerContainer.y + player.height / 2) && !obj.passed) {
                asteroidCount++
                obj.passed = true
                var isCombo = isColliding(comboHitbox, obj)
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
                obj.destroy()
            }
        }

        if (scoreMultiplierTimer.running) {
            scoreMultiplierElapsed += gameTimer.interval / 1000
        }

        if (Math.random() < largeAsteroidDensity / 2) {
            largeAsteroidComponent.createObject(largeAsteroidContainer)
        }

        if (Math.random() < asteroidDensity) {
            var isAsteroid = Math.random() < 0.96
            objectComponent.createObject(objectContainer, {isAsteroid: isAsteroid, isPowerup: !isAsteroid})
        }

        if (Math.random() < 0.0001) {
            objectComponent.createObject(objectContainer, {isAsteroid: false, isInvincibility: true})
        }

        if (Math.random() < 0.0005) {
            objectComponent.createObject(objectContainer, {isAsteroid: false, isSpeedBoost: true})
        }

        if (Math.random() < 0.0005) {
            objectComponent.createObject(objectContainer, {isAsteroid: false, isScoreMultiplier: true})
        }

        if (Math.random() < 0.0005) {
            objectComponent.createObject(objectContainer, {isAsteroid: false, isShrink: true})
        }

        if (Math.random() < 0.0003) {
            objectComponent.createObject(objectContainer, {isAsteroid: false, isSlowMo: true})
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
        flashOverlay.triggerFlash("#8B6914")
    }

    function restartGame() {
        score = 0
        lives = 2
        level = 1
        asteroidCount = 0
        scrollSpeed = 1.6
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

        for (var i = objectContainer.children.length - 1; i >= 0; i--) {
            objectContainer.children[i].destroy()
        }
        for (i = largeAsteroidContainer.children.length - 1; i >= 0; i--) {
            largeAsteroidContainer.children[i].destroy()
        }

        for (var j = 0; j < 5; j++) {
            var obj = objectComponent.createObject(objectContainer, {isAsteroid: true})
            obj.y = -Math.random() * root.height
        }
        for (j = 0; j < 3; j++) {
            var largeAsteroid = largeAsteroidComponent.createObject(largeAsteroidContainer)
            largeAsteroid.y = -Math.random() * root.height
        }
    }

    Component.onCompleted: {
        calibrating = true
        for (var i = 0; i < 5; i++) {
            var obj = objectComponent.createObject(objectContainer, {isAsteroid: true})
            obj.y = -Math.random() * root.height
        }
        for (i = 0; i < 3; i++) {
            var largeAsteroid = largeAsteroidComponent.createObject(largeAsteroidContainer)
            largeAsteroid.y = -Math.random() * root.height
        }
    }
}
