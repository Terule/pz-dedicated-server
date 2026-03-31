# Project Zomboid Dedicated Server by Terule 🧟‍♂️

Professional, high-performance Docker image for Project Zomboid Dedicated Servers. Developed to solve common persistence and configuration issues, focusing on stability and ease of use.

Developed with 24/7 uptime in mind by **Terule**.

## Key Features

* **Official Base**: Built on the official `steamcmd/steamcmd:ubuntu-22` image for maximum reliability.
* **Graceful Shutdown**: Automatically executes RCON `save` and `quit` commands on container stop to prevent world corruption.
* **Memory Patching**: Directly modifies `ProjectZomboid64.json` to ensure your RAM allocation (`-Xmx`) is actually applied.
* **Smart Settings Patching**: Injects PVP, MaxPlayers, and Minimap settings via environment variables without wiping other manual changes made to the `.ini` file.
* **Build 42 Ready**: Easy branch switching (Stable vs. Unstable) via environment variables.
* **Permissions Support**: Full PUID/PGID support to match your host's filesystem permissions.

## Quick Start

1. **Clone this repository**:
   ```bash
   git clone [https://github.com/Terule/pz-dedicated-server.git](https://github.com/Terule/pz-dedicated-server.git)
   cd pz-dedicated-server
   ```

2. **Configure environment**:
   Copy `.env.example` to `.env` and fill in your desired passwords and settings.
   ```bash
   cp .env.example .env
   ```

3. **Run the server**:
   ```bash
   docker-compose up -d
   ```

## Modding Support 🛠️

To add mods to your server, you need to edit the configuration files generated after the first run:

1. **Locate your config**: Go to `./server-data/Server/`.
2. **Edit the `.ini` file**: Open `{SERVER_NAME}.ini` (e.g., `dedicated.ini`).
3. **Add Workshop IDs**: Find the line `WorkshopItems=` and add the Steam Workshop IDs separated by semicolons.
   * *Example:* `WorkshopItems=2292487282;1111111111`
4. **Add Mod IDs**: Find the line `Mods=` and add the internal Mod IDs separated by semicolons.
   * *Example:* `Mods=Brita;OtherMod`
5. **Restart**: Restart the container with `docker-compose restart`. The server will automatically download the mods on startup.

> **Note**: Workshop items are the packages from Steam, while Mods are the actual content IDs inside those packages. You usually need both.

## Environment Variables

| Variable | Description | Default |
| :--- | :--- | :--- |
| `SERVER_NAME` | Name of your server profile | `dedicated` |
| `MEMORY_XMX_GB` | RAM allocated to the server (GB) | `8` |
| `SERVER_BRANCH` | Use `unstable` for Build 42, leave empty for Stable | (empty) |
| `PVP` | Enable or disable player vs player | `true` |
| `MAX_PLAYERS` | Maximum player slots | `32` |
| `ALLOW_MINIMAP` | Allow players to use the minimap | `true` |

## Support & Credits

* **Maintained by**: [Terule](https://github.com/Terule)
* **Instagram**: [@aguiar_fael](https://www.instagram.com/aguiar_fael)

---
*This is the story of how you died... on a well-configured server.*