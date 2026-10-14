# Horsepower Tuner (FS22)

A Farming Simulator 22 mod that lets you raise or lower the horsepower and torque of any vehicle with an engine, right in the game. Tractors, trucks, harvesters, loaders: if it has an engine, you can tune it.

## Features

- On-screen tuner panel, opened with one key
- Change horsepower and torque separately, from 25% to 500% of stock
- Shows the current and stock HP and torque of the vehicle you're driving
- Settings are saved per vehicle in your savegame
- Works in multiplayer
- Works with base game and modded vehicles

## Installation

1. Download `FS22_HorsepowerTuner.zip` from the [Releases](../../releases) page.
   (Or make it yourself: zip the files in this repository so that `modDesc.xml` sits at the top level of the zip, not inside a folder.)
2. Put the zip in your mods folder:
   `Documents\My Games\FarmingSimulator2022\mods`
3. Do **not** unzip or rename it. The name must stay `FS22_HorsepowerTuner.zip`, or saved settings won't load.
4. Start FS22, choose your savegame, and tick **Horsepower Tuner** in the mod list.

## How to use

1. **Get into a vehicle** with an engine.
2. **Press Left Alt + H.** A dark panel appears on the left side of the screen. It shows:
   - the vehicle name
   - **Horsepower**: how much you've changed it (for example `+25%`), the tuned HP, and the stock HP
   - **Torque**: how much you've changed it, the tuned torque in Nm, and the stock torque
3. **Adjust the engine** while the panel is open:

   | Key | What it does |
   | --- | --- |
   | Numpad 8 | Horsepower up 5% |
   | Numpad 2 | Horsepower down 5% |
   | Numpad 6 | Torque up 5% |
   | Numpad 4 | Torque down 5% |
   | Numpad 5 | Reset this vehicle to stock |
   | Left Alt + H | Close the panel |

   The numpad keys only work while the panel is open, so they won't interfere with anything else when it's closed.
4. **Drive.** The change takes effect immediately; there's no need to restart or re-enter the vehicle.
5. **Save your game** to keep the settings. Each vehicle remembers its own tuning.

### Changing the keys

No numpad, or the keys clash with another mod? Go to **Options → Controls** and search for **Engine tuner**. Every key can be rebound there.

### Horsepower or torque, which should I change?

- **Torque** gives more pull at low engine speed. Use it for heavy work: ploughing, cultivating, pulling full trailers up hills.
- **Horsepower** gives more power at high engine speed. Use it for faster acceleration and keeping speed under load.
- For an overall stronger engine, raise both by the same amount.

The two are linked (horsepower = torque × engine speed), so changing one also moves the other's number on the panel a little. That's expected.

## Good to know

- **Top speed doesn't go up.** The gearbox still sets the maximum speed. Tuning makes the vehicle accelerate faster and pull harder, not drive faster.
- **Multiplayer:** whoever is driving the vehicle can change its tuning, and everyone sees the same result. Players who join later get the current settings automatically.
- **Damage:** a damaged engine still loses power as usual, on top of your tuning.

## Troubleshooting

**The panel doesn't open.** Check that the mod is ticked for your savegame and that Left Alt + H isn't used by another mod (see *Changing the keys*).

**The panel opens but the vehicle doesn't feel stronger.** Close the game and open `Documents\My Games\FarmingSimulator2022\log.txt`. Each change writes a line like:

```
HorsepowerTuner: <vehicle> torque x1.50, power x1.50 (sent to physics: true)
```

If it says `false`, or the line is missing, please [open an issue](../../issues) and attach your `log.txt`.

**My settings were lost after loading.** Make sure the zip is still named exactly `FS22_HorsepowerTuner.zip`.

## How it works (technical)

- The mod adds a vehicle specialization to every vehicle type that has the `motorized` specialization.
- It hooks `VehicleMotor.getTorqueCurveValue` and `VehicleMotor.getTorqueAndSpeedValues` to multiply the engine's torque curve. The **Torque** factor applies at minimum RPM and the **Horsepower** factor at maximum RPM, blended linearly in between.
- After each change, the tuned curve is pushed to the physics engine with `updateMotorProperties`.
- Factors are stored in the savegame under each vehicle and synced with a network event in multiplayer.

## Author

Made by Timo.
