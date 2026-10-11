# EdoGTA

EdoGTA is a 3D open-world driving game for Android, inspired by the free-roaming driving of GTA. "Edo" is Edo State, Nigeria - the game will grow into a driving environment inspired by Nigerian roads and towns.

**Current status: Phase 1A (project foundation).** The project opens, shows a small test road with a placeholder car and a third-person camera, and has an Android export preset plus a GitHub Actions workflow. **The placeholder car does not drive yet** - there is no driving physics, no controls and no follow camera. Those are Phase 1B.

## Pinned versions and identifiers

| Item | Value |
|---|---|
| Engine | Godot **4.4.1-stable** (standard build, not Mono/.NET) |
| Language | GDScript (no scripts exist yet) |
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
│   └── icon.svg                          App icon
└── scenes/
    ├── main/main.tscn                    Main scene (entry point)
    ├── environment/test_road.tscn        Ground, road, markings, trees, buildings
    └── player/placeholder_car.tscn       Placeholder car
```

There is deliberately **no `scripts/` folder yet**: Phase 1A needs no scripts, and empty folders are not tracked by Git. Phase 1B should create `scripts/` when it adds its first script.

## Main scene: `scenes/main/main.tscn`

This is `run/main_scene`. Hierarchy:

```
Main (Node3D)
├── WorldEnvironment          procedural sky, fog, filmic tonemap
├── SunLight                  DirectionalLight3D, orthogonal shadow, 80 m shadow distance
├── TestRoad                  instance of scenes/environment/test_road.tscn
├── VehicleSpawn (Marker3D)   the starting position: (3, 0, 0)
├── PlaceholderCar            instance of scenes/player/placeholder_car.tscn, placed at the spawn
├── CameraRig (Node3D)        sits at the spawn position; Phase 1B attaches the follow script here
│   └── Camera3D              3.2 m up, 7.5 m behind, pitched 12 degrees down, looking toward -Z
└── HUD (CanvasLayer)
    └── TitleLabel            "EdoGTA - Phase 1A..." text; remove or replace in Phase 1B
```

Conventions used everywhere:

- **Forward is -Z** (Godot's convention). The road runs from z = +50 down to z = -250.
- The car spawns at **x = 3, z = 0**, in the right-hand lane (Nigeria drives on the right), on a yellow start pad. The centre line is at x = 0.
- Road surface is at **y = 0**. Ground is 5 cm lower.
- Ground and road are `StaticBody3D` with box collision (layer 1). **Trees and buildings are visual only (no collision) in Phase 1A.**
- Scenery uses `MultiMeshInstance3D` (a few draw calls) to stay light on phones.

## Placeholder car: `scenes/player/placeholder_car.tscn`

```
PlaceholderCar (VehicleBody3D, freeze = true)   origin = ground contact point under the car's centre
├── Collision (CollisionShape3D)                one box, 1.8 x 1.08 x 4.2 m
├── Visual (Node3D)
│   ├── Body, Cabin                             red body, dark cabin (cabin sits toward the rear)
│   ├── HeadlightLeft/Right                     pale-yellow glow, at the FRONT (-Z)
│   └── TaillightLeft/Right                     red glow, at the REAR (+Z)
├── Wheels (Node3D)
│   └── WheelFrontLeft / FrontRight / RearLeft / RearRight    plain MeshInstance3D cylinders
└── CameraMount (Marker3D)                      documented camera attachment point (same offset as the main camera)
```

The root is a `VehicleBody3D` because it is Godot's built-in node for car-style physics. It is **frozen** so the placeholder stays still. The project uses Godot's default 3D physics engine; check the Godot 4.4 documentation before switching physics engines if you rely on `VehicleBody3D`.

## Continuing in Phase 1B

Start from these exact points. Keep the existing node names so nothing else needs restructuring.

1. **Driving**: attach a script to `PlaceholderCar` (create `scripts/`, e.g. `scripts/car_controller.gd`). Set `freeze = false`. Replace the four plain wheel `MeshInstance3D` nodes under `Wheels` with `VehicleWheel3D` nodes at the same positions (`x = +-0.92`, `y = 0.35`, `z = +-1.35`, radius 0.35) and move each cylinder mesh underneath as a child. Set mass, centre of mass and suspension. The visual collision box can be refined.
2. **Follow camera**: attach a script to `CameraRig` that follows `PlaceholderCar`'s position/heading. `Camera3D` keeps its local offset (0, 3.2, 7.5, pitch -12 degrees). `PlaceholderCar/CameraMount` marks the same offset if you prefer to parent a camera to the car.
3. **Mobile controls**: add a `CanvasLayer` UI under `Main` (next to `HUD`) and an input map in `project.godot`. No input actions are defined yet.
4. **Spawn**: read `Main/VehicleSpawn` instead of hard-coding the start position. The car and `CameraRig` currently duplicate its transform in `main.tscn`.
5. **Environment**: `scenes/environment/test_road.tscn` can be extended (collision for scenery, more road). Its scenery buffers were generated, not hand-placed; edit the scene in the Godot editor rather than by hand.
6. **HUD**: `HUD/TitleLabel` is a Phase 1A label and can be deleted.

Files Phase 1B will most likely modify: `scenes/main/main.tscn`, `scenes/player/placeholder_car.tscn`, `project.godot` (input map), and new files under `scripts/`.

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
4. Generates a throw-away **debug keystore on the runner** and writes Godot's editor settings (SDK, JDK and keystore paths).
5. Imports the project, validates it headless (loads the main scene and fails on any engine/script error), then exports the debug APK.
6. Uploads the APK as an artifact. Logs are uploaded separately, even when the build fails.

Each step prints a `::error::` message that says what is missing if it fails.

**Finding the APK after a successful run:** open the repository on GitHub -> **Actions** -> click the finished run -> scroll to **Artifacts** at the bottom -> download **EdoGTA-debug-apk** (a zip containing `EdoGTA-debug.apk`). Unzip it on your phone and install the APK (you must allow installs from unknown sources). If a run fails, download **EdoGTA-build-logs** for the full Godot output. Artifacts are kept for 14 days (logs 7 days).

**This workflow has not been run yet.** No APK has been built or tested.

## Manual configuration still needed

- None of the Phase 1A settings need editor-generated values. The workflow creates its own debug keystore.
- **Release builds are not set up**: a signed release APK/AAB needs your own release keystore, added later via GitHub Secrets. Do not commit a keystore.
- Optional: open the project once in the Godot 4.4.1 editor and commit the generated `assets/icon.svg.import`; CI creates it automatically otherwise.
- Optional: set custom adaptive launcher icons in the export preset (the SVG icon is used for now).

## Deliberately reserved for Phase 1B (not in this phase)

Vehicle movement and driving physics, acceleration/braking/reversing/steering, mobile touch controls, a working follow camera. Also not planned for this phase: the detailed Toyota Camry model, openable doors, a large map, traffic or pedestrians, missions, saving, online features or monetisation.

## What was verified in Phase 1A

- Godot 4.4.1-stable (official Linux build) imported the project and loaded the main scene headless with **no errors**; a scripted check confirmed all required nodes exist (road, ground and road collision, markings, scenery, sun, spawn, car, camera, HUD) and that the camera is behind and above the car looking down the road.
- Godot accepted `export_presets.cfg` (preset "Android"), and with a stand-in SDK and templates its export validation passed.
- The template download URL, checksum file and archive layout used by the workflow were checked against the official 4.4.1 release.
- **Not verified:** a real Android export or APK (the Android SDK and full templates were not installed locally), the GitHub Actions run itself, and on-device behaviour.
