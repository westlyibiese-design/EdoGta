# EdoGTA

EdoGTA is a 3D open-world driving game for Android, inspired by the free-roaming driving of GTA. "Edo" is Edo State, Nigeria - the game will grow into a driving environment inspired by Nigerian roads and towns.

**Current status: Phase 1B (playable driving prototype).** The placeholder car now drives along the test road with acceleration, braking, reverse and steering, using Android touch buttons (or the keyboard on desktop) and a smooth third-person follow camera. Phase 1A's project foundation, Android export preset and GitHub Actions workflow are unchanged. **Nothing from Phase 1B has been run in Godot, built into an APK or tested on a device yet** - see "What was verified in Phase 1B".

## Pinned versions and identifiers

| Item | Value |
|---|---|
| Engine | Godot **4.4.1-stable** (standard build, not Mono/.NET) |
| Language | GDScript (Phase 1B scripts under `scripts/`) |
| Renderer | Mobile (Vulkan Mobile) |
| Display name | EdoGTA |
| Android package ID | `com.westly.edogta` |
| Version | `0.1.0` (version code `1`) |
| Orientation | Landscape (sensor landscape - both landscape directions) |
| Android architecture | `arm64-v8a` only |
| Android SDK pieces (CI) | platform-tools, build-tools 35.0.1, platform `android-35`, JDK 17 |
| Repository | https://github.com/westlyibiese-design/EdoGta.git |

If you change the Godot version, update **all** of: `config/features` in `project.godot`, the `env:` block in `.github/workflows/android-build.yml`, the editor-settings file name in the same workflow (`editor_settings-4.4.tres`), and this table.

## Folder structure

```
EdoGta/
├── project.godot                         Project settings (name, main scene, Android/mobile settings)
├── export_presets.cfg                    Android export preset named "Android"
├── README.md                             This file
├── .gitignore                            Ignores .godot/, build/, keystores, APKs
├── .github/workflows/android-build.yml   CI: builds a debug APK
├── assets/
│   └── icon.png                          App icon (512x512, transparent corners)
├── scenes/
│   ├── main/main.tscn                    Main scene (entry point)
│   ├── environment/test_road.tscn        Ground, road, markings, trees, buildings
│   ├── player/placeholder_car.tscn       Drivable placeholder car (VehicleBody3D + 4 VehicleWheel3D)
│   └── ui/touch_controls.tscn            Touch HUD: steering, accelerator, brake/reverse, reset, speed readout
└── scripts/
    ├── vehicle/car_controller.gd         Driving controller (attached to PlaceholderCar)
    ├── camera/follow_camera.gd           Smooth follow camera (attached to CameraRig)
    └── ui/
        ├── touch_controls.gd             Lays out the buttons for any landscape size; speed readout
        └── touch_pad_button.gd           One round TouchScreenButton (draws itself, feeds an input action)
```

## Main scene: `scenes/main/main.tscn`

This is `run/main_scene`. Hierarchy:

```
Main (Node3D)
├── WorldEnvironment          procedural sky, fog, filmic tonemap
├── SunLight                  DirectionalLight3D, orthogonal shadow, 80 m shadow distance
├── TestRoad                  instance of scenes/environment/test_road.tscn
├── VehicleSpawn (Marker3D)   the starting position: (3, 0, 0); the car spawns and resets here
├── PlaceholderCar            instance of scenes/player/placeholder_car.tscn (spawn_marker -> ../VehicleSpawn)
├── CameraRig (Node3D)        follow_camera.gd, target_path -> ../PlaceholderCar
│   └── Camera3D              3.2 m up, 7.5 m behind, pitched 12 degrees down; the only camera, `current`
└── TouchControls             instance of scenes/ui/touch_controls.tscn (CanvasLayer), vehicle -> ../PlaceholderCar
```

Phase 1B removed the Phase 1A `HUD/TitleLabel` ("vehicle does not drive yet"), because it was no longer true.

Conventions used everywhere:

- **Forward is -Z** (Godot's convention). The road runs from z = +50 down to z = -250.
- The car spawns at **x = 3, z = 0**, in the right-hand lane (Nigeria drives on the right), on a yellow start pad. The centre line is at x = 0.
- Road surface is at **y = 0**. Ground is 5 cm lower.
- Ground and road are `StaticBody3D` with box collision (layer 1). **Trees and buildings are visual only (no collision) in Phase 1A.**
- Scenery uses `MultiMeshInstance3D` (a few draw calls) to stay light on phones.

## Placeholder car: `scenes/player/placeholder_car.tscn`

```
PlaceholderCar (VehicleBody3D, car_controller.gd)   origin = ground contact point under the car's centre
├── Collision (CollisionShape3D)                one box, 1.8 x 1.08 x 4.2 m
├── Visual (Node3D)
│   ├── Body, Cabin                             red body, dark cabin (cabin sits toward the rear)
│   ├── HeadlightLeft/Right                     pale-yellow glow, at the FRONT (-Z)
│   └── TaillightLeft/Right                     red glow, at the REAR (+Z)
├── WheelFrontLeft / WheelFrontRight            VehicleWheel3D, steering; each has a "Mesh" child (the tyre cylinder)
├── WheelRearLeft / WheelRearRight              VehicleWheel3D, driven (traction); each has a "Mesh" child
└── CameraMount (Marker3D)                      documented camera attachment point (not used by the follow camera)
```

The root is a `VehicleBody3D`, Godot's built-in raycast-vehicle node, so the Phase 1A root type was kept. The wheels are **direct children of the body** (a `VehicleWheel3D` only works when its parent is the `VehicleBody3D`), so the Phase 1A `Wheels` container node was removed. The project uses Godot's default 3D physics engine; check the Godot 4.4 documentation before switching physics engines if you rely on `VehicleBody3D`.

## Phase 1B: driving prototype

### Controls

All input goes through **named input actions** (defined in `project.godot`). `touch_controls.gd` tracks each finger itself (`InputEventScreenTouch` / `InputEventScreenDrag`, one finger index per button) and presses/releases the matching action with `Input.action_press` / `action_release`, so touch and keyboard share one path.

| Action | Keyboard | Touch button (landscape HUD) |
|---|---|---|
| `accelerate` | W or Up Arrow | GAS (bottom-right, large) |
| `brake_reverse` | S or Down Arrow | BRAKE / REV (bottom-right, left of GAS) |
| `steer_left` | A or Left Arrow | left arrow (bottom-left) |
| `steer_right` | D or Right Arrow | right arrow (bottom-left) |
| `reset_vehicle` | R | RESET (small, top-right) |

Buttons act while held, stop when released, work with several fingers at once, and a thumb can slide from one button to its neighbour (not onto RESET). Buttons are released if the app loses focus. The default `ui_left`/`ui_right`/`ui_up`/`ui_down` actions also use the arrow keys, but nothing in the project uses `ui_*`, so there is no conflict. To try the touch buttons with a mouse on desktop, enable *Project Settings > Input Devices > Pointing > Emulate Touch From Mouse* locally (not set in the project).

### Brake / reverse behaviour

Speed is measured along the car's own forward (-Z) direction.

- Brake held while moving forward faster than `reverse_engage_speed` (1 m/s): **brakes**.
- Brake held at or below that speed: **reverses**, up to `max_reverse_speed`.
- Accelerator held while moving backwards faster than 1 m/s: brakes first, then drives forward.
- Both held: brakes (the car stops; it does not reverse).
- Nothing held: light "coast" braking (rolling resistance and engine braking), so the car slows smoothly instead of coasting forever.

Steering is limited by speed: the wheel angle shrinks as speed rises so the car never turns harder than `max_lateral_acceleration`. Throttle and brake ramp up and down instead of switching instantly.

### Reset

Press **R** or touch **RESET**. The car returns to `Main/VehicleSpawn`, stopped, with straight wheels, and the camera snaps behind it. The car also resets automatically if it falls below `fall_reset_height` (-10 m). There is no automatic flip detection: if the car ends up on its roof, use Reset.

### Tuning

Everything important is an exported variable on `PlaceholderCar` (Inspector, or `placeholder_car.tscn`). Forward thrust and braking are applied as real forces (`apply_central_force`, in m/s^2); `engine_force` and `brake` stay at 0. Thrust only applies while at least one wheel touches the ground.

| Variable (`car_controller.gd`) | Default | Meaning |
|---|---|---|
| `acceleration` | 4 m/s^2 | Full-throttle acceleration (about 0-80 km/h in 6-7 s) |
| `max_forward_speed` / `max_reverse_speed` | 22 / 7 m/s | Speed limits; thrust fades out over the last `top_speed_taper` (15%) |
| `reverse_acceleration_scale` | 0.6 | Reverse acceleration as a fraction of forward |
| `brake_deceleration` | 9 m/s^2 | Full braking |
| `coast_deceleration` | 1 m/s^2 | Slowing with no pedal held |
| `max_steer_angle_deg` / `min_steer_angle_deg` | 32 / 2.5 | Steering at low speed / floor at high speed |
| `max_lateral_acceleration` | 10 m/s^2 | Cornering limit that shrinks steering at speed |
| `steer_speed` / `steer_return_speed` | 2.5 / 4 rad/s | How fast the wheels turn / recentre |
| `throttle_rise_rate` / `throttle_fall_rate` | 3 / 6 per s | Throttle smoothing |
| `spawn_marker`, `spawn_lift`, `fall_reset_height` | `../VehicleSpawn`, 0.2 m, -10 m | Spawn and reset |

Physics values live in the scene: `mass` 1000, custom centre of mass (0, 0.3, 0) to resist rolling, `angular_damp` 1.0, and per wheel `suspension_stiffness` 50, `wheel_friction_slip` 10.5, `wheel_roll_influence` 0.1. These are first-guess values and have **not** been run in Godot.

### Diagnostic readout

The HUD shows a small status line under the speed: `gas`/`brake` (what the input actions read), `steer`, `throttle`, `thrust` (m/s^2 being applied), `speed`, and `wheels on ground n/4`. It is on by default for testing; turn it off with `show_debug` on the `TouchControls` node. If GAS does nothing: `gas 0.0` while pressed means the touch is not reaching the action; `gas 1.0` but `wheels on ground 0/4` means the wheels are not touching the road; `gas 1.0`, wheels 4/4, thrust above 0 but speed 0 means something is physically holding the car.

### Camera

`CameraRig` follows `PlaceholderCar`'s position and heading with exponential smoothing (`position_follow_speed` 10, `heading_follow_speed` 3.5), inside `_physics_process` so it stays in step with the car. The `Camera3D` child keeps its Phase 1A offset. At speed the camera trails slightly behind. There is no camera collision in this phase.

### The yellow shape

The yellow rectangle under the spawn point is `TestRoad/Markings/StartPad`: an intentional 2.8 x 5.6 m start pad (a flat `MeshInstance3D`, 12 mm thick, no collision), placed in Phase 1A under the spawn position. It is not a bug and was left unchanged.

## Phase 1B fix 1 (car did not move on the phone)

The first Phase 1B build installed fine but the car stayed at 0 km/h. Without the ability to run Godot, the two weak points found by inspection were fixed rather than guessed at:

1. **Power**: acceleration relied on `VehicleBody3D.engine_force`, whose scaling is unclear (the docs only say "try 25-50" for 1000 kg) and was probably far too weak. Thrust and braking are now real forces in m/s^2.
2. **Touch input**: buttons relied on `TouchScreenButton` hit-testing with no texture, which could not be verified. Fingers are now tracked directly from screen-touch events. The diagnostic readout above shows which of the two (or neither) was the cause.

## Continuing after Phase 1B

1. **Tune on a device.** Acceleration, braking, steering and suspension are untested first guesses (see "Tuning"). Turn off `show_debug` when done.
2. **Detailed car**: replace the placeholder meshes under `Visual` and each wheel's `Mesh` child; keep the `VehicleWheel3D` nodes, their radius (0.35) and positions in sync with the new model.
3. **Environment**: trees and buildings have no collision, and the road is a straight 300 m strip. Build the real world in later phases.
4. **Camera**: add camera collision and speed-based field of view if wanted.
5. **Safe areas**: the HUD uses simple margins; add notch/cut-out safe-area handling if a device clips the buttons.

## Android configuration

Set in `project.godot` and `export_presets.cfg`:

- Display name `EdoGTA`, package `com.westly.edogta`, landscape orientation, Mobile renderer.
- Stretch mode `canvas_items`, aspect `expand`, base size 1280 x 720 (3D renders at native resolution; UI scales).
- ETC2/ASTC texture import enabled (required for Android export).
- No extra Android permissions (the `INTERNET` permission is off).
- Debug APK, `arm64-v8a` only, Gradle build **off** (the pre-built Godot Android templates are used, so no NDK or CMake is needed).
- No credentials, keystores or secrets are stored in the project.

## GitHub Actions build

Workflow: `.github/workflows/android-build.yml`. It runs on a GitHub-hosted Ubuntu 24.04 runner when you push to `main` or `master`, or when you start it manually (**Actions** tab -> **Android Build (EdoGTA debug APK)** -> **Run workflow**).

What it does, in order:

1. Checks that `project.godot`, `export_presets.cfg`, the "Android" preset and the package ID are present.
2. Installs JDK 17 and the Android SDK components (platform-tools, build-tools 35.0.1, platform android-35), and checks each one exists.
3. Downloads Godot 4.4.1 and its export templates from the official GitHub release, verifies the SHA-512 checksums, and installs the Android templates into `~/.local/share/godot/export_templates/4.4.1.stable/`.
4. Sets the Android version code to the workflow run number, loads the **permanent signing key** from GitHub Secrets (or, if the secrets are missing, makes a throw-away key and warns), and writes Godot's editor settings (SDK, JDK and keystore paths).
5. Imports the project, validates it headless (loads the main scene and fails on any engine/script error), then exports the debug APK.
6. Uploads the APK as an artifact. Logs are uploaded separately, even when the build fails.

Each step prints a `::error::` message that says what is missing if it fails.

**Finding the APK after a successful run:** open the repository on GitHub -> **Actions** -> click the finished run -> scroll to **Artifacts** at the bottom -> download **EdoGTA-debug-apk** (a zip containing `EdoGTA-debug.apk`). Unzip it on your phone and install the APK (you must allow installs from unknown sources). If a run fails, download **EdoGTA-build-logs** for the full Godot output. Artifacts are kept for 14 days (logs 7 days).

**This workflow has not been run yet.** No APK has been built or tested.

## Signing and updating (installing a new build over the old one)

Android only lets a new APK replace an installed app when **all three** match: the package ID (`com.westly.edogta`), the **same signing key**, and a version code that is not lower. The workflow sets the version code from the run number automatically. For the key, create **one permanent keystore, once**, and keep it forever.

**Warning:** if you lose this keystore or its password you can never update installed copies of the app - users would have to uninstall and reinstall. Keep a backup somewhere safe (not in the repository) and never commit it (`.gitignore` already blocks `*.keystore`).

One-time setup (Replit Shell):

1. Create the keystore outside the repo folder. Use one password for both prompts, avoid `"` and `\` in it, and press Enter when asked for the key password:
   ```
   mkdir -p ~/workspace/edogta-keys && cd ~/workspace/edogta-keys
   keytool -genkeypair -v -keystore edogta-release.keystore -alias edogta -keyalg RSA -keysize 2048 -validity 10000
   ```
   The alias must stay `edogta` (it is set in the workflow as `SIGNING_KEY_ALIAS`).
2. Add two GitHub repository secrets (repo -> Settings -> Secrets and variables -> Actions -> New repository secret):
   - `ANDROID_KEYSTORE_BASE64` - the keystore file encoded as base64 (`base64 -w0 edogta-release.keystore`)
   - `ANDROID_KEYSTORE_PASSWORD` - the keystore password
3. Re-run the workflow. The log says "Signing with the permanent EdoGTA key". Without the secrets, the log shows a warning and the APK cannot be installed over a previous build.

The first APK signed with the permanent key will not install over an older APK signed with a throw-away key: uninstall the old app once. Every build after that updates cleanly.

## Manual configuration still needed

- None of the Phase 1A settings need editor-generated values.
- **Permanent signing key**: required for in-place updates - see "Signing and updating" above. A Play Store release (AAB, release export) is not set up; the workflow still produces a debug-export APK, now signed with your permanent key.
- Optional: open the project once in the Godot 4.4.1 editor and commit the generated `assets/icon.png.import`; CI creates it automatically otherwise.
- Optional: set custom adaptive launcher icons in the export preset (the PNG icon is used for now).

## Deliberately not in Phase 1B

The detailed Toyota Camry model, openable doors, a large map, traffic or pedestrians, weapons, missions, saving, online features or monetisation.

## What was verified in Phase 1A

- Godot 4.4.1-stable (official Linux build) imported the project and loaded the main scene headless with **no errors**; a scripted check confirmed all required nodes exist (road, ground and road collision, markings, scenery, sun, spawn, car, camera, HUD) and that the camera is behind and above the car looking down the road.
- Godot accepted `export_presets.cfg` (preset "Android"), and with a stand-in SDK and templates its export validation passed.
- The template download URL, checksum file and archive layout used by the workflow were checked against the official 4.4.1 release.
- **Not verified:** a real Android export or APK (the Android SDK and full templates were not installed locally), the GitHub Actions run itself, and on-device behaviour.

## What was verified in Phase 1B

Checked (static, scripted, no Godot available in the authoring environment):

- All `res://` paths in the modified scenes and scripts exist; every `ExtResource`/`SubResource` id resolves; every node's parent is declared; `load_steps` values match.
- The `$Node` lookups in `touch_controls.gd` exist in `touch_controls.tscn`.
- (Fix 1) The same checks were re-run after the controller and touch rewrite; no references to the removed `acceleration_force`, `brake_strength` or `coast_brake` remain.
- Every input action used by a script or button (`accelerate`, `brake_reverse`, `steer_left`, `steer_right`, `reset_vehicle`) is defined in `project.godot`, and none is unused.
- GDScript files use tab indentation consistently and have balanced brackets.
- `Camera3D` under `CameraRig` is the only camera and is `current`. The Godot version pin (4.4.1), the Android export preset and the workflow were not modified.
- Wheel geometry: wheel centres sit 0.35 m (the tyre radius) above the road at suspension rest, and the collision box bottom is 0.35 m above the body origin.

**Not verified:** the GDScript has not been parsed or run by Godot (so no headless validation, no scene load, no physics behaviour), no APK was built, the GitHub Actions workflow was not run, and nothing was tested on a device or in the desktop editor. The workflow's headless validation step will be the first real parse check.
