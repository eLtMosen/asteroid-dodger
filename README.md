# Asteroid Dodger

**Description:**
Dive into *Asteroid Dodger*, a thrilling survival game for [AsteroidOS](http://asteroidos.org/) where you tilt your watch to surf through an ever-denser asteroid field, nailing asteroid surfing combos for big points. Master the art of near-misses, and grab rare power-up potions to shrink, speed up, or freeze the cosmic chaos—all while the challenge ramps up with each level. With its retro arcade flair, vibrant visuals, and accelerometer-driven action, this game turns your wrist into a playground of skill and reflexes.
Ready to ride the asteroid waves and claim the high score?

**Features:**

### Gameplay Mechanics
- Random generation of the asteroid field and power-ups for endless variety.
- Combo system: asteroid surfing (near-miss dodging) grants more points per successive dodge within a 2-second window.
- New level every 100th asteroid survived, with successive increases in speed and field density.
- Highscore tracking stored in persistent ConfigurationValue.

### Visuals & Feedback
- Parallax effect with slower, non-colliding larger asteroids for added visual depth.
- Particles for scoring asteroids enhance the action.
- Asteroids sparkle from grey to white, simulating spinning motion.
- Player opacity blinks when hit, signaling a 1-second invincibility grace period.
- Vibration and animated feedback when taking damage or advancing levels.
- Green combo indicator meter runs down to show the combo period.
- Visualization of the combo area for precisely aimed dodges.

### Power-Ups
- Power-up potions:
- Blue: Gain additional lives.
- Pink: 4 seconds of invincibility.
- Yellow: 4-second speed boost with a tricky “drunk” control twist.
- Green: 2x score multiplier for 10 seconds.
- Cyan: 4-second freeze, slowing the playfield.
- Orange: Shrink to 50% size, growing back over 6 seconds.

### UI & Controls
- Accelerometer control of the X-axis for horizontal movement.
- Exact crash detection using a QtShapes hitbox shaped like the AsteroidOS logo.
- HUD displays score, lives, and current level.
- Game pauses with a screen tap.
- Calibration start screen adjusts accelerometer to your comfortable position.
- Game intro screen transitions smoothly from calibration to action.

https://github.com/user-attachments/assets/14be49db-a2c0-466b-8402-caf0e3f773f0

