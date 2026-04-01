# Project Zomboid Dedicated Server by Terule 🧟‍♂️

Professional, high-performance Docker image for Project Zomboid Dedicated Servers. Developed to solve common persistence and configuration issues, focusing on stability and ease of use.

Developed with 24/7 uptime in mind by **Terule**.

> [!CAUTION]
> **CRITICAL WARNING (Build 42 Versions):**
> Saves created in Build 42.15 are **NOT compatible** with Build 42.16 and higher. Updating your server will result in map corruption or loss of progress. 
> To protect your save, if you use `SERVER_BRANCH=outdatedunstable`, automatic updates are **forcefully disabled** on startup.

## ⚠️ Disclaimer

**This is a community-driven project.** I (Terule) am the maintainer of this Docker image, but I am **not** a developer of Project Zomboid, nor am I affiliated with The Indie Stone.

* **Docker/Config Issues:** If the container doesn't boot, memory isn't being allocated, or RCON fails, I'm here to help! Please open an issue.
* **Game Bugs:** If the game crashes due to internal engine errors, item glitches, or map bugs, I cannot fix those. Please report them directly to the official Project Zomboid forums.

## Key Features

* **Official Base**: Built on the official `steamcmd/steamcmd:ubuntu-22` image for maximum reliability.
* **Graceful Shutdown**: Automatically executes RCON `save` and `quit` commands on container stop to prevent world corruption.
* **Memory Patching**: Directly modifies `ProjectZomboid64.json` to ensure your RAM allocation (`-Xmx`) is actually applied.
* **Build 42 Ready**: Supports Stable, Latest Unstable (42.16+), and Outdated Unstable (42.15).

## Quick Start

### Option A: Using Docker Compose (Recommended)

1. **Clone this repository**:
   ```bash
   git clone [https://github.com/Terule/pz-dedicated-server.git](https://github.com/Terule/pz-dedicated-server.git)
   cd pz-dedicated-server
   ```
2. **Configure environment**:
   Copy `.env.example` to `.env` and fill in your desired passwords.
   ```bash
   cp .env.example .env
   ```
3. **Run the server**:
   ```bash
   docker-compose up -d
   ```

### Option B: Using Docker Run (Quick Start)

```bash
docker run -d \
  --name pz_server \
  --restart unless-stopped \
  -p 16261:16261/udp \
  -p 16262:16262/udp \
  -p 27015:27015/tcp \
  -v "$(pwd)/server-data:/project-zomboid-config" \
  -v "$(pwd)/server-files:/project-zomboid" \
  -e ADMIN_PASSWORD="your_secure_password" \
  -e RCON_PASSWORD="your_rcon_password" \
  -e MEMORY_XMX_GB=8 \
  -e PVP=false \
  -e MAX_PLAYERS=10 \
  terule/pz-dedicated-server:latest
```

## Environment Variables

| Variable | Description | Default | 
| ----- | ----- | ----- | 
| `ADMIN_USERNAME` | Administrator username | `admin` | 
| `ADMIN_PASSWORD` | Administrator password (Required) | `CHANGEME` | 
| `SERVER_PASSWORD` | Password required to join the server | (empty) | 
| `PUBLIC` | If `true`, server appears in the global list | `false` | 
| `MEMORY_XMX_GB` | RAM allocated to the server (GB) | `8` | 
| `SERVER_BRANCH` | `unstable`, `outdatedunstable`, or empty (Stable) | (empty) | 
| `PVP` | Enable or disable player vs player | `false` | 
| `MAX_PLAYERS` | Maximum player slots | `10` | 
| `MOUSE_OVER_DISPLAY_NAME` | Show name when hovering mouse over player | `false` | 
| `DISPLAY_USER_NAME` | Show username above player head | `false` | 
| `SHOW_FIRST_LAST_NAME` | Show character's first and last name | `true` | 
| `SNEAK_HIDE_PLAYERS` | Hide from others while sneaking | `false` | 
| `MAP_REMOTE_VISIBILITY` | Visibility level of other players on map | `3` | 
| `ALLOW_MINIMAP` | Enable or disable the minimap (Sandbox) | `true` | 
| `PUID` | User ID for file permissions | `1000` | 
| `PGID` | Group ID for file permissions | `1000` | 

## Support & Credits

* **Maintained by**: [Terule](https://github.com/Terule)
* **Instagram**: [@aguiar_fael](https://www.instagram.com/aguiar_fael)

---
*This is the story of how you died... on a well-configured server.*