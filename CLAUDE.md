# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is the **PixeLAW Examples Repository** containing multiple game/app examples built on the PixeLAW framework. Each subdirectory contains a standalone app that can be deployed individually or as part of a collection.

## Current Framework Versions

- **Dojo Framework**: v1.7.1
- **PixeLAW Core**: v0.7.9
- **Cairo**: v2.12.2
- **Scarb**: v2.12.2
- **Starknet**: v2.12.2

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
# Build the app
sozo build

# IMPORTANT: Always use 'sozo build' (not 'scarb build') for proper Dojo compilation

# Format code
scarb fmt

# Run tests
sozo test

# Deploy to local environment
sozo migrate
```

### Format and Quality
```bash
# Format all apps
make fmt_all

# Check formatting without modifying
make fmt_check

# Clean Scarb.lock files
make clean_locks
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

- `docker-compose.yml` - Core PixeLAW infrastructure setup (uses pixelaw/core image)
- `Makefile` - Development workflow commands
- `deploy_apps.sh` - App deployment script that waits for Katana and handles migrations
- `dojo_dev.toml` - Per-app Dojo configuration (world name, namespace mappings, skip_contracts)
- `Scarb.toml` - Per-app package configuration with dependencies and build settings
- `.tool-versions` - Per-app asdf tool versions (Scarb 2.12.2, Dojo 1.7.1)

## Development Notes

### Deployment and Infrastructure
- System automatically handles contract permissions during deployment
- Apps integrate with PixeLAW core for pixel updates and notifications
- Each app uses dual namespace pattern (pixelaw + app-specific namespace)
- Local development uses predefined account addresses and private keys
- All apps support both individual and collective deployment
- Modern Dojo configuration uses `dojo_init` function for automatic initialization

### Dojo 1.7.1 Breaking Changes
**CRITICAL**: All apps have been upgraded to Dojo 1.7.1. Key changes:
- **Enums in models MUST derive `Default` trait** and have `#[default]` attribute on one variant
- **Scarb.toml requires** `allow-prebuilt-plugins = ["dojo_cairo_macros"]`
- **Testing**: `spawn_test_world` now requires `world::TEST_CLASS_HASH` as second argument
- **Cairo version**: Must use 2.12.2 or higher
- See `DOJO_1.7.1_UPGRADE_GUIDE.md` for complete migration instructions

### App Development Patterns
- Use `pixelaw_test_utils` for comprehensive testing helpers
- Reference core models via `build-external-contracts` in Scarb.toml
- Skip core contracts in migration via `skip_contracts` in dojo_dev.toml
- Use proper namespace mappings to avoid conflicts with core contracts

### Dependencies Configuration
**IMPORTANT**: All apps use git dependencies for PixeLAW core, NOT relative paths:
```toml
[dependencies]
pixelaw = { git = "https://github.com/pixelaw/core", branch = "main" }

[dev-dependencies]
pixelaw_test_utils = { git = "https://github.com/pixelaw/core", branch = "main" }
```
This ensures apps always use the latest stable core version from the repository.

## When to Use the PixeLAW App Developer Agent

For any PixeLAW-specific development work, use the specialized agent:
- Creating new PixeLAW applications
- Updating apps to newer framework versions
- Implementing PixeLAW patterns (hooks, pixel interactions)
- Modernizing old Dojo-style apps
- Debugging Cairo compilation issues
- Writing comprehensive tests

The agent contains all technical patterns, code templates, and expert knowledge for PixeLAW development.
