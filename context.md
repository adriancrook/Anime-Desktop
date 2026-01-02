# Project Context: Desktop Mascot (Godot 4)
- Engine: Godot 4.x (Compatibility Mode)
- Goal: Transparent, click-through desktop pet on Windows/Mac.
- Structure:
  - Main.tscn (Root Node3D): Handles Window transparency, passthrough, and global state.
  - Character.tscn (Instantiated in Main): The 3D model (Mixamo rig).
    - Root Node: Node3D
    - AnimationPlayer: Holds "mixamo_com" (Idle).
    - Area3D/CollisionShape3D: For click detection.
- Assets:
  - res://sitting.res (Animation: Sit)
  - res://walking.res (Animation: Walk)
  - res://toon_ramp.tres (Gradient)
- Current Status:
  - Basic idle and click detection works.
  - Window transparency works.
  - Needs: UI Menu for "Fetch/Sit", State Machine for walking to target.

