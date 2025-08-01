# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a PixeLAW Examples repository containing multiple game/app examples built on the PixeLAW framework. PixeLAW is a pixel-based Autonomous World built on Starknet using the Dojo engine. Each subdirectory contains a standalone app that can be deployed individually or as part of a collection.

## Architecture

- **Framework**: Built on Dojo v1.4.0 and PixeLAW core v0.6.31
- **Language**: Cairo v2.9.4 for smart contracts
- **Deployment**: Uses Sozo for building and deploying contracts
- **Infrastructure**: Docker-based local development environment

### App Structure
Each app follows a consistent structure:
- `src/lib.cairo` - Main library file with module declarations
- `src/app.cairo` - Main application logic (for simpler apps)
- `src/systems/actions.cairo` - System actions and contract interfaces (for Dojo-based apps)
- `src/models.cairo` - Data models and structs (for Dojo-based apps)
- `src/tests/` - Test files
- `Scarb.toml` - Package configuration and dependencies
- `dojo_dev.toml` - Dojo development configuration (for Dojo-based apps)

### Key Apps
- **chest**: Dojo-based treasure chest placement and collection system
- **pix2048**: 2048 game implementations
- **hunter**: Pixel-based chance game
- **minesweeper**: Classic minesweeper implementation
- **rps**: Rock-paper-scissors game
- **tictactoe**: Tic-tac-toe with ML opponent

## Development Commands

### Core Infrastructure
```bash
# Start PixeLAW core infrastructure
make start_core
# or
docker compose up -d

# Stop core infrastructure
make stop_core
# or
docker compose down

# Reset (with volume cleanup)
make reset
```

### App Development
```bash
# Deploy all apps
make start

# Deploy specific app
make deploy_app APP=<app_name>
# or
./local_deploy.sh <app_name>

# Stop everything
make stop
```

### Individual App Commands
Within each app directory:
```bash
# Build
sozo build

# Test
sozo test

# Build and migrate (from Scarb.toml scripts)
scarb run migrate

# Individual app actions (example from chest)
scarb run spawn
scarb run move
```

### Debugging and Logs
```bash
# Access core container
make shell

# View logs
make log_katana    # Katana blockchain logs
make log_torii     # Torii indexer logs
make log_bots      # Bot logs
```

## Local Development Workflow

1. **Start Core**: `make start_core` to launch the PixeLAW infrastructure
2. **Wait for Katana**: The system automatically waits for Katana to be ready at localhost:5050
3. **Deploy App**: Use `./local_deploy.sh <app_name>` to deploy and configure an app
4. **Development**: Apps connect to local Katana node and use predefined accounts

## Testing

Each app has its own test suite. Run tests from within the app directory:
```bash
cd <app_name>
sozo test
```

## Key Configuration Files

- `docker-compose.yml` - Core PixeLAW infrastructure setup
- `Makefile` - Development workflow commands
- `local_deploy.sh` - App deployment script with automatic permissions setup
- Individual `Scarb.toml` files define app-specific dependencies and scripts
- `dojo_dev.toml` files configure Dojo world settings for each app

## Dependencies

- PixeLAW core contracts are imported as git dependencies
- Dojo framework v1.5.1 for blockchain functionality
- Cairo v2.10.1 for smart contract development
- Local development uses predefined account addresses and private keys

## Development Notes

- The system automatically handles contract permissions and authorizations during deployment
- Each app can define custom models and systems while integrating with PixeLAW's core pixel management
- Apps use the PixeLAW core actions for pixel updates and notifications
- The framework supports both simple apps (single contract) and complex Dojo-based apps (multiple systems and models)