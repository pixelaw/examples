# Dojo 1.7.1 Upgrade Guide

This document summarizes all necessary changes to upgrade PixeLAW projects to Dojo 1.7.1.

## Overview

Dojo 1.7.1 introduces several breaking changes, particularly around model storage and enum handling. This guide covers all required updates for core contracts, example apps, and tooling.

## 1. Toolchain Version Updates

### Required Versions
Update your `.tool-versions` file or asdf configuration:

```
scarb 2.12.2
sozo 1.7.1
katana 1.7.1
torii 1.7.1
```

### Installation
```bash
asdf install scarb 2.12.2
asdf install dojo 1.7.1
asdf set global scarb 2.12.2
```

## 2. Scarb.toml Configuration Changes

### Add Dojo Macros Plugin

All `Scarb.toml` files must include the precompiled `dojo_cairo_macros` plugin using `allow-prebuilt-plugins`:

```toml
[package]
cairo-version = "2.12.2"

[dependencies]
dojo = { git = "https://github.com/dojoengine/dojo", tag = "v1.7.1" }

[dev-dependencies]
cairo_test = "2.12.2"
dojo_cairo_test = { git = "https://github.com/dojoengine/dojo", tag = "v1.7.1" }

[tool.scarb]
allow-prebuilt-plugins = ["dojo_cairo_macros"]
```

**Note**: Dojo 1.7.1 uses precompiled proc macros, which removes the need for having Rust/Cargo installed locally.

### Update Cairo Version
Change `cairo-version` from previous versions to `"2.12.2"` or `"=2.12.2"`

## 3. Model Storage Changes (BREAKING)

### DojoStore Trait Requirements

**All enums in Dojo models MUST:**
1. Derive the `Default` trait
2. Set a `#[default]` variant using the attribute macro

#### Before (Dojo < 1.7):
```cairo
#[derive(Drop, Serde)]
enum Direction {
    North,
    East,
    South,
    West
}
```

#### After (Dojo 1.7.1):
```cairo
#[derive(Drop, Serde, Default)]
enum Direction {
    North,
    East,
    #[default]
    South,
    West
}
```

### Model Trait Derivation

**For new projects or models without existing data:**
```cairo
#[derive(Drop, Serde, DojoStore, Default)]
enum MyEnum {
    Variant1,
    #[default]
    Variant2
}
```

**For existing projects with production data:**
```cairo
// Use DojoLegacyStore to preserve existing storage
#[derive(Drop, Serde, DojoLegacyStore, Default)]
enum MyEnum {
    Variant1,
    #[default]
    Variant2
}
```

### Why This Change?

- **Uninitialized Storage**: Previously, uninitialized enum storage defaulted to index 0. Now it defaults to the `#[default]` variant.
- **Data Migration**: Using `DojoLegacyStore` preserves old behavior for existing data.
- **Explicit Initialization**: Models should be explicitly initialized before use to avoid undefined behavior.

## 4. Testing Framework Updates

### dojo-cairo-test Changes

The `spawn_test_world` function now requires passing the world class hash:

#### Before:
```cairo
use dojo::world::{WorldStorageTrait};
use dojo_cairo_test::{spawn_test_world};

#[test]
fn test_something() {
    let world = spawn_test_world();
    // ...
}
```

#### After:
```cairo
use dojo::world::{WorldStorageTrait, world};
use dojo_cairo_test::{spawn_test_world};

#[test]
fn test_something() {
    let world = spawn_test_world([].span(), world::TEST_CLASS_HASH);
    // ...
}
```

### Starknet Foundry Support

Dojo 1.7.1 adds support for Starknet Foundry testing:

```toml
[dev-dependencies]
dojo_snf_test = { git = "https://github.com/dojoengine/dojo", tag = "v1.7.1" }
snforge_std = { git = "https://github.com/foundry-rs/starknet-foundry", tag = "v0.31.0" }
```

## 5. PixeLAW-Specific Considerations

### Core Models to Update

Review all enum definitions in:
- `core/contracts/src/core/models/*.cairo`
- Example app models in `examples/*/src/*.cairo`

### Common Enum Patterns

#### Alert Enum (if used):
```cairo
#[derive(Drop, Serde, Default)]
enum AlertType {
    #[default]
    None,
    Info,
    Warning,
    Error
}
```

#### Game State Enums:
```cairo
#[derive(Drop, Serde, Default)]
enum GameState {
    #[default]
    NotStarted,
    InProgress,
    Completed
}
```

## 6. Migration Checklist

### For All Projects:

- [ ] Update `.tool-versions` to Scarb 2.12.2, Dojo 1.7.1
- [ ] Update all `Scarb.toml` files:
  - [ ] Set `cairo-version = "2.12.2"`
  - [ ] Update `dojo` dependency to `tag = "v1.7.1"`
  - [ ] Add `allow-prebuilt-plugins = ["dojo_cairo_macros"]`
- [ ] Review all enum definitions:
  - [ ] Add `Default` to derive list
  - [ ] Add `#[default]` attribute to appropriate variant
- [ ] Update test files:
  - [ ] Import `world` from `dojo::world`
  - [ ] Pass `world::TEST_CLASS_HASH` to `spawn_test_world`
- [ ] Run `sozo build` to verify compilation
- [ ] Run `sozo test` to verify tests pass
- [ ] Test deployment to local Katana

### For Production/Existing Data:

- [ ] Identify models with enum fields that have existing data
- [ ] Use `DojoLegacyStore` instead of `DojoStore` for these models
- [ ] Plan data migration strategy if switching to `DojoStore`
- [ ] Test migration on testnet before mainnet deployment

## 7. Example Updates

### Minimal Scarb.toml for PixeLAW App

```toml
[package]
cairo-version = "2.12.2"
name = "my_pixelaw_app"
version = "0.1.0"
edition = "2024_07"

[cairo]
sierra-replace-ids = true

[dependencies]
pixelaw = { path = "../../core/contracts" }
dojo = { git = "https://github.com/dojoengine/dojo", tag = "v1.7.1" }

[dev-dependencies]
pixelaw_testing = { path = "../../core/pixelaw_testing" }
dojo_cairo_test = { git = "https://github.com/dojoengine/dojo", tag = "v1.7.1" }

[tool.scarb]
allow-prebuilt-plugins = ["dojo_cairo_macros"]

[[target.starknet-contract]]
sierra = true
build-external-contracts = [
    "dojo::world::world_contract::world",
    "pixelaw::core::models::pixel::m_Pixel",
    # ... other models
]
```

### Example Model with Enum

```cairo
use starknet::ContractAddress;

#[derive(Drop, Serde, Default)]
enum CellState {
    #[default]
    Hidden,
    Revealed,
    Flagged
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct Cell {
    #[key]
    position: (u32, u32),
    state: CellState,
    is_mine: bool,
    adjacent_mines: u8,
    owner: ContractAddress
}
```

## 8. Common Issues and Solutions

### Issue: "cannot find package `cairo_test =2.12.2`"
**Solution**: Upgrade Scarb to 2.12.2

### Issue: "enum must derive Default trait"
**Solution**: Add `Default` to derive list and `#[default]` to a variant

### Issue: "spawn_test_world expects 2 arguments"
**Solution**: Import `world` and pass `world::TEST_CLASS_HASH` as second argument

### Issue: Build fails with macro errors
**Solution**: Add `allow-prebuilt-plugins = ["dojo_cairo_macros"]` to `[tool.scarb]` section in your Scarb.toml

## 9. Additional Resources

- [Official Dojo 1.7 Upgrade Guide](https://book.dojoengine.org/framework/upgrading/dojo-1-7)
- [Dojo Documentation](https://book.dojoengine.org/)
- [PixeLAW Core Repository](https://github.com/pixelaw/core)

## 10. Version History

- **Dojo 1.7.1**: Latest stable release with precompiled proc macros and enum storage changes
- **Cairo 2.12.2**: Required Cairo version
- **Scarb 2.12.2**: Required Scarb version

---

**Last Updated**: October 2024
**PixeLAW Core Version**: 0.7.9+
**Dojo Version**: 1.7.1+
