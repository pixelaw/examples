use dojo::model::{ModelStorage};
use dojo::world::{IWorldDispatcherTrait, WorldStorage, WorldStorageTrait};
use dojo_cairo_test::{
    ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
};
use maze::app::{IMazeActionsDispatcher, IMazeActionsDispatcherTrait, MazeGame, m_MazeGame, maze_actions};
use pixelaw::core::models::pixel::{Pixel};


use pixelaw::core::utils::{DefaultParameters, Position, encode_rgba};
use pixelaw_testing::helpers::{set_caller, setup_core, update_test_world};


fn deploy_app(ref world: WorldStorage) -> IMazeActionsDispatcher {
    let namespace = "maze";

    let ndef = NamespaceDef {
        namespace: namespace.clone(),
        resources: [
            TestResource::Model(m_MazeGame::TEST_CLASS_HASH),
            TestResource::Contract(maze_actions::TEST_CLASS_HASH),
        ]
            .span(),
    };
    let cdefs: Span<ContractDef> = [
        ContractDefTrait::new(@namespace, @"maze_actions")
            .with_writer_of([dojo::utils::bytearray_hash(@namespace)].span())
    ]
        .span();

    world.dispatcher.register_namespace(namespace.clone());
    update_test_world(ref world, [ndef].span());
    world.sync_perms_and_inits(cdefs);

    world.set_namespace(@namespace);
    let maze_actions_address = world.dns_address(@"maze_actions").unwrap();
    world.set_namespace(@"pixelaw");

    IMazeActionsDispatcher { contract_address: maze_actions_address }
}

#[test]
fn test_maze_actions() {
    // Deploy everything
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    //println!("Started test");
    set_caller(player_1);

    println!("1");
    // Deploy Maze actions
    let maze_actions = deploy_app(ref world);

    let color = encode_rgba(1, 1, 1, 1);
    let position = Position { x: 100, y: 100 };
    
    // Create a new maze
    println!("test: About to interact with maze at position ({}, {})", position.x, position.y);
    
    // Test that we can read from the maze namespace before calling interact
    let test_game: MazeGame = world.read_model(position);
    println!("test: Read model from maze namespace, id: {}", test_game.id);
    
    maze_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position,
                color: color,
            },
        );

    // Check that a 5x5 maze was created with hidden pixels
    let pixel_100_100: Pixel = world.read_model(position);
    assert(pixel_100_100.color == 0x808080, 'should be gray hidden');
    assert(pixel_100_100.text == 'U+2753', 'should be question mark');

    // Try revealing a cell
    maze_actions
        .reveal_cell(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position,
                color: color,
            },
        );

    // Check that the cell was revealed
    let revealed_pixel: Pixel = world.read_model(position);
    assert(revealed_pixel.text != 'U+2753', 'should be revealed');
    
    // Test trap functionality by revealing a trap cell 
    let trap_position = Position { x: 102, y: 101 }; // This should be a trap in maze layout 1
    
    // Set up player with some lives for testing
    let mut test_player: pixelaw::apps::player::Player = world.read_model(player_1);
    test_player.lives = 5; // Give player 5 lives
    world.write_model(@test_player);
    
    println!("Set player lives to: {}", test_player.lives);
    
    // Test trap functionality
    if test_player.lives > 0 {
        let initial_lives = test_player.lives;
        
        // Reveal the trap cell
        maze_actions
            .reveal_cell(
                DefaultParameters {
                    player_override: Option::None,
                    system_override: Option::None,
                    area_hint: Option::None,
                    position: trap_position,
                    color: color,
                },
            );
            
        // Check that player lost a life
        let updated_player: pixelaw::apps::player::Player = world.read_model(player_1);
        assert(updated_player.lives == initial_lives - 1, 'should lose a life');
        
        // Check that trap was revealed with explosion emoji
        let trap_pixel: Pixel = world.read_model(trap_position);
        assert(trap_pixel.text == 'U+1F4A5', 'should be explosion emoji');
        assert(trap_pixel.color == 0xFF0000, 'should be red');
        
        println!("Trap test passed!");
    } else {
        println!("Player has no lives, skipping trap test");
    }
    
    println!("Maze test with traps completed!");
}

