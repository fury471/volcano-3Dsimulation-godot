# volcano-3Dsimulation-godot🌋 
A real-time, 3D particle simulation of a volcanic eruption built with **Godot Engine**.

## Setup & Installation

1.  Clone this repository.
2.  Import the `project.godot` file into Godot Engine (v4.5+).
3.  Open `Main.tscn`.
4.  Press **F5** to run the simulation.

## Features

* **Custom Particle Physics:** "Structure of Arrays" (SoA) implementation.
* **Dispersed Smoke Dust:** Expanding smoke dust with scaling and opacity fading shaders.
* **Physics-based Lava:** Ejecting lava chunks with gravity, drag, and buoyancy calculations.
* **Tween Animation:** Smooth elevator-style platform movement for flame to show and disappear.
* **Free-Fly Camera:** Debug camera with adjustable speed and full 6DoF movement.

## Development

* **Engine:** Godot 4.5.1
* **Language:** GDScript
* **Renderer:** Forward+ (Vulkan)

## Controls

| Key | Action |
| :--- | :--- |
| **Space** | Trigger Eruption (Smoke dust & Lava chunks) |
| **V** | Make volcano dormant |
| **W / A / S / D** | Move Camera (Forward, Left, Back, Right) |
| **Q / E** | Move Camera Vertical (Up / Down) |
| **Shift** | Boost Movement Speed |
| **Tab** | Capture Mouse Cursor |
| **Esc** | Release Mouse Cursor |

---

*Developed for educational purposes to demonstrate advanced GDScript optimization techniques.*
