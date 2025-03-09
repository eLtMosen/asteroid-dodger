# asteroid-dodger

Asteroid-Dodger is a thrilling survival game for AsteroidOS where you tilt your watch to surf through an ever-denser asteroid field, nailing asteroid surfing combos for big points. Master the art of near-misses and grab rare power-up potions to shrink, speed up, or freeze the cosmic chaos—all while the challenge ramps up with each level. With its retro arcade flair, vibrant visuals, and accelerometer-driven action, this game turns your wrist into a playground of skill and reflexes. Ready to ride the asteroid waves and claim the high score?

## Gameplay Mechanics

- **Random generation** of the asteroid field and power-ups for endless variety.
- **Combo system**: Asteroid surfing (near-miss dodging) grants more points per successive dodge within a 2-second window.
- **Level progression**: Every 100 asteroids survived increases speed and field density.
- **Highscore tracking** stored in persistent `ConfigurationValue`.
- **Shield system** Increase your shield up to 10 impacts using power ups. Displayed in a bar below the player.

## Visuals & Feedback

- **Background Flashes** Atmospheric background effects, colored consistently to indcate game events.
- **Parallax effect** with slower, non-colliding larger asteroids for added depth.
- **Particle effects** for scoring asteroids enhance the action. Particles grow larger and turn pink the higher their value.
- **Hit feedback**: Player opacity blinks when hit, signaling a 2-second invincibility grace period.
- **Haptic feedback**: Vibration and animated effects for damage and level advancement.
- **Combo meter**: A green indicator runs down to show the 2 second combo period.
- **Visualization of combo area**: Helps precisely aimed dodges.
- **Dynamic Progress Bars** for all power-ups to indicate their duration

## Power-Ups

- **Blue**: Gain additional shield points. 
- **Pink**: 10 seconds of invincibility. Stack invincibility and grace periods to become untouchable—time your power-ups for survival!
- **Yellow**: 6-second speed boost with a tricky “drunk” control twist. Grab speed boosts to zip through asteroids and stack combos—just don’t lose control!
- **Green**: 2x score multiplier for 10 seconds. Time your score multiplier for combo runs or power-up blasts—double your rewards!
- **Cyan**: 6-second freeze, slowing the playfield by 50%. Slow time to master combos and grab power-ups safely—control the pace of battle!
- **Orange**: Shrink to 50% size, growing back over 6 seconds. Shrink down to slip through asteroid fields—evasion is your edge!
- **NEW: Purple**: Auto Fire at 200ms for 6000ms and destroy asteroids and potions
- **NEW: Red**: Laser Swipe the screen from all objects.

## UI & Controls

- **Accelerometer control** of the X-axis for horizontal movement.
- **Exact crash detection** using a `QtShapes` hitbox shaped like the AsteroidOS logo.
- **HUD displays** score, lives, and current level.
- **Game pauses** with a screen tap.
- **Calibration start screen** adjusts the accelerometer to your comfortable position, Skip with tap on screen.
- **Game intro screen** smoothly transitions from calibration to action.
- **Debug Tools** FPS counter toggle accessible via the pause screen.

## Tactical gameplay considerations

- Chain combos by dodging asteroids within 2 seconds—precision pays off with massive score boosts!
- Pickung up any power-up potions resets the combo period and thus count. If you are out for maximum combos, be mindful with collecting power-ups.
- Destroying asteroids before they pass the player either by shooting them individually or using the laserSwipe, removes them from the level progression count. You can push back the level change and thus speed and asteroid density progression by destryoing asteroids.


### Ready to test your reflexes? Strap in and dodge like a pro! 🚀


### 1.0 Release video:
https://github.com/user-attachments/assets/99b8f8c5-eea0-4c35-812b-8c7f61858872

### Initial commit gameplay:
https://github.com/user-attachments/assets/14be49db-a2c0-466b-8402-caf0e3f773f0

