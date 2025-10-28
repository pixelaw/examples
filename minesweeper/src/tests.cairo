use dojo::model::ModelStorage;
use dojo::world::{IWorldDispatcherTrait, WorldStorage, WorldStorageTrait};
use dojo_cairo_test::{
    ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
};
use minesweeper::app::{
    Difficulty, IMinesweeperActionsDispatcher, IMinesweeperActionsDispatcherTrait, MineCell,
    MinesweeperGame, m_MineCell, m_MinesweeperGame, minesweeper_actions,
};
use pixelaw::core::models::pixel::PixelUpdate;
use pixelaw::core::models::registry::App;
use pixelaw::core::utils::{DefaultParameters, Position, encode_rgba};
use pixelaw_test_utils::{set_caller, setup_core, update_test_world};

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

    // Interact to initialize game with Easy difficulty
    app_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position,
                color,
            },
            Difficulty::Easy,
        );

    // Verify game state was created
    world.set_namespace(@"minesweeper");
    let game_state: MinesweeperGame = world.read_model(position);
    assert(game_state.creator == player_1, 'Player mismatch');
    assert(game_state.state == 1, 'Game state should be Open');
    assert(game_state.size == 4, 'Size should be 4 for Easy');
    assert(game_state.mines_amount == 3, 'Mines should be 3 for Easy');

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
        system: 0x123.try_into().unwrap(), name: 'test', icon: 0x1F4A0, action: 'test_action',
    };

    let result = app_actions.on_pre_update(pixel_update, test_app, player_1);
    assert(result.is_none(), 'Pre-update should return None');

    // Test post_update hook (should not panic)
    app_actions.on_post_update(pixel_update, test_app, player_1);
}

//#[test]
//#[available_gas(3000000000)]
//fn test_difficulty_levels() {
//    let (mut world, _core_actions, player_1, _player_2) = setup_core();
//    let app_actions = deploy_app(ref world);

//    set_caller(player_1);

//    let color = encode_rgba(255, 0, 0, 255);

//    // Test Easy difficulty
//    let easy_position = Position { x: 10, y: 10 };
//    println!("Testing Easy difficulty at position: {}, {}", easy_position.x, easy_position.y);
//    app_actions
//        .interact(
//            DefaultParameters {
//                player_override: Option::None,
//                system_override: Option::None,
//                area_hint: Option::None,
//                position: easy_position,
//                color,
//            },
//            Difficulty::Easy,
//        );

//    world.set_namespace(@"minesweeper");
//    println!("Reading Easy game from minesweeper namespace");
//    let easy_game: MinesweeperGame = world.read_model(easy_position);
//    println!("Easy game - size: {}, mines: {}", easy_game.size, easy_game.mines_amount);
//    assert(easy_game.size == 4, 'Easy size should be 4');
//    assert(easy_game.mines_amount == 3, 'Easy mines should be 3');

//    // Test Medium difficulty
//    let medium_position = Position { x: 20, y: 20 };
//    println!("Testing Medium difficulty at position: {}, {}", medium_position.x,
//    medium_position.y);
//    app_actions
//        .interact(
//            DefaultParameters {
//                player_override: Option::None,
//                system_override: Option::None,
//                area_hint: Option::None,
//                position: medium_position,
//                color,
//            },
//            Difficulty::Medium,
//        );

//    println!("Reading Medium game from minesweeper namespace");
//    let medium_game: MinesweeperGame = world.read_model(medium_position);
//    println!("Medium game - size: {}, mines: {}", medium_game.size, medium_game.mines_amount);
//    assert(medium_game.size == 5, 'Medium size should be 5');
//    assert(medium_game.mines_amount == 6, 'Medium mines should be 6');

//    // Test Hard difficulty
//    let hard_position = Position { x: 30, y: 30 };
//    println!("Testing Hard difficulty at position: {}, {}", hard_position.x, hard_position.y);
//    app_actions
//        .interact(
//            DefaultParameters {
//                player_override: Option::None,
//                system_override: Option::None,
//                area_hint: Option::None,
//                position: hard_position,
//                color,
//            },
//            Difficulty::Hard,
//        );

//    println!("Reading Hard game from minesweeper namespace");
//    let hard_game: MinesweeperGame = world.read_model(hard_position);
//    println!("Hard game - size: {}, mines: {}", hard_game.size, hard_game.mines_amount);
//    assert(hard_game.size == 7, 'Hard size should be 7');
//    assert(hard_game.mines_amount == 12, 'Hard mines should be 12');

//    world.set_namespace(@"pixelaw");
//    println!("test_difficulty_levels completed successfully");
//}

#[test]
#[available_gas(3000000000)]
fn test_mine_placement() {
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    let app_actions = deploy_app(ref world);

    set_caller(player_1);

    let position = Position { x: 10, y: 10 };
    let color = encode_rgba(255, 0, 0, 255);

    // Initialize game with Easy difficulty
    app_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position,
                color,
            },
            Difficulty::Easy,
        );

    // Verify correct number of mines were placed
    world.set_namespace(@"minesweeper");
    let game_state: MinesweeperGame = world.read_model(position);
    assert(game_state.mines_amount == 3, 'Should have 3 mines');

    // Count actual mines
    let mut mine_count: u32 = 0;
    let mut x: u32 = 0;
    while x < game_state.size {
        let mut y: u32 = 0;
        while y < game_state.size {
            let cell_position = Position {
                x: position.x + x.try_into().unwrap(), y: position.y + y.try_into().unwrap(),
            };
            let cell: MineCell = world.read_model(cell_position);
            if cell.is_mine {
                mine_count += 1;
            }
            y += 1_u32;
        }
        x += 1_u32;
    }

    assert(mine_count == 3, 'Should have exactly 3 mines');
    world.set_namespace(@"pixelaw");
}

#[test]
#[available_gas(3000000000)]
fn test_simple_reveal_mechanics() {
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    let app_actions = deploy_app(ref world);

    set_caller(player_1);

    let position = Position { x: 10, y: 10 };
    let color = encode_rgba(255, 0, 0, 255);

    // Initialize game
    app_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position,
                color,
            },
            Difficulty::Easy,
        );

    // Test revealing cells - simplified mechanics
    world.set_namespace(@"minesweeper");
    let mut revealed_count = 0_u32;
    let mut x = 0_u32;
    while x < 4_u32 {
        let mut y = 0_u32;
        while y < 4_u32 && revealed_count < 3_u32 {
            let cell_position = Position {
                x: position.x + x.try_into().unwrap(), y: position.y + y.try_into().unwrap(),
            };

            // Try to reveal this cell
            world.set_namespace(@"pixelaw");
            app_actions
                .reveal(
                    DefaultParameters {
                        player_override: Option::None,
                        system_override: Option::None,
                        area_hint: Option::None,
                        position: cell_position,
                        color,
                    },
                );

            // Check if cell was revealed
            world.set_namespace(@"minesweeper");
            let cell: MineCell = world.read_model(cell_position);
            if cell.is_revealed {
                revealed_count += 1;

                // If we hit a mine, game should be over
                if cell.is_mine {
                    let game: MinesweeperGame = world.read_model(position);
                    assert(game.state == 3_u8, 'Game exploded');
                    revealed_count = 3_u32; // Exit loops
                }
            }
            y += 1_u32;
        }
        x += 1_u32;
    }
    world.set_namespace(@"pixelaw");
}


#[test]
#[available_gas(3000000000)]
#[should_panic(expected: ("Game not active", 'ENTRYPOINT_FAILED'))]
fn test_reveal_invalid_game_state() {
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    let app_actions = deploy_app(ref world);

    set_caller(player_1);

    let position = Position { x: 10, y: 10 };

    // Try to reveal a cell without a game - should panic
    app_actions
        .reveal(
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
fn test_cell_reveal_mechanics() {
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    let app_actions = deploy_app(ref world);

    set_caller(player_1);

    let position = Position { x: 10, y: 10 };
    let color = encode_rgba(255, 0, 0, 255);

    // Initialize game
    app_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position,
                color,
            },
            Difficulty::Easy,
        );

    // Test revealing a cell
    let cell_position = Position { x: position.x, y: position.y };
    app_actions
        .reveal(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: cell_position,
                color,
            },
        );

    // Verify cell was revealed
    world.set_namespace(@"minesweeper");
    let cell: MineCell = world.read_model(cell_position);
    assert(cell.is_revealed, 'Cell should be revealed');

    // Check game state based on what was revealed
    let game: MinesweeperGame = world.read_model(position);
    if cell.is_mine {
        // If it was a mine, game should be exploded
        assert(game.state == 3_u8, 'Game exploded if mine hit');
    } else {
        // If it was safe, game should still be active or finished
        assert(game.state == 1_u8 || game.state == 2_u8, 'Game active or finished');
    }

    // Test revealing already revealed cell - should not panic
    world.set_namespace(@"pixelaw");
    app_actions
        .reveal(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: cell_position,
                color,
            },
        );

    world.set_namespace(@"pixelaw");
}
