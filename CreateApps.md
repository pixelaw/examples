# Creating PixeLAW Apps: A Comprehensive Guide

This guide provides detailed instructions for building new PixeLAW applications, based on analysis of core apps and examples in the PixeLAW ecosystem.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [App Structure](#app-structure)
3. [Core Integration](#core-integration)
4. [Development Setup](#development-setup)
5. [App Implementation](#app-implementation)
6. [Testing Strategy](#testing-strategy)
7. [Deployment](#deployment)
8. [Best Practices](#best-practices)

## Architecture Overview

### PixeLAW Core Concepts

- **Pixel World**: 2D Cartesian plane where each position (x,y) represents a Pixel
- **Pixel Properties**: position, app, color, owner, text, alert, timestamp
- **Apps**: Define pixel behavior and interactions (one app per pixel)
- **App2App**: Controlled interactions between different apps via hooks
- **Queued Actions**: Future actions that can be scheduled during execution

### Technology Stack

- **Cairo** (v2.10.1): Smart contract programming language for Starknet
- **Dojo Framework** (v1.5.0-1.5.1): ECS-based blockchain game development framework
- **Starknet**: Layer 2 blockchain platform
- **Scarb** (v2.10.1): Package manager and build tool

## App Structure

### File Organization

```
your_app/
├── src/
│   ├── lib.cairo          # Main library file with module declarations
│   ├── app.cairo          # Main application logic and contract
│   ├── constants.cairo    # App constants (optional)
│   └── tests.cairo        # Test suite
├── Scarb.toml            # Package configuration
├── dojo_dev.toml         # Dojo development configuration
├── LICENSE               # License file
├── README.md             # App documentation
└── Makefile              # Build automation (optional)
```

### Essential Files

#### 1. `src/lib.cairo`
```cairo
mod app;
mod constants; // Optional
mod tests;
```

#### 2. `src/app.cairo` Structure
```cairo
use pixelaw::core::models::{pixel::{PixelUpdate}, registry::{App}};
use pixelaw::core::utils::{DefaultParameters, Position};
use starknet::{ContractAddress};

// Your app models (if needed)
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct YourAppModel {
    #[key]
    pub position: Position,
    // your fields...
}

// App interface
#[starknet::interface]
pub trait IYourAppActions<T> {
    // Hook functions (optional but recommended)
    fn on_pre_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    ) -> Option<PixelUpdate>;
    
    fn on_post_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    );
    
    // Main interaction function (required)
    fn interact(ref self: T, default_params: DefaultParameters);
    
    // Additional app-specific functions...
}

// App constants
pub const APP_KEY: felt252 = 'your_app_name';
pub const APP_ICON: felt252 = 0xf09f8fa0; // Unicode hex for emoji

// Main contract
#[dojo::contract]
pub mod your_app_actions {
    // Implementation...
}
```

### Scarb.toml Configuration

```toml
[package]
cairo-version = "=2.10.1"
name = "your_app"
version = "1.0.0"
edition = "2024_07"

[cairo]
sierra-replace-ids = true

[dependencies]
pixelaw = { git = "https://github.com/pixelaw/core", tag = "v0.7.8" }
dojo = { git = "https://github.com/dojoengine/dojo", tag = "v1.5.1" }

[dev-dependencies]
pixelaw_testing = { git = "https://github.com/pixelaw/core", tag = "v0.7.8" }
dojo_cairo_test = { git = "https://github.com/dojoengine/dojo", tag = "v1.5.1" }

[[target.starknet-contract]]
sierra = true

build-external-contracts = [
    "dojo::world::world_contract::world",
    "pixelaw::core::models::pixel::m_Pixel",
    "pixelaw::core::models::area::m_Area",
    "pixelaw::core::models::queue::m_QueueItem",
    "pixelaw::core::models::registry::m_App",
    "pixelaw::core::models::registry::m_AppName",
    "pixelaw::core::models::registry::m_CoreActionsAddress",
    "pixelaw::core::models::area::m_RTree",
    "pixelaw::core::events::e_QueueScheduled",
    "pixelaw::core::events::e_Notification",
    "pixelaw::core::actions::actions"
]

[tool.fmt]
sort-module-level-items = true
```

## Core Integration

### Essential Imports

```cairo
use dojo::model::{ModelStorage};
use pixelaw::core::actions::{IActionsDispatcherTrait as ICoreActionsDispatcherTrait};
use pixelaw::core::models::pixel::{Pixel, PixelUpdate, PixelUpdateResultTrait};
use pixelaw::core::models::registry::App;
use pixelaw::core::utils::{DefaultParameters, Position, get_callers, get_core_actions};
use starknet::{ContractAddress, contract_address_const, get_contract_address};
```

### App Registration

Every PixeLAW app must register itself with the core system:

```cairo
fn dojo_init(ref self: ContractState) {
    let mut world = self.world(@"pixelaw");
    let core_actions = get_core_actions(ref world);
    
    core_actions.new_app(contract_address_const::<0>(), APP_KEY, APP_ICON);
}
```

### Core Action Patterns

#### Basic Pixel Update
```cairo
let core_actions = get_core_actions(ref world);
let (player, system) = get_callers(ref world, default_params);

core_actions
    .update_pixel(
        player,
        system,
        PixelUpdate {
            position: default_params.position,
            color: Option::Some(0xFF0000), // Red color
            timestamp: Option::None,
            text: Option::Some(0xf09f8fa0), // House emoji
            app: Option::Some(system),
            owner: Option::Some(player),
            action: Option::None
        },
        Option::None, // area_hint
        false,
    )
    .unwrap();
```

#### Notifications
```cairo
core_actions
    .notification(
        position,
        default_params.color,
        Option::Some(player),
        Option::None,
        'Action completed!',
    );
```

#### Scheduled Actions (Queue System)
```cairo
let queue_timestamp = starknet::get_block_timestamp() + 60; // 1 minute delay
let mut calldata: Array<felt252> = ArrayTrait::new();
calldata.append(parameter1.into());
calldata.append(parameter2.into());

core_actions
    .schedule_queue(
        queue_timestamp,
        get_contract_address(),
        function_selector, // Use function selector hash
        calldata.span()
    );
```

### Hook System Implementation

Apps can implement hooks to intercept pixel updates from other apps:

#### Pre-Update Hook
```cairo
fn on_pre_update(
    ref self: ContractState,
    pixel_update: PixelUpdate,
    app_caller: App,
    player_caller: ContractAddress,
) -> Option<PixelUpdate> {
    let mut world = self.world(@"pixelaw");
    
    // Default: deny all changes
    let mut result = Option::None;
    
    // Allow specific apps or conditions
    if app_caller.name == 'trusted_app' {
        result = Option::Some(pixel_update);
    }
    
    result
}
```

#### Post-Update Hook
```cairo
fn on_post_update(
    ref self: ContractState,
    pixel_update: PixelUpdate,
    app_caller: App,
    player_caller: ContractAddress,
) {
    // React to changes made by other apps
    if app_caller.name == 'paint' {
        // Handle paint app interactions
    }
}
```

## Development Setup

### 1. Project Initialization

```bash
# Create new app directory
mkdir your_app && cd your_app

# Initialize Scarb project
scarb init --name your_app

# Copy Scarb.toml configuration from examples
# Create required directories and files
mkdir -p src
touch src/lib.cairo src/app.cairo src/tests.cairo
```

### 2. Development Environment

For local development, use the examples infrastructure:

```bash
# From examples/ directory
make start_core  # Start PixeLAW core infrastructure
make deploy_app APP=your_app  # Deploy your app
```

### 3. VSCode DevContainer (Recommended)

Use the provided DevContainer configuration for a complete development environment with all tools pre-installed.

## App Implementation

### Basic App Template

```cairo
use pixelaw::core::models::{pixel::{PixelUpdate}, registry::{App}};
use pixelaw::core::utils::{DefaultParameters, Position};
use starknet::{ContractAddress};

// Optional: Custom models for your app state
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct MyAppData {
    #[key]
    pub position: Position,
    pub created_by: ContractAddress,
    pub created_at: u64,
    pub custom_field: u32,
}

#[starknet::interface]
pub trait IMyAppActions<T> {
    fn on_pre_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    ) -> Option<PixelUpdate>;
    
    fn on_post_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    );
    
    fn interact(ref self: T, default_params: DefaultParameters);
}

pub const APP_KEY: felt252 = 'my_app';
pub const APP_ICON: felt252 = 0xf09f8ea8; // 🎨

#[dojo::contract]
pub mod my_app_actions {
    use dojo::model::{ModelStorage};
    use pixelaw::core::actions::{IActionsDispatcherTrait as ICoreActionsDispatcherTrait};
    use pixelaw::core::models::pixel::{Pixel, PixelUpdate, PixelUpdateResultTrait};
    use pixelaw::core::models::registry::App;
    use pixelaw::core::utils::{DefaultParameters, Position, get_callers, get_core_actions};
    use starknet::{ContractAddress, contract_address_const, get_contract_address, get_block_timestamp};
    use super::{IMyAppActions, MyAppData, APP_KEY, APP_ICON};

    fn dojo_init(ref self: ContractState) {
        let mut world = self.world(@"pixelaw");
        let core_actions = get_core_actions(ref world);
        core_actions.new_app(contract_address_const::<0>(), APP_KEY, APP_ICON);
    }

    #[abi(embed_v0)]
    impl ActionsImpl of IMyAppActions<ContractState> {
        fn on_pre_update(
            ref self: ContractState,
            pixel_update: PixelUpdate,
            app_caller: App,
            player_caller: ContractAddress,
        ) -> Option<PixelUpdate> {
            // Default: allow no changes
            Option::None
        }

        fn on_post_update(
            ref self: ContractState,
            pixel_update: PixelUpdate,
            app_caller: App,
            player_caller: ContractAddress,
        ) {
            // React to changes if needed
        }

        fn interact(ref self: ContractState, default_params: DefaultParameters) {
            let mut world = self.world(@"pixelaw");
            let core_actions = get_core_actions(ref world);
            let (player, system) = get_callers(ref world, default_params);
            let position = default_params.position;

            // Your app logic here
            let pixel: Pixel = world.read_model(position);
            
            // Example: Create app data model
            let app_data = MyAppData {
                position,
                created_by: player,
                created_at: get_block_timestamp(),
                custom_field: 42,
            };
            world.write_model(@app_data);

            // Update the pixel
            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        position,
                        color: Option::Some(default_params.color),
                        timestamp: Option::None,
                        text: Option::Some(APP_ICON),
                        app: Option::Some(system),
                        owner: Option::Some(player),
                        action: Option::None,
                    },
                    Option::None,
                    false,
                )
                .unwrap();

            // Send notification
            core_actions
                .notification(
                    position,
                    default_params.color,
                    Option::Some(player),
                    Option::None,
                    'My app activated!',
                );
        }
    }
}
```

### Common Patterns

#### 1. State Management with Models

```cairo
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct GameState {
    #[key]
    pub position: Position,
    pub game_id: u32,
    pub player: ContractAddress,
    pub status: felt252, // 'active', 'completed', 'failed'
    pub score: u32,
}
```

#### 2. Multi-pixel Operations

```cairo
// Update multiple pixels in a loop
let mut x = 0;
while x < size {
    let mut y = 0;
    while y < size {
        let pixel_position = Position { 
            x: position.x + x.into(), 
            y: position.y + y.into() 
        };
        
        core_actions
            .update_pixel(
                player,
                system,
                PixelUpdate {
                    position: pixel_position,
                    color: Option::Some(calculate_color(x, y)),
                    // ... other fields
                },
                Option::None,
                false,
            )
            .unwrap();
        
        y += 1;
    };
    x += 1;
};
```

#### 3. Player Integration

```cairo
// Access player data
use pixelaw::apps::player::{Player};

let mut player_data: Player = world.read_model(player);
player_data.lives += 1; // Reward player
world.write_model(@player_data);
```

#### 4. Cooldowns and Timing

```cairo
const COOLDOWN_SECONDS: u64 = 86400; // 24 hours

// Check cooldown
let current_timestamp = get_block_timestamp();
assert!(
    current_timestamp >= last_action_timestamp + COOLDOWN_SECONDS,
    "Cooldown not ready yet"
);
```

## Testing Strategy

### Test File Structure

```cairo
// src/tests.cairo
use dojo::model::{ModelStorage};
use dojo::world::{IWorldDispatcherTrait, WorldStorage, WorldStorageTrait};
use dojo_cairo_test::{
    ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
};

use your_app::app::{IYourAppActionsDispatcher, IYourAppActionsDispatcherTrait, your_app_actions, YourAppModel, m_YourAppModel};
use pixelaw::core::models::pixel::{Pixel};
use pixelaw::core::utils::{DefaultParameters, Position, encode_rgba};
use pixelaw_testing::helpers::{set_caller, setup_core, update_test_world};

fn deploy_app(ref world: WorldStorage) -> IYourAppActionsDispatcher {
    let namespace = "your_app";

    let ndef = NamespaceDef {
        namespace: namespace.clone(),
        resources: [
            TestResource::Model(m_YourAppModel::TEST_CLASS_HASH),
            TestResource::Contract(your_app_actions::TEST_CLASS_HASH),
        ].span(),
    };
    
    let cdefs: Span<ContractDef> = [
        ContractDefTrait::new(@namespace, @"your_app_actions")
            .with_writer_of([dojo::utils::bytearray_hash(@namespace)].span())
    ].span();

    world.dispatcher.register_namespace(namespace.clone());
    update_test_world(ref world, [ndef].span());
    world.sync_perms_and_inits(cdefs);

    world.set_namespace(@namespace);
    let app_actions_address = world.dns_address(@"your_app_actions").unwrap();
    world.set_namespace(@"pixelaw");

    IYourAppActionsDispatcher { contract_address: app_actions_address }
}

#[test]
#[available_gas(3000000000)]
fn test_basic_interaction() {
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    let app_actions = deploy_app(ref world);

    set_caller(player_1);

    let position = Position { x: 10, y: 10 };
    let color = encode_rgba(255, 0, 0, 255);

    app_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position,
                color,
            },
        );

    // Verify pixel was updated
    let pixel: Pixel = world.read_model(position);
    assert(pixel.color == color, 'Pixel color mismatch');
    
    // Verify app model was created
    let app_data: YourAppModel = world.read_model(position);
    assert(app_data.created_by == player_1, 'Creator mismatch');
}

#[test]
#[available_gas(3000000000)]
#[should_panic(expected: ('Expected error message', 'ENTRYPOINT_FAILED'))]
fn test_failure_case() {
    // Test expected failures
}
```

### Testing Best Practices

1. **Setup Core**: Always use `setup_core()` for consistent test environment
2. **Deploy App**: Use proper namespace and permission setup
3. **Set Caller**: Use `set_caller()` to simulate different players
4. **Test Scenarios**: Cover success, failure, and edge cases
5. **Verify State**: Check both pixel state and app model state
6. **Gas Limits**: Set appropriate gas limits for complex tests

### Running Tests

```bash
cd your_app
sozo test
```

## Deployment

### Local Development

```bash
# From examples/ directory
./local_deploy.sh your_app
```

### Configuration Files

#### dojo_dev.toml
```toml
[world]
name = "pixelaw"
description = "PixeLAW Your App"
cover_uri = "file://assets/cover.png"
icon_uri = "file://assets/icon.png"
website = "https://github.com/your_username/your_app"
socials.x = "https://twitter.com/pixelaw"

[namespace]
default = "your_app"

[[namespace.mappings]]
namespace = "your_app"
account = "$DOJO_ACCOUNT_ADDRESS"
```

### Deployment Steps

1. **Build**: `sozo build`
2. **Migrate**: `sozo migrate`
3. **Initialize**: Register with core system via `dojo_init`
4. **Test**: Verify deployment with integration tests

## Best Practices

### Code Organization

1. **Separation of Concerns**: Keep app logic, models, and tests separate
2. **Clear Naming**: Use descriptive names for functions and variables
3. **Documentation**: Document public interfaces and complex logic
4. **Error Handling**: Provide clear error messages
5. **Gas Optimization**: Be mindful of gas costs in loops and complex operations

### App Design Patterns

#### 1. Simple Apps
- Single contract with minimal state
- Direct pixel manipulation
- Examples: Paint, basic games

#### 2. Complex Apps
- Multiple models for state management
- Queue system for delayed actions
- Player integration
- Examples: Snake, House, Maze

#### 3. Multi-App Integration
- Implement hooks for cross-app interactions
- Design for interoperability
- Consider permission models

### Security Considerations

1. **Input Validation**: Always validate input parameters
2. **Permission Checks**: Verify caller permissions
3. **State Consistency**: Ensure consistent state updates
4. **Reentrancy**: Be aware of reentrancy risks in hooks
5. **Integer Overflow**: Use safe arithmetic operations

### Performance Tips

1. **Batch Operations**: Group multiple pixel updates when possible
2. **Efficient Loops**: Minimize nested loops and complex calculations
3. **Model Design**: Keep models as small as necessary
4. **Event Usage**: Use notifications judiciously

### Common Pitfalls

1. **Namespace Confusion**: Ensure correct namespace usage
2. **Hook Conflicts**: Test app interactions thoroughly
3. **Gas Estimation**: Account for varying gas costs
4. **State Synchronization**: Handle concurrent access properly
5. **Error Propagation**: Don't suppress important errors

## Examples and References

### Study These Apps

1. **Core Apps** (`core/contracts/src/apps/`):
   - `paint.cairo`: Basic pixel manipulation
   - `snake.cairo`: Complex game logic with queue system
   - `house.cairo`: Area management and player integration
   - `player.cairo`: Player management and movement

2. **Example Apps** (`examples/`):
   - `chest/`: Simple reward system
   - `maze/`: Complex game with custom models
   - `minesweeper/`: Grid-based gameplay
   - `rps/`: Player vs player interactions

### Useful Resources

- [Dojo Documentation](https://book.dojoengine.org/)
- [Cairo Book](https://book.cairo-lang.org/)
- [PixeLAW Core Repository](https://github.com/pixelaw/core)
- [Starknet Documentation](https://docs.starknet.io/)

## Conclusion

Building PixeLAW apps requires understanding the core framework, following established patterns, and thorough testing. Start with simple apps and gradually build complexity as you become familiar with the system. The examples in this repository provide excellent templates for different types of applications.

Remember to:
- Always test thoroughly
- Follow the established patterns
- Consider app interactions
- Document your code
- Engage with the PixeLAW community for support

Happy building! 🎮✨