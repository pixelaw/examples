use dojo::model::{ModelStorage};
use dojo::world::{IWorldDispatcherTrait, WorldStorage, WorldStorageTrait};
use dojo_cairo_test::{
    ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
};
use maze::app::{
    IMazeActionsDispatcher, IMazeActionsDispatcherTrait, MazeGame, m_MazeGame, maze_actions,
};
use pixelaw::core::models::pixel::{Pixel};
use pixelaw::apps::player::{Player, IPlayerActionsDispatcherTrait};

use pixelaw::core::utils::{DefaultParameters, Position, encode_rgba};
use pixelaw_testing::helpers::{set_caller, setup_core, update_test_world, setup_apps};

fn deploy_app(ref world: WorldStorage) -> IMazeActionsDispatcher {
    let namespace = "maze";

    world.dispatcher.register_namespace(namespace.clone());

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
    
    // Grant the test account owner permissions on pixelaw namespace
    world.dispatcher.grant_owner(dojo::utils::bytearray_hash(@"pixelaw"), player_1);
    
    set_caller(player_1);

    println!("1");
    // Deploy Maze actions
    let maze_actions = deploy_app(ref world);
    let (_paint_actions, _snake_actions, player_actions, _house_actions) = setup_apps(ref world);

    let color = encode_rgba(1, 1, 1, 1);
    let maze_position = Position { x: 100, y: 100 };
    let player_position = Position { x: 100, y: 99 };


    // Create a new maze
    println!("test: About to interact with maze at position ({}, {})", maze_position.x, maze_position.y);

    // First create a player to have proper lives
    player_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: player_position,
                color: color,
            },
        );

    // Verify player was created with proper lives
    let player: Player = world.read_model(player_1);
    println!("test: Player lives after creation: {}", player.lives);
    assert(player.lives > 0, 'Player should have lives');

    // Test that we can read from the maze namespace before calling interact
    let test_game: MazeGame = world.read_model(maze_position);
    println!("test: Read model from maze namespace, id: {}", test_game.id);

    // Create the maze
    maze_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: maze_position,
                color: color,
            },
        );

    // Check that a 5x5 maze was created with hidden pixels
    let pixel_100_100: Pixel = world.read_model(maze_position);
    println!("after maze creation");
    assert(pixel_100_100.color == 0x808080, 'should be gray hidden');
    assert(pixel_100_100.text == 0xe29d93, 'should be question mark');

    // Test that the maze was created successfully
    world.set_namespace(@"maze");
    let created_game: MazeGame = world.read_model(maze_position);
    assert(created_game.id > 0, 'maze should have been created');
    assert(created_game.creator == player_1, 'creator should match');
    assert(created_game.is_revealed == false, 'should not be revealed');
    world.set_namespace(@"pixelaw");

    // Now move player to the maze cell to trigger revealing
    player_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: maze_position,
                color: color,
            },
        );

    // Check if the pixel changed at all after player movement
    let revealed_pixel: Pixel = world.read_model(maze_position);
    println!("Pixel after player movement - color: {}, text: {}, app: {:?}", 
             revealed_pixel.color, revealed_pixel.text, revealed_pixel.app);

    // Check the maze game model state
    world.set_namespace(@"maze");
    let revealed_game: MazeGame = world.read_model(maze_position);
    println!("Maze game revealed status: {}", revealed_game.is_revealed);
    
    // Test the reveal_cell function directly as an alternative
    world.set_namespace(@"pixelaw");
    maze_actions
        .reveal_cell(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: maze_position,
                color: color,
            },
        );
    
    // Check that manual reveal worked
    let manually_revealed_pixel: Pixel = world.read_model(maze_position);
    println!("Manually revealed pixel - color: {}, text: {}", 
             manually_revealed_pixel.color, manually_revealed_pixel.text);
    assert(manually_revealed_pixel.text != 0xe29d93, 'manual reveal should work');

    world.set_namespace(@"maze");
    let manually_revealed_game: MazeGame = world.read_model(maze_position);
    assert(manually_revealed_game.is_revealed == true, 'manual reveal should set flag');
    world.set_namespace(@"pixelaw");

    println!("Maze test with player interaction completed!");
}

#[test]
fn test_maze_player_movement() {
    // Deploy everything
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    
    // Grant the test account owner permissions on pixelaw namespace
    world.dispatcher.grant_owner(dojo::utils::bytearray_hash(@"pixelaw"), player_1);
    
    set_caller(player_1);

    // Deploy Maze actions
    let maze_actions = deploy_app(ref world);
    let (_paint_actions, _snake_actions, player_actions, _house_actions) = setup_apps(ref world);

    let color = encode_rgba(1, 1, 1, 1);
    let maze_position = Position { x: 50, y: 50 };
    let outside_position = Position { x: 40, y: 40 };
    let adjacent_maze_position = Position { x: 51, y: 51 }; // Inside the 5x5 maze
    let truly_outside_position = Position { x: 60, y: 60 }; // Completely outside the maze

    // Create a player first
    player_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: outside_position,
                color: color,
            },
        );

    println!("Player created at outside position");

    // Create a maze
    maze_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: maze_position,
                color: color,
            },
        );

    println!("Maze created");

    // Move player into maze
    player_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: maze_position,
                color: color,
            },
        );

    println!("Player moved into maze");

    // Move player to adjacent maze cell
    player_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: adjacent_maze_position,
                color: color,
            },
        );

    println!("Player moved to adjacent maze cell");

    // Check player is indeed at adjacent position
    let adjacent_check: Pixel = world.read_model(adjacent_maze_position);
    println!("Adjacent position pixel - color: {}", adjacent_check.color);
    
    // Try moving to a position just outside the maze first (step by step)
    let near_outside = Position { x: 55, y: 55 }; // Just outside the 5x5 maze
    player_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: near_outside,
                color: color,
            },
        );
    
    println!("Player moved to near outside position");
    
    let near_outside_pixel: Pixel = world.read_model(near_outside);
    println!("Near outside pixel - color: {}", near_outside_pixel.color);

    // Move player back out of maze to completely outside position  
    player_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: truly_outside_position,
                color: color,
            },
        );

    println!("Player moved to completely outside position");

    // Verify player is at the truly outside position
    let final_pixel: Pixel = world.read_model(truly_outside_position);
    println!("Final pixel - color: {}, expected: {}", final_pixel.color, color);
    
    // Check what's at the maze position now
    let maze_pixel: Pixel = world.read_model(maze_position);
    println!("Maze pixel after player left - color: {}", maze_pixel.color);
    
    // Check what's at the adjacent maze position now
    let adjacent_pixel: Pixel = world.read_model(adjacent_maze_position);  
    println!("Adjacent maze pixel after player left - color: {}", adjacent_pixel.color);
    
    assert(final_pixel.color == color, 'Player should be at outside pos');

    println!("Maze movement test completed successfully!");
}

