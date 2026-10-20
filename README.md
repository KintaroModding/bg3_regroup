# Regroup

Adds the Regroup spell to every character: it teleports the whole party to the caster.

A mod for Baldur's Gate 3 (Patch 8), made with game version 4.1.1.7398727. It needs
[Norbyte's Script Extender](https://github.com/Norbyte/bg3se). This README is for developers. What the mod does, how
to install it and its compatibility are in [openmods.md](openmods.md), the mod page on
[openmods](https://openmods.nexus).

## How it works

- `Public/bg3_regroup/Stats/Generated/Data/Spell_Regroup.txt` defines the spell `Regroup_Shout`: a self-target Shout
  without `UseCosts` (free), with `"Requirements" "!Combat"`. Its texts are in
  `Localization/English/bg3_regroup.loca.xml`; `build.ps1` turns that file into the binary `.loca` the game reads.
- `Server/Regroup.lua` gives the spell with `AddSpell` (when the character does not have it yet, no notification) to
  `DB_Players` and `DB_PartOfTheTeam` on `LevelGameplayStarted`, and to each character on `CharacterJoinedParty`.
  Summons do not get it.
- On `CastedSpell` it moves the caster's party members (`DB_Players`) and summons (`DB_PlayerSummons`) that are in the
  caster's party (`IsInPartyWith`, or the owner is) and not in combat. Each one gets a spot on rings around the caster
  (1.5, 2.5 and 3.5 m): the first spot that `FindValidPosition` turns into a valid position at least 0.9 m from the
  caster and from every other spot. Then `TeleportToPosition` moves it there (snap to ground; no linked characters,
  followers or summons, since each character is moved on its own). A character without such a spot goes to the
  caster with `TeleportTo`, the game's own placement.
- The icon: `Public/bg3_regroup/GUI/Icons_Skills.lsx` maps `Regroup_Icon` to the top-left 64 x 64 of the sheet
  `Assets/Textures/Icons/Icons_Regroup.dds`. The texture bank `Content/UI/[PAK]_UI/_merged.lsf.lsx` names that sheet;
  `build.ps1` turns it into the binary `_merged.lsf`. Both files follow the layout of the game's own
  `Icons_Skills.lsx` and texture bank. The tooltip icon (380 x 380) and the controller icon (144 x 144) are
  `Public/Game/GUI/Assets/{Tooltips/Icons,ControllerUIIcons/skills_png}/Regroup_Icon.DDS`. All icons are DXT5 with
  all mip levels, sRGB colors and a soft alpha edge, so they float on the game's backgrounds like its own icons.
- `server.log` gets a line per cast, for example `Regroup by S_Player_Karlach: 3 to free spots, 0 to the caster
  (no free spot).`

## Build

Requirements: Windows PowerShell and [LSLib](https://github.com/Norbyte/lslib/releases) (`Divine.exe`).
`build.ps1` looks for `_tools\lslib\Packed\Tools\Divine.exe` in the parent folders of the project; set `BG3_TOOLS` to
a folder that holds `lslib\` to use another place.

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1             # dist\bg3_regroup.pak
powershell -ExecutionPolicy Bypass -File .\build.ps1 -Deploy     # build, then copy the .pak to the Mods folder
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -Wait      # copy the .pak when the game is closed
```

`deploy.ps1` copies the .pak to the `Mods` folder below `BG3_DATA_DIR` (the BG3 user-data folder), else to
`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods`; `-ModsDir` overrides both. The running game locks the .pak, so
the script stops (exit code 2) or, with `-Wait`, waits until the game is closed.

## Project layout

```
src/                                     Mod files (packed into the .pak)
  Mods/bg3_regroup/meta.lsx           Mod metadata (UUID 3daca750-99f1-4b97-92a2-934e8c43d4cb)
  Mods/bg3_regroup/ScriptExtender/
    Config.json
    Lua/BootstrapServer.lua              Server entry point
    Lua/BootstrapClient.lua              Client entry point
    Lua/Shared/Common.lua                Shared helpers (mod version)
    Lua/Shared/FileWriter.lua            Throttled file output in the Script Extender folder
    Lua/Server/Regroup.lua               The spell: who gets it, who a cast moves, and where to
    Lua/Server/ServerLog.lua             server.log
    Lua/Client/ClientLog.lua             client.log
  Localization/English/bg3_regroup.loca.xml   Texts (build.ps1 converts them to .loca)
  Public/bg3_regroup/Stats/Generated/Data/Spell_Regroup.txt   The spell
  Public/bg3_regroup/GUI/Icons_Skills.lsx, Content/UI/[PAK]_UI/_merged.lsf.lsx, Assets/Textures/Icons/   Icon sheet
  Public/Game/GUI/Assets/                Tooltip and controller icons
docs/                                    Cover and screenshots for openmods.md
tests/                                   Offline tests (Lua 5.4 through lupa)
scripts/bump_version.py                  Raises the last version digit in meta.lsx
scripts/show_log.py                      Prints the mod's log files
build.ps1                                Builds dist/bg3_regroup.pak from src/ (texts: .loca.xml -> .loca)
deploy.ps1                               Copies the .pak to the Mods folder
openmods.json, openmods.md               Data and mod page for openmods.nexus
```

Versioning: every change raises the last version digit (1.0.0.0 -> 1.0.0.1):

```powershell
python scripts\bump_version.py           # both Version64 values in meta.lsx
python scripts\bump_version.py --show
```

Logs: the mod writes `server.log` and `client.log` to
`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\bg3_regroup\`. Each load writes a line like
`Regroup 1.0.0.1 loaded.`, so the logs show which version runs. `python scripts\show_log.py` prints the newest
lines (from `BG3_DATA_DIR`, if set).

Tests:

```powershell
python -m pip install lupa
python tests\run_tests.py
```

The tests run every mod script against mocks of the Script Extender API (`tests/harness.lua`). The IMGUI, audio and
resource mocks are checked against the Script Extender IDE helpers (`tests/gen_extui_api.py` refreshes
`tests/extui_api.json`), so a property or method that does not exist in the real API fails the tests.

## License

MIT, see [LICENSE](LICENSE).
