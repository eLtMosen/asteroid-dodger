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

    // Game properties
    property int scrollSpeed: 2    // Pixels per frame
    property int basePlayerSpeed: 1  // Base speed for accelerometer move
    property real playerSpeed: basePlayerSpeed  // Dynamic speed, starts at base
    property int asteroidCount: 0  // Track passed asteroids
    property int score: 0          // Score based on passed asteroids
    property int lives: 2          // Starting lives
    property int level: 1          // Current level
    property int asteroidsPerLevel: 100  // Level completion requirement
    property real asteroidDensity: 0.03 + (level - 1) * 0.01  // Increase density per level
    property real largeAsteroidDensity: asteroidDensity / 2  // Less frequent large asteroids
    property bool gameOver: false
    property bool playerHit: false // Track hit state
    property bool paused: false    // Pause state
    property real speedChangeThreshold: 4  // Y-axis threshold for speed change
    property bool speedChanged: false // Track if speed is modified
    property bool calibrating: true   // Calibration state
    property bool showingNow: false   // "NOW" screen state
    property bool showingSurvive: false  // "SURVIVE" screen state
    property real baselineX: 0        // Initial X-axis zero point
    property real baselineY: 0        // Initial Y-axis zero point
    property int calibrationTimer: 5  // Countdown for calibration (5 seconds)
    property bool invincible: false   // Grace period invincibility

    NonGraphicalFeedback {
        id: feedback
        event: "press"
    }

    // Animation timer
    Timer {
        id: gameTimer
        interval: 16 // ~60fps
        running: !gameOver && !paused && !calibrating && !showingNow && !showingSurvive  // Stop during transitions
        repeat: true
        onTriggered: {
            updateGame()
        }
    }

    // Flash timer (hit effect)
    Timer {
        id: flashTimer
        interval: Math.max(500, 2000 / lives)  // 2s at 1 life, shorter with more lives, min 0.5s
        running: playerHit
        onTriggered: {
            playerHit = false
            player.color = "white"
        }
    }

    // Grace period timer (2 seconds invincibility)
    Timer {
        id: graceTimer
        interval: 2000  // 2 seconds
        running: invincible
        repeat: false
        onTriggered: {
            invincible = false
        }
    }

    // Speed reset timer (4 seconds of slowdown)
    Timer {
        id: speedResetTimer
        interval: 4000  // 4 seconds active duration
        running: speedChanged
        repeat: false
        onTriggered: {
            playerSpeed = basePlayerSpeed  // Reset to base speed
            speedChanged = false
        }
    }

    // Calibration countdown timer
    Timer {
        id: calibrationCountdownTimer
        interval: 1000  // 1-second updates
        running: calibrating
        repeat: true
        onTriggered: {
            calibrationTimer--
            if (calibrationTimer <= 0) {
                // End calibration, set baselines, transition to "NOW"
                baselineX = accelerometer.reading.x
                baselineY = accelerometer.reading.y
                calibrating = false
                showingNow = true
                feedback.play()
                nowTransition.start()
            }
        }
    }

    // "NOW" to "SURVIVE" transition timer
    Timer {
        id: nowToSurviveTimer
        interval: 1500  // 1.5s for "NOW" screen
        running: showingNow
        repeat: false
        onTriggered: {
            showingNow = false
            showingSurvive = true
            surviveTransition.start()
        }
    }

    // "SURVIVE" to game transition timer
    Timer {
        id: surviveToGameTimer
        interval: 1500  // 1.5s for "SURVIVE" screen
        running: showingSurvive
        repeat: false
        onTriggered: {
            showingSurvive = false
        }
    }

    Item {
        id: gameArea
        anchors.fill: parent

        // Background
        Rectangle {
            anchors.fill: parent
            color: playerHit ? "#050030" : "black"
            SequentialAnimation on color {
                running: invincible
                loops: Animation.Infinite
                ColorAnimation { from: "black"; to: "#300000"; duration: 200 }
                ColorAnimation { from: "#300000"; to: "black"; duration: 200 }
            }
        }

        // Large asteroid layer (parallax background)
        Item {
            id: largeAsteroidContainer
            width: parent.width
            height: parent.height
            z: 0  // Below small asteroids and player
            visible: !calibrating && !showingNow && !showingSurvive
        }

        // Large asteroid component
        Component {
            id: largeAsteroidComponent
            Text {
                text: "●"  // Larger asteroid character
                color: "#222222"  // Much darker gray
                font.pixelSize: 24 + Math.random() * 16  // Random size between 24px and 40px
                x: Math.random() * (root.width - width)
                y: -height  // Start above screen
            }
        }

        // Player (diamond shape using rotated square)
        Rectangle {
            id: player
            width: 20
            height: 20
            color: playerHit ? "red" : "white"  // Flash red when hit, overridden by grace period
            rotation: 45
            x: root.width / 2 - width / 2
            y: root.height * 0.75 - height / 2
            z: 2  // Above both asteroid layers
            visible: !calibrating && !showingNow && !showingSurvive  // Hide during transitions

            // Blinking animation during grace period
            SequentialAnimation on color {
                running: invincible
                loops: Animation.Infinite
                ColorAnimation { from: "white"; to: "red"; duration: 250 }
                ColorAnimation { from: "red"; to: "white"; duration: 250 }
            }
        }

        // Small asteroid layer (foreground)
        Item {
            id: objectContainer
            width: parent.width
            height: parent.height
            z: 1  // Above large asteroids, below player
            visible: !calibrating && !showingNow && !showingSurvive  // Hide during transitions
        }

        // Small asteroid and item component
        Component {
            id: objectComponent
            Text {
                property bool isAsteroid: true  // Default to true
                text: isAsteroid ? "*" : "!"
                color: isAsteroid ? "gray" : "yellow"
                font.pixelSize: 16
                x: Math.random() * (root.width - width)
                y: -height  // Start above screen

                // Sparkle animation for asteroids
                SequentialAnimation on color {
                    running: isAsteroid  // Only for asteroids
                    loops: Animation.Infinite
                    ColorAnimation { from: "gray"; to: "white"; duration: 500 + Math.random() * 1000; easing.type: Easing.InOutQuad }
                    ColorAnimation { from: "white"; to: "gray"; duration: 500 + Math.random() * 1000; easing.type: Easing.InOutQuad }
                }
            }
        }

        // HUD (top: level)
        Column {
            id: hud
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                margins: 10
            }
            spacing: 5
            visible: !gameOver && !calibrating && !showingNow && !showingSurvive  // Show during pause

            Text {
                text: "lvl " + level
                color: "white"
                font.pixelSize: 20
                font.bold: true  // Bold for level
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // HUD (bottom: score and lives)
        Column {
            id: hudBottom
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                margins: 10
            }
            spacing: 5
            visible: !gameOver && !calibrating && !showingNow && !showingSurvive  // Show during pause

            Text {
                text: "* " + score + "  ❤️ " + lives
                color: "white"
                font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // Calibration message
        Column {
            id: calibrationText
            anchors.centerIn: parent
            spacing: 5
            visible: calibrating
            opacity: showingNow ? 0 : 1  // Fade out when transitioning to "NOW"

            Behavior on opacity {
                NumberAnimation {
                    duration: 500  // 0.5s fade to "NOW"
                    easing.type: Easing.InOutQuad
                }
            }

            Text {
                text: "Calibrating"
                color: "white"
                font.pixelSize: 24
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "Please hold your watch comfy"
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

        // "NOW" screen
        Text {
            id: nowText
            text: "NOW"
            color: "white"
            font.pixelSize: 48  // Start large
            anchors.centerIn: parent
            visible: showingNow
            opacity: 0  // Start invisible

            SequentialAnimation {
                id: nowTransition
                running: false
                NumberAnimation { target: nowText; property: "opacity"; from: 0; to: 1; duration: 500 }  // Fade in
                ParallelAnimation {
                    NumberAnimation { target: nowText; property: "font.pixelSize"; from: 48; to: 120; duration: 1000; easing.type: Easing.OutQuad }  // Enlarge
                    NumberAnimation { target: nowText; property: "opacity"; from: 1; to: 0; duration: 1000; easing.type: Easing.OutQuad }  // Fade out
                }
            }
        }

        // "SURVIVE" screen
        Text {
            id: surviveText
            text: "SURVIVE"
            color: "orange"
            font.pixelSize: 48  // Start large
            font.bold: true  // Thick text
            anchors.centerIn: parent
            visible: showingSurvive
            opacity: 0  // Start invisible

            SequentialAnimation {
                id: surviveTransition
                running: false
                NumberAnimation { target: surviveText; property: "opacity"; from: 0; to: 1; duration: 500 }  // Fade in
                ParallelAnimation {
                    NumberAnimation { target: surviveText; property: "font.pixelSize"; from: 48; to: 120; duration: 1000; easing.type: Easing.OutQuad }  // Enlarge
                    NumberAnimation { target: surviveText; property: "opacity"; from: 1; to: 0; duration: 1000; easing.type: Easing.OutQuad }  // Fade out
                }
            }
        }

        // Pause text
        Text {
            id: pauseText
            text: "Paused"
            color: "white"
            font.pixelSize: 32
            anchors.centerIn: parent
            visible: paused && !gameOver && !calibrating && !showingNow && !showingSurvive
        }

        // Game over text and Try Again button
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
                        text: "Try Again"
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

        // Accelerometer controls
        Accelerometer {
            id: accelerometer
            active: true
            onReadingChanged: {
                if (!gameOver && !paused && !calibrating && !showingNow && !showingSurvive) {
                    // X-axis for steering, adjusted for baseline
                    var deltaX = (accelerometer.reading.x - baselineX) * -2  // Adjust sensitivity from baseline
                    var newX = player.x + deltaX * playerSpeed
                    player.x = Math.max(0, Math.min(root.width - player.width, newX))

                    // Y-axis for speed manipulation, adjusted for baseline
                    var yReading = accelerometer.reading.y - baselineY
                    if (!speedChanged && Math.abs(yReading) > speedChangeThreshold) {
                        // Slow down if tilted significantly forward or back from baseline
                        playerSpeed = Math.max(basePlayerSpeed * 0.6, basePlayerSpeed * (1 - 0.4 * Math.abs(yReading) / 10)) // Max 40% slowdown
                        speedChanged = true
                    }
                }
            }
        }

        // Tap to pause/resume
        MouseArea {
            anchors.fill: parent
            enabled: !gameOver && !calibrating && !showingNow && !showingSurvive
            onClicked: {
                paused = !paused
            }
        }
    }

    function updateGame() {
        // Scroll large asteroids (1/5 speed)
        for (var i = largeAsteroidContainer.children.length - 1; i >= 0; i--) {
            var largeObj = largeAsteroidContainer.children[i]
            largeObj.y += scrollSpeed / 5  // Much slower movement (e.g., 0.4px/frame at level 1)

            // Remove large asteroids off-screen
            if (largeObj.y >= root.height) {
                largeObj.destroy()
            }
        }

        // Scroll small asteroids and items
        for (i = objectContainer.children.length - 1; i >= 0; i--) {
            var obj = objectContainer.children[i]
            obj.y += scrollSpeed

            // Check collision with player, skip if invincible
            if (obj.isAsteroid && isColliding(player, obj) && !invincible) {
                lives--
                playerHit = true  // Trigger flash
                player.color = "red"
                invincible = true  // Start grace period
                obj.destroy()
                feedback.play()
                if (lives <= 0) {
                    gameOver = true
                }
                continue
            }

            // Collect life item (not affected by invincibility)
            if (!obj.isAsteroid && isColliding(player, obj)) {
                lives++
                playerHit = true  // Trigger flash
                player.color = "blue"
                obj.destroy()
                continue
            }

            // Count passed asteroids and remove off-screen objects
            if (obj.y >= root.height) {
                if (obj.isAsteroid) {
                    asteroidCount++
                    score++
                    if (asteroidCount >= asteroidsPerLevel) {
                        levelUp()
                    }
                }
                obj.destroy()
            }
        }

        // Spawn new large asteroids
        if (Math.random() < largeAsteroidDensity) {
            var largeAsteroid = largeAsteroidComponent.createObject(largeAsteroidContainer)
        }

        // Spawn new small asteroids or items
        if (Math.random() < asteroidDensity) {
            var isAsteroid = Math.random() < 0.9  // 90% chance asteroid, 10% life
            var obj = objectComponent.createObject(objectContainer, {isAsteroid: isAsteroid})
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
        scrollSpeed += 0.5  // Slight speed increase per level
    }

    function restartGame() {
        // Reset game state
        score = 0
        lives = 2
        level = 1
        asteroidCount = 0
        scrollSpeed = 2
        asteroidDensity = 0.03
        gameOver = false
        paused = false
        playerHit = false
        invincible = false  // Reset invincibility
        playerSpeed = basePlayerSpeed  // Reset speed
        speedChanged = false
        calibrating = true  // Restart calibration
        calibrationTimer = 5  // Reset calibration timer to 5s
        baselineX = 0
        baselineY = 0
        showingNow = false
        showingSurvive = false
        nowText.font.pixelSize = 48  // Reset "NOW" size
        nowText.opacity = 0          // Reset "NOW" opacity
        surviveText.font.pixelSize = 48  // Reset "SURVIVE" size
        surviveText.opacity = 0          // Reset "SURVIVE" opacity
        player.x = root.width / 2 - player.width / 2
        player.color = "white"

        // Clear all objects
        for (var i = objectContainer.children.length - 1; i >= 0; i--) {
            objectContainer.children[i].destroy()
        }
        for (i = largeAsteroidContainer.children.length - 1; i >= 0; i--) {
            largeAsteroidContainer.children[i].destroy()
        }

        // Respawn initial asteroids (small)
        for (var j = 0; j < 5; j++) {
            var obj = objectComponent.createObject(objectContainer, {isAsteroid: true})
            obj.y = -Math.random() * root.height
        }
        // Respawn initial large asteroids
        for (j = 0; j < 3; j++) {
            var largeAsteroid = largeAsteroidComponent.createObject(largeAsteroidContainer)
            largeAsteroid.y = -Math.random() * root.height
        }
    }

    Component.onCompleted: {
        // Initial spawn (small asteroids)
        for (var i = 0; i < 5; i++) {
            var obj = objectComponent.createObject(objectContainer, {isAsteroid: true})
            obj.y = -Math.random() * root.height  // Random start above screen
        }
        // Initial spawn (large asteroids)
        for (i = 0; i < 3; i++) {
            var largeAsteroid = largeAsteroidComponent.createObject(largeAsteroidContainer)
            largeAsteroid.y = -Math.random() * root.height
        }
    }
}
