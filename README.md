# PixeLAW Examples

A collection of game and application examples demonstrating PixeLAW's capabilities. Each app showcases different patterns and mechanics within the PixeLAW ecosystem - a pixel-based Autonomous World built on Starknet using the Dojo engine.

## Available Apps

| Name         | Type                    | Description                                                                             |
|-------------|------------------------|-----------------------------------------------------------------------------------------|
| **chest**   | Cooldown System        | Treasure chest placement and collection with 24-hour cooldown mechanics                |
| **hunter**  | Probability Game       | Cryptographic randomness-based chance game with 1/1024 winning odds                    |
| **maze**    | Grid Navigation        | Navigate through pixel-based mazes with predefined layouts and randomization           |
| **minesweeper** | Classic Puzzle     | Traditional minesweeper with complex grid state management and win/lose conditions     |
| **pix2048** | Grid Game              | Fully on-chain 2048 with directional controls and multi-pixel coordination             |
| **rps**     | PvP Competition        | Rock-paper-scissors with commit-reveal cryptographic scheme for fair play              |
| **tictactoe** | AI Opponent          | Classic tic-tac-toe against a machine learning opponent                                |

## Framework Versions

- **Dojo Framework**: v1.6.2
- **PixeLAW Core**: v0.7.9  
- **Cairo**: v2.10.1
- **Starknet**: Latest

## Prerequisites

1. [Make](https://www.gnu.org/software/make/#download)
2. [Docker](https://docs.docker.com/engine/install/)
3. [Docker Compose plugin](https://docs.docker.com/compose/install/)

## Quick Start

### Deploy All Apps (Recommended)
Start PixeLAW with all example apps in one command:

```shell
make start
```

This will:
1. Launch PixeLAW core infrastructure (Katana, Torii, Dashboard)
2. Wait for services to be ready
3. Deploy all example apps with proper permissions
4. Initialize each app for immediate use

**Access the dashboard**: http://localhost:3000

To stop everything:
```shell
make stop
```

### Manual Deployment

#### 1. Start Core Infrastructure
```shell
make start_core
# or
docker compose up -d
```

Services will be available at:
- **Katana** (blockchain): http://localhost:5050
- **Torii** (indexer): http://localhost:8080  
- **Dashboard**: http://localhost:3000

#### 2. Deploy Apps

**All apps at once:**
```shell
make deploy_all
```

**Individual app:**
```shell
./deploy_apps.sh <app_name>
# or
make deploy_app APP=<app_name>
```

Available apps: `chest`, `hunter`, `maze`, `minesweeper`, `pix2048`, `rps`, `tictactoe`

## Development Commands

```shell
make reset           # Reset with volume cleanup
make shell           # Access container shell  
make build_all       # Build all apps
make test_all        # Test all apps
make log_katana      # View blockchain logs
make log_torii       # View indexer logs
```

## App Architecture Patterns

Each app demonstrates different PixeLAW development patterns:

- **Simple Single-Pixel** (chest, hunter): Direct pixel interaction with state management
- **Complex Grid Games** (maze, minesweeper, pix2048): Multi-pixel coordination and game boards  
- **Player vs Player** (rps): Turn-based competition with cryptographic security
- **AI Integration** (tictactoe): Machine learning opponent integration

## Contributing

We welcome contributions! To add your app:

1. Create your app following PixeLAW patterns
2. Add it to the table above
3. Submit a pull request

For development guidance, see the technical documentation in the repository.

## Credits

| Contribution | Developer |
|--------------|-----------|
| [pix2048](https://github.com/themetacat/PixeLAW2048) | [MetaCat](https://github.com/themetacat) |

---

**Learn More**: 
- [PixeLAW Core](https://github.com/pixelaw/core)
- [Dojo Engine](https://dojoengine.org)
- [Starknet](https://starknet.io)