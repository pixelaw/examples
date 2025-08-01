use dojo::model::{ModelStorage};
use dojo::world::{IWorldDispatcherTrait, WorldStorage, WorldStorageTrait};
use dojo_cairo_test::{
    ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
};

use minesweeper::app::{
    IMinesweeperActionsDispatcher, IMinesweeperActionsDispatcherTrait, MineCell, MinesweeperGame,
    m_MineCell, m_MinesweeperGame, minesweeper_actions,
};
use pixelaw::core::models::pixel::{PixelUpdate};
use pixelaw::core::models::registry::App;
use pixelaw::core::utils::{DefaultParameters, Position, encode_rgba};
use pixelaw_testing::helpers::{set_caller, setup_core, update_test_world};

fn deploy_app(ref world: WorldStorage) -> IMinesweeperActionsDispatcher {
    let namespace = "minesweeper";

    let ndef = NamespaceDef {
        namespace: namespace.clone(),
        resources: [
            TestResource::Model(m_MinesweeperGame::TEST_CLASS_HASH),
            TestResource::Model(m_MineCell::TEST_CLASS_HASH),
            TestResource::Contract(minesweeper_actions::TEST_CLASS_HASH),
        ]
            .span(),
    };

    let cdefs: Span<ContractDef> = [
        ContractDefTrait::new(@namespace, @"minesweeper_actions")
            .with_writer_of([dojo::utils::bytearray_hash(@namespace)].span())
    ]
        .span();

    world.dispatcher.register_namespace(namespace.clone());
    update_test_world(ref world, [ndef].span());
    world.sync_perms_and_inits(cdefs);

    world.set_namespace(@namespace);
    let app_actions_address = world.dns_address(@"minesweeper_actions").unwrap();
    world.set_namespace(@"pixelaw");

    IMinesweeperActionsDispatcher { contract_address: app_actions_address }
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
            3, // size
            2 // mines_amount
        );

    // Verify game state was created
    world.set_namespace(@"minesweeper");
    let game_state: MinesweeperGame = world.read_model(position);
    assert(game_state.creator == player_1, 'Player mismatch');
    assert(game_state.state == 1, 'Game state should be Open');
    assert(game_state.size == 3, 'Size should be 3');
    assert(game_state.mines_amount == 2, 'Mines should be 2');

    world.set_namespace(@"pixelaw");

    // Verify some cells were created
    let cell_position = Position { x: position.x, y: position.y };
    world.set_namespace(@"minesweeper");
    let cell: MineCell = world.read_model(cell_position);
    assert(cell.game_position == position, 'Game position mismatch');

    world.set_namespace(@"pixelaw");
}

#[test]
#[available_gas(3000000000)]
fn test_flag_operations() {
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
            3,
            2,
        );

    // Test flagging a cell
    let cell_position = Position { x: position.x, y: position.y };
    app_actions
        .flag(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: cell_position,
                color,
            },
        );

    // Verify cell was flagged
    world.set_namespace(@"minesweeper");
    let cell: MineCell = world.read_model(cell_position);
    assert(cell.is_flagged, 'Cell should be flagged');

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
