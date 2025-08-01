# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is the **PixeLAW Examples Repository** containing multiple game/app examples built on the PixeLAW framework. Each subdirectory contains a standalone app that can be deployed individually or as part of a collection.

## Current Framework Versions

- **Dojo Framework**: v1.6.2 
- **PixeLAW Core**: v0.7.9
- **Cairo**: v2.10.1 
- **Scarb**: v2.10.1

## Repository Structure

Each app follows a consistent structure:
- `src/lib.cairo` - Module declarations with `#[cfg(test)]` for tests
- `src/app.cairo` - Main application logic and contract
- `src/constants.cairo` - App constants (optional)
- `src/tests.cairo` - Test suite
- `Scarb.toml` - Package configuration with latest versions
- `dojo_dev.toml` - Modern Dojo configuration (app-specific world name, no hardcoded world_address)

## Available Apps

- **chest**: Cooldown-based treasure chest system
- **hunter**: Cryptographic randomness-based chance game  
- **maze**: Multi-pixel maze navigation with predefined layouts
- **minesweeper**: Classic minesweeper with complex grid state
- **pix2048**: 2048 game with control buttons and multi-pixel coordination
- **rps**: Player vs player rock-paper-scissors with commit-reveal scheme
- **tictactoe**: Tic-tac-toe with ML opponent

## Development Commands

### Core Infrastructure Management
```bash
# Start PixeLAW core infrastructure
make start_core
# or
docker compose up -d

# Stop core infrastructure  
make stop_core
# or
docker compose down

# Reset everything (with volume cleanup)
make reset
```

### App Deployment
```bash
# Deploy all apps (full setup)
make start

# Deploy specific app
./deploy_apps.sh <app_name>
# or  
make deploy_app APP=<app_name>

# Build all apps
make build_all

# Test all apps
make test_all

# Stop everything
make stop
```

### Individual App Development
Within each app directory:
```bash
# Quick syntax check
scarb build

# Format code
scarb fmt

# Full Dojo build
sozo build

# Run tests
sozo test

# Deploy to local environment
sozo migrate
```

### Debugging and Monitoring
```bash
# Access core container shell
make shell

# View logs
make log_katana    # Blockchain logs
make log_torii     # Indexer logs  
make log_bots      # Bot logs
```

## Local Development Workflow

1. **Start Core**: `make start_core` launches PixeLAW infrastructure
2. **Wait for Ready**: System waits for Katana at localhost:5050
3. **Deploy Apps**: Use `./deploy_apps.sh <app_name>` for individual deployment
4. **Development**: Apps connect to local Katana with predefined accounts
5. **Testing**: Each app has comprehensive test suite via `sozo test`

## Key Services

- **Katana** (Starknet node): `http://localhost:5050`
- **Torii** (indexer): `http://localhost:8080`  
- **Dashboard**: `http://localhost:3000`

## Configuration Files

- `docker-compose.yml` - Core PixeLAW infrastructure setup
- `Makefile` - Development workflow commands
- `deploy_apps.sh` - App deployment script with automatic permissions
- `dojo_dev.toml` files - Modern Dojo configuration for each app

## Development Notes

- System automatically handles contract permissions during deployment
- Apps integrate with PixeLAW core for pixel updates and notifications  
- Each app uses dual world pattern (pixelaw + app-specific worlds)
- Local development uses predefined account addresses and private keys
- All apps support both individual and collective deployment

## When to Use the PixeLAW App Developer Agent

For any PixeLAW-specific development work, use the specialized agent:
- Creating new PixeLAW applications
- Updating apps to newer framework versions
- Implementing PixeLAW patterns (hooks, pixel interactions)
- Modernizing old Dojo-style apps
- Debugging Cairo compilation issues
- Writing comprehensive tests

The agent contains all technical patterns, code templates, and expert knowledge for PixeLAW development.