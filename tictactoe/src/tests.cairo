use dojo::model::{ModelStorage};
use dojo::world::{IWorldDispatcherTrait, WorldStorage, WorldStorageTrait};
use pixelaw::core::actions::{IActionsDispatcherTrait};
use dojo_cairo_test::{
    ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
};

use tictactoe::app::{
    ITicTacToeActionsDispatcher, ITicTacToeActionsDispatcherTrait, tictactoe_actions, TicTacToeGame,
    TicTacToeCell, m_TicTacToeGame, m_TicTacToeCell, GameState, CellState,
};
use pixelaw::core::models::pixel::{Pixel, PixelUpdate, PixelUpdateResultTrait};
use pixelaw::core::utils::{DefaultParameters, Position, encode_rgba};
use pixelaw_testing::helpers::{set_caller, setup_core, update_test_world};

fn deploy_app(ref world: WorldStorage) -> ITicTacToeActionsDispatcher {
    let namespace = "tictactoe";

    world.dispatcher.register_namespace(namespace.clone());

    let ndef = NamespaceDef {
        namespace: namespace.clone(),
        resources: [
            TestResource::Model(m_TicTacToeGame::TEST_CLASS_HASH),
            TestResource::Model(m_TicTacToeCell::TEST_CLASS_HASH),
            TestResource::Contract(tictactoe_actions::TEST_CLASS_HASH),
        ]
            .span(),
    };
    let cdefs: Span<ContractDef> = [
        ContractDefTrait::new(@namespace, @"tictactoe_actions")
            .with_writer_of([dojo::utils::bytearray_hash(@namespace)].span())
    ]
        .span();

    update_test_world(ref world, [ndef].span());
    world.sync_perms_and_inits(cdefs);

    world.set_namespace(@namespace);
    let tictactoe_actions_address = world.dns_address(@"tictactoe_actions").unwrap();
    world.set_namespace(@"pixelaw");

    ITicTacToeActionsDispatcher { contract_address: tictactoe_actions_address }
}

#[test]
#[available_gas(3000000000)]
fn test_tictactoe_game_creation() {
    // Deploy everything
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    set_caller(player_1);

    // Deploy TicTacToe actions
    let tictactoe_actions = deploy_app(ref world);

    let color = encode_rgba(255, 0, 0, 255);
    let position = Position { x: 10, y: 10 };

    // Create a new game
    tictactoe_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position,
                color: color,
            },
        );

    // Check that the game was created
    world.set_namespace(@"tictactoe");
    let game: TicTacToeGame = world.read_model(position);
    assert(game.player == player_1, 'Game creator mismatch');
    assert(game.state == GameState::Active, 'Game should be active');
    assert(game.moves_left == 9, 'Should have 9 moves left');
    world.set_namespace(@"pixelaw");

    // Check that a 3x3 grid was created
    let pixel_10_10: Pixel = world.read_model(position);
    assert(pixel_10_10.owner == player_1, 'Pixel should be owned by player');

    // Check corner pixels
    let pixel_12_12: Pixel = world.read_model(Position { x: 12, y: 12 });
    assert(pixel_12_12.owner == player_1, 'Corner pixel should be owned');
}

#[test]
#[available_gas(3000000000)]
fn test_tictactoe_make_move() {
    // Deploy everything
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    set_caller(player_1);

    let tictactoe_actions = deploy_app(ref world);

    let color = encode_rgba(255, 0, 0, 255);
    let position = Position { x: 10, y: 10 };

    // Create a new game
    tictactoe_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position,
                color: color,
            },
        );

    // Make a move at position (10, 10)
    tictactoe_actions
        .make_move(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position,
                color: color,
            },
        );

    // Check that the cell was updated
    world.set_namespace(@"tictactoe");
    let cell: TicTacToeCell = world.read_model(position);
    assert(cell.cell_state == CellState::Player, 'Cell should be Player');

    // Check that game moves were decremented (player + AI move)
    let game: TicTacToeGame = world.read_model(position);
    assert(game.moves_left <= 7, 'Moves should be decremented'); // Player move + AI move
    world.set_namespace(@"pixelaw");

    // Check that the pixel was updated with X symbol
    let pixel: Pixel = world.read_model(position);
    assert(pixel.text == 0x58, 'Should show X symbol'); // X symbol
}

#[test]
#[available_gas(3000000000)]
#[should_panic(expected: ("Cell already occupied", 'ENTRYPOINT_FAILED'))]
fn test_tictactoe_cannot_occupy_same_cell() {
    // Deploy everything
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    set_caller(player_1);

    let tictactoe_actions = deploy_app(ref world);

    let color = encode_rgba(255, 0, 0, 255);
    let position = Position { x: 10, y: 10 };

    // Create a new game
    tictactoe_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position,
                color: color,
            },
        );

    // Make first move
    tictactoe_actions
        .make_move(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position,
                color: color,
            },
        );

    // Try to make move on same cell - should fail
    tictactoe_actions
        .make_move(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position,
                color: color,
            },
        );
}

#[test]
#[available_gas(3000000000)]
#[should_panic(expected: ("Need 3x3 empty area", 'ENTRYPOINT_FAILED'))]
fn test_tictactoe_requires_empty_area() {
    // Deploy everything
    let (mut world, core_actions, player_1, _player_2) = setup_core();
    set_caller(player_1);

    let tictactoe_actions = deploy_app(ref world);

    let position = Position { x: 10, y: 10 };

    // Occupy one pixel in the 3x3 area first
    core_actions
        .update_pixel(
            player_1,
            core_actions.contract_address,
            PixelUpdate {
                position: Position { x: 11, y: 11 },
                color: Option::Some(0xFF0000),
                timestamp: Option::None,
                text: Option::None,
                app: Option::Some(core_actions.contract_address),
                owner: Option::Some(player_1),
                action: Option::None,
            },
            Option::None,
            false,
        )
        .unwrap();

    // Try to create game - should fail because area is not empty
    tictactoe_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position,
                color: encode_rgba(255, 0, 0, 255),
            },
        );
}

#[test]
#[available_gas(3000000000)]
fn test_tictactoe_game_integration() {
    // Deploy everything
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    set_caller(player_1);

    let tictactoe_actions = deploy_app(ref world);

    let color = encode_rgba(255, 0, 0, 255);
    let position = Position { x: 10, y: 10 };

    // Create game by calling interact on empty area
    tictactoe_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position,
                color: color,
            },
        );

    // Make moves by calling interact on existing game cells
    let move_position = Position { x: 11, y: 11 }; // Different cell

    tictactoe_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: move_position,
                color: color,
            },
        );

    // Verify both pixels are updated correctly
    let origin_pixel: Pixel = world.read_model(position);
    let move_pixel: Pixel = world.read_model(move_position);

    assert(origin_pixel.owner == player_1, 'Origin should be owned');
    assert(move_pixel.owner == player_1, 'Move pixel should be owned');
    assert(move_pixel.text == 0x58, 'Should show X symbol');
}
