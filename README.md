# GatherGlow

GatherGlow highlights nearby gathering targets in **World of Warcraft: Forever 1.60.1**. One switch in **Esc > Options > AddOns > GatherGlow** controls the markers, sounds, and fishing pins. Four dropdowns let you pick built-in icons for herbs, ore, skinning, and fishing pins. Choices are saved and update the displayed icons as you change them.

- The default icons are a green leaf for herbs, an icy-blue crystal for ore, and an amber hide for corpses ready to skin. The marker pulses as you approach and flashes once when the target comes within Interact Key range.
- Skinning uses one silent marker on the corpse WoW selects for your Interact Key, with your selected skinnable corpse as a fallback when its nameplate is available.
- Herbs chime and ore plays an anvil strike once per encounter. During combat the cue waits until WoW can still detect a gathering target after the fight. Skinning is silent.
- Blue fish on the minimap mark 337 known fishing pool and wreckage locations across 17 established Azeroth zones. Pins indicate saved locations. A pool may be empty when you arrive.

GatherGlow follows the gathering target WoW selects for your Interact Key. It enables the game's Interact Key nameplate setting, which may also show native nameplates on nearby interactable NPCs.

For the amber hides to appear, enable **Enemy Unit Nameplate** under **Esc > Options > Gameplay > Nameplates** so WoW can provide corpse nameplates. GatherGlow's options show a setup warning while GatherGlow is enabled and enemy nameplates are off.

## Install

Use the [CurseForge project](https://www.curseforge.com/wow/addons/gatherglow) or download this repository as a ZIP. If you are installing the source, extract it and rename the extracted folder to `GatherGlow`. Put that folder in `World of Warcraft/_forever_/Interface/AddOns` so that `GatherGlow_Camelot.toc` is directly inside it. Restart WoW to load the addon and its icon textures.

Turn GatherGlow off before uninstalling so it can restore any Interact Key settings it changed.

## Icon source

The four TGA textures ship with the addon. The Python scripts in [tools](tools) regenerate them with Pillow. Install Pillow with `python -m pip install Pillow`, then run the script for the icon you want to rebuild.

## License and credits

GatherGlow's original code, documentation, and artwork are available under the [MIT License](LICENSE).

The fishing locations are adapted from Wuild's GatherLite Forever database. See [the fishing data notice](PoolData-LICENSE.txt) for provenance and the accompanying license notice.
