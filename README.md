# Asteroid Dodger
A simple game for [AsteroidOS](http://asteroidos.org/)

Features:
- Random generation of the asteroid field and power ups
- Parallax effect with slower, non colliding larger asteroids for added visual depth
- Particles for the scoring asteroids
- Combo system, dodging asteroids in a near miss gives more score points on each successive dodge in a 2 sec time window
- Green Combo indicator meter, runs down to indicate the combo period
- Visualisation of the combo area for precisely aimed dodges
- Exact crash detection for the player character using a QtShapes hitbox in shape of the AsteroidOS logo
- Vibration and animated feedback when taking damage and advancing levels
- New level every survived 100th asteroid
- Successive increase of speed and density of the field per level
- Highscore keeping in persistent ConfigurationValue
- Hud displays score, amount of lives and current level
- Asteroids sparkle from grey to white to simulate spinning
- Accelerometer control of the X-Axis for horizontal movement
- Player opacity blinks when hit to indicate 1 second invincible grace period
- Power-up potions in 
	blue for additional lives
	pink for 4 seconds of invincibility
	yellow for 4 sec speed boost
	green for 2x score multiplyer over 10 seconds
	cyan for 4 seconds freeze slow down of the playfield
	orange for player shrink to 50% and grow back to original size in 8 seconds
- Game can be paused by taping the screen
- Calibration start screen to ensure accelerometer values relative to a comfortable device position
- Game intro screen following the calibration as transition into the game

https://github.com/user-attachments/assets/14be49db-a2c0-466b-8402-caf0e3f773f0

