import QtQuick 2.15
import QtSensors 5.15

Item {
    id: root
    anchors.fill: parent
    visible: true

    // Game properties
    property int scrollSpeed: 2    // Pixels per frame
    property int playerSpeed: 1    // Pixels per key press or mouse move
    property int asteroidCount: 0  // Track passed asteroids
    property int score: 0          // Score based on passed asteroids
    property int lives: 2          // Starting lives
    property int level: 1          // Current level
    property int asteroidsPerLevel: 100  // Level completion requirement
    property real asteroidDensity: 0.03 + (level - 1) * 0.01  // Increase density per level
    property bool gameOver: false
    property bool playerHit: false // Track hit state

    // Animation timer
    Timer {
        id: gameTimer
        interval: 16 // ~60fps
        running: !gameOver
        repeat: true
        onTriggered: {
            updateGame()
        }
    }

    // Flash timer
    Timer {
        id: flashTimer
        interval: Math.max(500, 2000 / lives)  // 2s at 1 life, shorter with more lives, min 0.5s
        running: playerHit
        onTriggered: {
            playerHit = false
            player.color = "white"
        }
    }

    Item {
        id: gameArea
        anchors.fill: parent

        // Background
        Rectangle {
            anchors.fill: parent
            color: "black"
        }

        // Player (diamond shape using rotated square)
        Rectangle {
            id: player
            width: 20
            height: 20
            color: playerHit ? "red" : "white"  // Flash red when hit
            rotation: 45
            x: root.width / 2 - width / 2
            y: root.height * 0.75 - height / 2
            z: 1  // Ensure player is above asteroids
        }

        // Object container
        Item {
            id: objectContainer
            width: parent.width
            height: parent.height
        }

        // Asteroid and item component
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

        // Score and lives display
        Text {
            id: hud
            text: "* " + score + "  ❤️ " + lives + "   lvl " + level
            color: "white"
            font.pixelSize: 20
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                margins: 10
            }
            visible: !gameOver  // Hide during game over
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

        Accelerometer {
            id: accelerometer
            active: true
            onReadingChanged: {
                if (!gameOver) {
                    var deltaX = accelerometer.reading.x * -2  // Adjust sensitivity
                    var newX = player.x + deltaX
                    player.x = Math.max(0, Math.min(root.width - player.width, newX))
                }
            }
        }
    }

    function updateGame() {
        // Scroll objects
        for (var i = objectContainer.children.length - 1; i >= 0; i--) {
            var obj = objectContainer.children[i]
            obj.y += scrollSpeed

            // Check collision with player
            if (obj.isAsteroid && isColliding(player, obj)) {
                lives--
                playerHit = true  // Trigger flash
                player.color = "red"
                obj.destroy()
                if (lives <= 0) {
                    gameOver = true
                }
                continue
            }

            // Collect life item
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

        // Spawn new objects
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
        playerHit = false
        player.x = root.width / 2 - player.width / 2
        player.color = "white"

        // Clear all objects
        for (var i = objectContainer.children.length - 1; i >= 0; i--) {
            objectContainer.children[i].destroy()
        }

        // Respawn initial asteroids
        for (var j = 0; j < 5; j++) {
            var obj = objectComponent.createObject(objectContainer, {isAsteroid: true})
            obj.y = -Math.random() * root.height
        }
    }

    Component.onCompleted: {
        // Initial spawn
        for (var i = 0; i < 5; i++) {
            var obj = objectComponent.createObject(objectContainer, {isAsteroid: true})
            obj.y = -Math.random() * root.height  // Random start above screen
        }
    }
}
