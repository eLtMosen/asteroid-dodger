# asteroid-dodger

Asteroid-Dodger is a thrilling survival game for AsteroidOS where you tilt your watch to surf through an ever-denser asteroid field, nailing asteroid surfing combos for big points. Master the art of near-misses and grab rare power-up potions to shrink, speed up, or freeze the cosmic chaos—all while the challenge ramps up with each level. With its retro arcade flair, vibrant visuals, and accelerometer-driven action, this game turns your wrist into a playground of skill and reflexes. Ready to ride the asteroid waves and claim the high score?

## Gameplay Mechanics

- **Random generation** of the asteroid field and power-ups for endless variety.
- **Combo system**: Asteroid surfing (near-miss dodging) grants more points per successive dodge within a 2-second window.
- **Level progression**: Every 100 asteroids survived increases speed and field density.
- **Highscore tracking** stored in persistent `ConfigurationValue`.
- **Adaptive difficulty scaling**: The game dynamically adjusts difficulty based on player performance.

## Visuals & Feedback

- **Parallax effect** with slower, non-colliding larger asteroids for added depth.
- **Particle effects** for scoring asteroids enhance the action.
- **Hit feedback**: Player opacity blinks when hit, signaling a 2-second invincibility grace period.
- **Haptic feedback**: Vibration and animated effects for damage and level advancement.
- **Combo meter**: A green indicator runs down to show the combo period.
- **Visualization of combo area**: Helps precisely aimed dodges.

## Power-Ups

- **Blue**: Gain additional lives.
- **Pink**: 4 seconds of invincibility.
- **Yellow**: 4-second speed boost with a tricky “drunk” control twist.
- **Green**: 2x score multiplier for 10 seconds.
- **Cyan**: 4-second freeze, slowing the playfield.
- **Orange**: Shrink to 50% size, growing back over 6 seconds.
- **NEW: Purple**: Reverse controls for 5 seconds to challenge advanced players.
- **NEW: White**: Time Warp - temporarily slows down asteroids but speeds up the player.

## UI & Controls

- **Accelerometer control** of the X-axis for horizontal movement.
- **Exact crash detection** using a `QtShapes` hitbox shaped like the AsteroidOS logo.
- **HUD displays** score, lives, and current level.
- **Game pauses** with a screen tap.
- **Calibration start screen** adjusts the accelerometer to your comfortable position.
- **Game intro screen** smoothly transitions from calibration to action.
- **NEW: Settings menu** for adjusting sensitivity and toggling power-ups.
- **NEW: Audio feedback** with retro sound effects for dodging, power-ups, and crashes.

### Ready to test your reflexes? Strap in and dodge like a pro! 🚀


### 1.0 Release video:
https://github.com/user-attachments/assets/99b8f8c5-eea0-4c35-812b-8c7f61858872

### Initial commit gameplay:
https://github.com/user-attachments/assets/14be49db-a2c0-466b-8402-caf0e3f773f0

