# Phase 2 validation (no Godot, Blender or Android device was available)

PASSED (scripted checks):
- Camry GLB re-parsed: valid glTF 2.0, accessor ranges valid, normals unit length, 4 wheel nodes centred on their pivots,
  wheel positions/radius match camry_car.tscn (x +-0.7816, y 0.33, z -+1.3875, r 0.33), 33,309 triangles, 4.0 MB.
- camry_car.tscn, main.tscn, touch_controls.tscn: every res:// path exists, every ExtResource/SubResource id resolves,
  load_steps match, every node's parent is declared. GDScript files use tabs only, brackets balanced.
- EXR headers: both skies are 1024x512, PIZ-compressed (readable by Godot).

NOT TESTED: opening the project in Godot 4.4.1, GDScript parsing, GLB import, wheel hookup at runtime, whether the car
now drives, paint/lighting look with the HDRIs, collision box fit, touch input on a phone, frame rate, the GitHub build.
