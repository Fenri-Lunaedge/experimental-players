# Experimental Players

**Advanced PlayerBot AI for Garry's Mod - Multiplayer Edition**

Experimental Players is a next-generation bot mod for Garry's Mod that uses real PlayerBots (not traditional NPCs) to create highly realistic AI players that behave, move, and interact exactly like human players.

## Features

### Core System (GLambda-based)
- **Real PlayerBot entities** - Uses `player.CreateNextBot()` for authentic player physics
- **Dual-threaded architecture** - Separate navigation and decision-making systems
- **Custom A* pathfinding** - Advanced navigation with dedicated navigator entity
- **Modular codebase** - Clean, maintainable architecture

### Weapon Systems (Lambda-compatible)
- Extensive weapon support from Lambda Players ecosystem
- Compatible with Lambda weapon addons (CSS, L4D2, TF2, etc.)
- Smart weapon selection and handling
- Ammo management and weapon switching

### Social Features (Zeta-inspired)
- **Text chat** with realistic typing simulation
- **Voice lines** and personality system
- **Conversations** between bots
- **Admin system** for bot management
- **Voting system** for map changes and game settings

### Game Modes
- **Team Deathmatch (TDM)**
- **Capture the Flag (CTF)**
- **King of the Hill (KOTH)**
- Custom team configurations

### Building & Interaction
- Prop spawning and manipulation
- Entity ownership system
- Tool gun support
- Physgun building

## Requirements

- **Garry's Mod** (obviously!)
- **Multiplayer server** - Does NOT work in singleplayer (uses PlayerBot system)
- Navigation meshes on maps for optimal pathfinding

## Installation

1. Download the latest release
2. Extract to `garrysmod/addons/experimental-players/`
3. Restart your server
4. Bots will appear in the spawn menu under "Experimental Players"

## Console Commands

### Spawning & Management
- `exp_spawn <name>` - Spawn a bot with optional custom name
- `exp_killall` - Kill all active bots
- `exp_removeall` - Remove all bots from server

### Debug & Testing
- `exp_listweapons` - List all available weapons with details
- `exp_debug_combat` - Show combat debug info for all bots
- `exp_debug_reloadfiles` - Reload all addon files (admin only)

### Configuration
All ConVars start with `exp_`:
- `exp_combat_range` - Enemy detection range
- `exp_combat_attackplayers` - Allow bots to attack human players
- `exp_building_enabled` - Enable/disable building system
- `exp_building_maxprops` - Max props per bot

See `lua/experimental_players/includes/sh_convars.lua` for full list.

## Architecture

Based on the revolutionary GLambda Players architecture with enhancements:

```
experimental-players/
├── lua/
│   ├── autorun/                    # Initialization
│   ├── entities/                   # Navigator and spawner entities
│   └── experimental_players/
│       ├── includes/               # Core systems
│       ├── players/                # Player behavior modules
│       ├── weapons/                # Weapon definitions
│       ├── social/                 # Chat, voice, voting
│       ├── gamemodes/              # CTF, KOTH, TDM
│       └── compatibility/          # Lambda addon support
```

## Latest Updates

**2025-11-16 - Major Combat Overhaul:**
- ✅ Fixed critical weapon loading issues
- ✅ Implemented panic/retreat system
- ✅ Added intelligent threat assessment
- ✅ Tactical strafing during combat
- ✅ Weapon-specific combat distances
- ✅ Smart damage response with evasion

See [IMPROVEMENTS.md](IMPROVEMENTS.md) for detailed changelog.

## Credits

This mod combines the best ideas from:
- **GLambda Players** by Lolleko - Revolutionary PlayerBot architecture
- **Lambda Players** by Lambda Gaming - Weapon systems and clean code
- **Zeta Players** by Zetaplayer - Social features and game modes

Special thanks to the Garry's Mod modding community!

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes with clear commits
4. Submit a pull request

## Support

Found a bug? Have a suggestion? Open an issue on GitHub!

---

**Created by Fenri-Lunaedge** | Powered by PlayerBot technology
