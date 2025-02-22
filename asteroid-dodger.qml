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

Item {
    id: root
    anchors.fill: parent
    visible: true

    property real scrollSpeed: 2
    property int basePlayerSpeed: 1
    property real playerSpeed: basePlayerSpeed
    property int asteroidCount: 0
    property int score: 0
    property int lives: 2
    property int level: 1
    property int asteroidsPerLevel: 100
    property real asteroidDensity: 0.045 + (level - 1) * 0.005
    property real largeAsteroidDensity: asteroidDensity / 2
    property bool gameOver: false
    property bool playerHit: false
    property bool paused: false
    property bool calibrating: true
    property bool showingNow: false
    property bool showingSurvive: false
    property real baselineX: 0
    property int calibrationTimer: 5
    property bool invincible: false
    property real closePassThreshold: 40
    property string flashColor: ""
    property int comboCount: 0
    property real lastDodgeTime: 0
    property bool comboActive: false

    onPausedChanged: {
        if (paused && comboActive) {
            comboMeterAnimation.pause()
        } else if (!paused && comboActive) {
            comboMeterAnimation.resume()
        }
    }

    ConfigurationValue {
        id: highScore
        key: "/asteroid-dodger/highScore"
        defaultValue: 0
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
        id: flashTimer
        interval: Math.max(500, 2000 / lives)
        running: playerHit
        onTriggered: {
            playerHit = false
            flashColor = ""
        }
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

    Component {
        id: scoreParticleComponent
        Text {
            id: particleText
            property int points: 1
            text: "+" + points
            color: points === 1 ? "#FFD700" : "#00CC00"
            font.pixelSize: 16
            z: 3
            opacity: 1

            SequentialAnimation {
                id: particleAnimation
                running: true
                NumberAnimation {
                    target: particleText
                    property: "y"
                    from: y
                    to: y - 2
                    duration: 100
                    easing.type: Easing.OutQuad
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: particleText
                        property: "y"
                        from: y - 2
                        to: y + 40
                        duration: 900
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        target: particleText
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: 900
                        easing.type: Easing.OutQuad
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

    Item {
        id: gameArea
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "black"
        }

        Rectangle {
            id: flashOverlay
            anchors.fill: parent
            color: flashColor
            opacity: 0
            z: 4
            SequentialAnimation on opacity {
                running: playerHit
                NumberAnimation { from: 0.5; to: 0; duration: 500; easing.type: Easing.OutQuad }
            }
        }

        Item {
            id: largeAsteroidContainer
            width: parent.width
            height: parent.height
            z: 0
            visible: !calibrating && !showingNow && !showingSurvive
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

        Image {
            id: player
            width: 34
            height: 34
            source: "file:///usr/share/asteroid-launcher/watchfaces-img/asteroid-logo.svg"
            x: root.width / 2 - width / 2
            y: root.height * 0.75 - height / 2
            z: 2
            visible: !calibrating && !showingNow && !showingSurvive
        }

        Item {
            id: objectContainer
            width: parent.width
            height: parent.height
            z: 1
            visible: !calibrating && !showingNow && !showingSurvive
        }

        Component {
            id: objectComponent
            Item {
                property bool isAsteroid: true
                property bool passed: false
                width: isAsteroid ? 10 : 18
                height: isAsteroid ? 10 : 18
                x: Math.random() * (root.width - width)
                y: -height

                Image {
                    visible: isAsteroid
                    width: 10
                    height: 10
                    source: "asteroid-dodger-star.svg"
                    anchors.centerIn: parent
                }

                Text {
                    visible: !isAsteroid
                    text: "!"
                    color: "#0087ff"
                    font.pixelSize: 18
                    font.bold: true
                    anchors.centerIn: parent
                }
            }
        }

        Rectangle {
            id: levelProgressBar
            width: 100
            height: 6
            radius: 3  // Pill-shaped
            color: "#8B6914"  // Dark gold background
            opacity: 0.6
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                margins: 14
            }
            z: 2
            visible: !gameOver && !calibrating && !showingNow && !showingSurvive

            Rectangle {
                id: progressFill
                width: asteroidCount  // 1px per asteroid, max 100
                height: parent.height
                color: "#FFD700"  // Golden fill, same as +1 particles
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
                value: player.x + player.width / 2 - scoreText.width / 2
                when: !gameOver && !paused && !calibrating && !showingNow && !showingSurvive
            }
            Binding {
                target: scoreArea
                property: "y"
                value: player.y + player.height + 5
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
                y: -height + 2
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
                }
            }

            Text {
                id: scoreText
                text: score
                color: "#dddddd"
                font.pixelSize: 18
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

        Item {
            id: gameOverScreen
            anchors.centerIn: parent
            z: 3
            visible: gameOver

            Column {
                spacing: 20
                anchors.centerIn: parent

                Text {
                    id: gameOverText
                    text: "Game Over!\nScore " + score + "\nHighest " + highScore.value
                    color: "red"
                    font.pixelSize: 32
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    id: tryAgainButton
                    width: 150
                    height: 50
                    color: "green"
                    border.color: "white"
                    border.width: 2
                    radius: 5
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "Die Again"
                        color: "white"
                        font.pixelSize: 20
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (score > highScore.value) {
                                highScore.value = score
                            }
                            restartGame()
                        }
                    }
                }
            }
        }

        Accelerometer {
            id: accelerometer
            active: true
            onReadingChanged: {
                if (!gameOver && !paused && !calibrating && !showingNow && !showingSurvive) {
                    var deltaX = (accelerometer.reading.x - baselineX) * -2
                    var newX = player.x + deltaX * playerSpeed
                    player.x = Math.max(0, Math.min(root.width - player.width, newX))
                }
            }
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

            if (obj.isAsteroid && isColliding(player, obj) && !invincible) {
                lives--
                playerHit = true
                flashColor = "red"
                comboCount = 0
                comboActive = false
                invincible = true
                obj.destroy()
                feedback.play()
                if (lives <= 0) {
                    gameOver = true
                }
                continue
            }

            if (!obj.isAsteroid && isColliding(player, obj)) {
                lives++
                playerHit = true
                flashColor = "blue"
                comboCount = 0
                comboActive = false
                obj.destroy()
                continue
            }

            if (obj.isAsteroid && obj.y > player.y + player.height && !obj.passed) {
                asteroidCount++
                obj.passed = true
                var distance = Math.abs((obj.x + obj.width / 2) - (player.x + player.width / 2))
                var basePoints = distance <= closePassThreshold ? 2 : 1
                var currentTime = Date.now()

                if (distance <= closePassThreshold) {
                    if (currentTime - lastDodgeTime <= 2000) {
                        comboCount++
                    } else {
                        comboCount = 1
                    }
                    lastDodgeTime = currentTime
                    comboActive = true
                    comboTimer.restart()
                    comboMeterAnimation.restart()
                    score += basePoints * Math.pow(2, comboCount - 1)
                } else {
                    score += basePoints
                }

                var particle = scoreParticleComponent.createObject(gameArea, {
                    "x": obj.x,
                    "y": obj.y,
                    "points": distance <= closePassThreshold ? basePoints * Math.pow(2, comboCount - 1) : basePoints
                })

                if (asteroidCount >= asteroidsPerLevel) {
                    levelUp()
                }
            }

            if (obj.y >= root.height) {
                obj.destroy()
            }
        }

        if (Math.random() < largeAsteroidDensity / 2) {
            largeAsteroidComponent.createObject(largeAsteroidContainer)
        }

        if (Math.random() < asteroidDensity) {
            var isAsteroid = Math.random() < 0.9
            objectComponent.createObject(objectContainer, {isAsteroid: isAsteroid})
        }
    }

    function isColliding(rect, text) {
        return (rect.x < text.x + text.width &&
                rect.x + rect.width > text.x &&
                rect.y < text.y + text.height &&
                rect.y + rect.height > text.y)
    }

    function levelUp() {
        asteroidCount = 0
        level++
        scrollSpeed += 0.01
        // No levelBumpAnimation anymore
    }

    function restartGame() {
        score = 0
        lives = 2
        level = 1
        asteroidCount = 0
        scrollSpeed = 2
        asteroidDensity = 0.045
        gameOver = false
        paused = false
        playerHit = false
        invincible = false
        playerSpeed = basePlayerSpeed
        calibrating = true
        calibrationTimer = 5
        baselineX = 0
        showingNow = false
        showingSurvive = false
        comboCount = 0
        comboActive = false
        lastDodgeTime = 0
        nowText.font.pixelSize = 48
        nowText.opacity = 0
        surviveText.font.pixelSize = 48
        surviveText.opacity = 0
        player.x = root.width / 2 - player.width / 2

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
