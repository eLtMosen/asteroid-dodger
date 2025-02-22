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

Item {
    id: root
    anchors.fill: parent
    visible: true

    property int scrollSpeed: 2
    property int basePlayerSpeed: 1
    property real playerSpeed: basePlayerSpeed
    property int asteroidCount: 0
    property int score: 0
    property int lives: 2
    property int level: 1
    property int asteroidsPerLevel: 100
    property real asteroidDensity: 0.03 + (level - 1) * 0.01
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
    property real closePassThreshold: 30

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
            player.color = "white"
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

    Component {
        id: scoreParticleComponent
        Text {
            id: particleText
            property int points: 1
            text: "+" + points
            color: points === 1 ? "lightgreen" : "yellow"
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
            color: playerHit ? "#001729" : "black"
            SequentialAnimation on color {
                running: invincible
                loops: Animation.Infinite
                ColorAnimation { from: "black"; to: "#200000"; duration: 250 }
                ColorAnimation { from: "#200000"; to: "black"; duration: 250 }
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
                font.pixelSize: 24 + Math.random() * 16
                x: Math.random() * (root.width - width)
                y: -height
            }
        }

        Rectangle {
            id: player
            width: 20
            height: 20
            color: playerHit ? "red" : "white"
            rotation: 45
            x: root.width / 2 - width / 2
            y: root.height * 0.75 - height / 2
            z: 2
            visible: !calibrating && !showingNow && !showingSurvive
            SequentialAnimation on color {
                running: invincible
                loops: Animation.Infinite
                ColorAnimation { from: "white"; to: "red"; duration: 250 }
                ColorAnimation { from: "red"; to: "white"; duration: 250 }
            }
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
            Text {
                property bool isAsteroid: true
                property bool passed: false
                text: isAsteroid ? "*" : "!"
                color: isAsteroid ? "gray" : "yellow"
                font.pixelSize: 16
                font.bold: !isAsteroid
                x: Math.random() * (root.width - width)
                y: -height
                SequentialAnimation on color {
                    running: isAsteroid
                    loops: Animation.Infinite
                    ColorAnimation { from: "gray"; to: "white"; duration: 500 + Math.random() * 1000; easing.type: Easing.InOutQuad }
                    ColorAnimation { from: "white"; to: "gray"; duration: 500 + Math.random() * 1000; easing.type: Easing.InOutQuad }
                }
            }
        }

        Column {
            id: hud
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                margins: 10
            }
            spacing: 5
            visible: !gameOver && !calibrating && !showingNow && !showingSurvive
            Text {
                id: levelText
                text: "lvl " + level
                color: "#dddddd"
                font.pixelSize: 20
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
                SequentialAnimation {
                    id: levelBumpAnimation
                    running: false
                    ParallelAnimation {
                        NumberAnimation { target: levelText; property: "font.pixelSize"; from: 20; to: 80; duration: 250; easing.type: Easing.OutQuad }
                        ColorAnimation { target: levelText; property: "color"; from: "#dddddd"; to: Qt.rgba(1, 0.843, 0, 1); duration: 250; easing.type: Easing.OutQuad }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: levelText; property: "font.pixelSize"; from: 80; to: 20; duration: 250; easing.type: Easing.InQuad }
                        ColorAnimation { target: levelText; property: "color"; from: Qt.rgba(1, 0.843, 0, 1); to: "#dddddd"; duration: 250; easing.type: Easing.InQuad }
                    }
                }
            }
        }

        Column {
            id: hudBottom
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                margins: 10
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

        Text {
            id: scoreText
            text: score
            color: "#dddddd"
            font.pixelSize: 20
            visible: !gameOver && !calibrating && !showingNow && !showingSurvive
            z: 2
            Binding {
                target: scoreText
                property: "x"
                value: player.x + player.width / 2 - scoreText.width / 2
                when: !gameOver && !paused && !calibrating && !showingNow && !showingSurvive
            }
            Binding {
                target: scoreText
                property: "y"
                value: player.y + player.height + 5
                when: !gameOver && !paused && !calibrating && !showingNow && !showingSurvive
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
                font.pixelSize: 24
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
            visible: gameOver
            Column {
                spacing: 20
                anchors.centerIn: parent
                Text {
                    id: gameOverText
                    text: "Game Over!\nFinal Score: " + score
                    color: "red"
                    font.pixelSize: 32
                    horizontalAlignment: Text.AlignHCenter
                }
                Rectangle {
                    id: tryAgainButton
                    width: 120
                    height: 40
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
                        onClicked: restartGame()
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
                player.color = "red"
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
                player.color = "blue"
                obj.destroy()
                continue
            }

            if (obj.isAsteroid && obj.y > player.y + player.height && !obj.passed) {
                asteroidCount++
                obj.passed = true
                var distance = Math.abs((obj.x + obj.width / 2) - (player.x + player.width / 2))
                var points = distance <= closePassThreshold ? 2 : 1
                score += points

                var particle = scoreParticleComponent.createObject(gameArea, {
                    "x": obj.x,
                    "y": obj.y,
                    "points": points
                })

                if (asteroidCount >= asteroidsPerLevel) {
                    levelUp()
                }
            }

            if (obj.y >= root.height) {
                obj.destroy()
            }
        }

        if (Math.random() < largeAsteroidDensity) {
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
        scrollSpeed += 0.5
        levelBumpAnimation.start()
    }

    function restartGame() {
        score = 0
        lives = 2
        level = 1
        asteroidCount = 0
        scrollSpeed = 2
        asteroidDensity = 0.03
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
        nowText.font.pixelSize = 48
        nowText.opacity = 0
        surviveText.font.pixelSize = 48
        surviveText.opacity = 0
        player.x = root.width / 2 - player.width / 2
        player.color = "white"

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
