# Horsepower Tuner (FS22)

A Farming Simulator 22 mod that lets you raise or lower the horsepower and torque of any motorized vehicle in-game.

## Installation

1. Download `FS22_HorsepowerTuner.zip` from the [Releases](../../releases) page (or zip the contents of this repository yourself, with `modDesc.xml` at the root of the zip).
2. Place the zip in `Documents\My Games\FarmingSimulator2022\mods`. Do not unzip or rename it.
3. Enable the mod for your savegame.

## Usage

Get into any vehicle with an engine and press **Left Alt + H** to open the tuner panel.

| Key | Action |
| --- | --- |
| Numpad 8 / Numpad 2 | Horsepower + / − (5% per press) |
| Numpad 6 / Numpad 4 | Torque + / − (5% per press) |
| Numpad 5 | Reset to stock |
| Left Alt + H | Close the panel |

All keys can be changed in **Options → Controls**. The range is 25% to 500%.

## How it works

- **Torque** scales the engine at low RPM (pulling power); **Horsepower** scales it at high RPM. In between, the two are blended, so power = torque × RPM stays consistent.
- The tuned torque curve is pushed to the physics engine whenever a value changes.
- Settings are saved per vehicle in the savegame and synced in multiplayer.
- Top speed is still limited by the gearbox; tuning gives faster acceleration and more pulling power.
