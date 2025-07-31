use dojo::model::{ModelStorage};
use dojo::world::{IWorldDispatcherTrait, WorldStorage, WorldStorageTrait};
use dojo_cairo_test::{
    ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
};

use pix2048::app::{
    GameState, IPix2048ActionsDispatcher, IPix2048ActionsDispatcherTrait, m_GameState,
    pix2048_actions,
};
use pixelaw::core::models::pixel::{Pixel, PixelUpdate};
use pixelaw::core::models::registry::App;
use pixelaw::core::utils::{DefaultParameters, Position, encode_rgba};
use pixelaw_testing::helpers::{set_caller, setup_core, update_test_world};

fn deploy_app(ref world: WorldStorage) -> IPix2048ActionsDispatcher {
    let namespace = "pix2048";

    let ndef = NamespaceDef {
        namespace: namespace.clone(),
        resources: [
            TestResource::Model(m_GameState::TEST_CLASS_HASH),
            TestResource::Contract(pix2048_actions::TEST_CLASS_HASH),
        ]
            .span(),
    };

    let cdefs: Span<ContractDef> = [
        ContractDefTrait::new(@namespace, @"pix2048_actions")
            .with_writer_of([dojo::utils::bytearray_hash(@namespace)].span())
    ]
        .span();

    world.dispatcher.register_namespace(namespace.clone());
    update_test_world(ref world, [ndef].span());
    world.sync_perms_and_inits(cdefs);

    world.set_namespace(@namespace);
    let app_actions_address = world.dns_address(@"pix2048_actions").unwrap();
    world.set_namespace(@"pixelaw");

    IPix2048ActionsDispatcher { contract_address: app_actions_address }
}

#[test]
#[available_gas(3000000000)]
fn test_game_initialization() {
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    let app_actions = deploy_app(ref world);

    set_caller(player_1);

    let position = Position { x: 10, y: 10 };
    let color = encode_rgba(255, 0, 0, 255);

    // Interact to initialize game
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

    // Verify game state was created
    world.set_namespace(@"pix2048");
    let game_state: GameState = world.read_model(position);
    assert(game_state.player == player_1, 'Player mismatch');
    assert(game_state.moves == 0, 'Moves should be 0');

    world.set_namespace(@"pixelaw");

    // Verify pixel was updated for game
    let pixel: Pixel = world.read_model(position);
    assert(pixel.owner == player_1, 'Pixel owner mismatch');
}

#[test]
#[available_gas(3000000000)]
fn test_move_operations() {
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    let app_actions = deploy_app(ref world);

    set_caller(player_1);

    let position = Position { x: 10, y: 10 };
    let color = encode_rgba(255, 0, 0, 255);

    // Initialize game first
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

    // Test move operations by clicking on control pixels
    let up_position = Position { x: position.x, y: position.y - 1 };
    app_actions
        .move_up(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: up_position,
                color,
            },
        );

    // Verify moves were incremented
    world.set_namespace(@"pix2048");
    let game_state: GameState = world.read_model(position);
    assert(game_state.moves == 1, 'Moves should be 1');

    world.set_namespace(@"pixelaw");
}

#[test]
#[available_gas(3000000000)]
fn test_hook_functions() {
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    let app_actions = deploy_app(ref world);

    set_caller(player_1);

    // Test pre_update hook (should return None by default)
    let pixel_update = PixelUpdate {
        position: Position { x: 5, y: 5 },
        color: Option::Some(0xFF0000FF),
        timestamp: Option::None,
        text: Option::Some('test'),
        app: Option::None,
        owner: Option::None,
        action: Option::None,
    };

    let test_app = App {
        system: starknet::contract_address_const::<0x123>(),
        name: 'test',
        icon: 0x1F4A0,
        action: 'test_action',
    };

    let result = app_actions.on_pre_update(pixel_update, test_app, player_1);
    assert(result.is_none(), 'Pre-update should return None');

    // Test post_update hook (should not panic)
    app_actions.on_post_update(pixel_update, test_app, player_1);
}
