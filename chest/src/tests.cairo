use chest::app::{
    Chest, IChestActionsDispatcher, IChestActionsDispatcherTrait, chest_actions, m_Chest,
};
use dojo::model::{ModelStorage};
use dojo::world::{IWorldDispatcherTrait, WorldStorage, WorldStorageTrait};
use dojo_cairo_test::{
    ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
};

use pixelaw::{core::{models::pixel::Pixel, utils::{DefaultParameters, Position}}};
use pixelaw_testing::helpers::{set_caller, setup_core, update_test_world};
use starknet::{testing::{set_block_timestamp}};


// Chest app test constants
const CHEST_COLOR: u32 = 0xFFC107FF; // Gold color
const COOLDOWN_SECONDS: u64 = 86400; // 24 hours (matches chest.cairo)
const LIFE_REWARD: u32 = 1;


fn deploy_app(ref world: WorldStorage) -> IChestActionsDispatcher {
    let namespace = "chest";

    world.dispatcher.register_namespace(namespace.clone());

    let ndef = NamespaceDef {
        namespace: namespace.clone(),
        resources: [
            TestResource::Model(m_Chest::TEST_CLASS_HASH),
            TestResource::Contract(chest_actions::TEST_CLASS_HASH),
        ]
            .span(),
    };

    let cdefs: Span<ContractDef> = [
        ContractDefTrait::new(@namespace, @"chest_actions")
            .with_writer_of([dojo::utils::bytearray_hash(@namespace)].span())
    ]
        .span();

    update_test_world(ref world, [ndef].span());

    world.sync_perms_and_inits(cdefs);

    // Set the namespace so the chest_actions can be found
    world.set_namespace(@namespace);

    let chest_actions_address = world.dns_address(@"chest_actions").unwrap();

    // Set the namespace back to pixelaw so everything still works afterwards
    world.set_namespace(@"pixelaw");

    IChestActionsDispatcher { contract_address: chest_actions_address }
}

#[test]
#[available_gas(3000000000)]
fn test_place_chest() {
    // Initialize the world
    println!("test: About to setup core");
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    println!("test: Setup core completed");

    println!("test: About to deploy chest app");
    let chest_actions = deploy_app(ref world);
    println!("test: Deploy chest app completed");

    set_caller(player_1);
    println!("test: Set caller to player_1");

    // Define the position for our chest
    let chest_position = Position { x: 10, y: 10 };

    // Place a chest at the specified position using interact
    chest_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: chest_position,
                color: CHEST_COLOR,
            },
        );

    // Verify that the chest pixel has the correct color and emoji
    let chest_pixel: Pixel = world.read_model(chest_position);
    assert(chest_pixel.color == CHEST_COLOR, 'Chest should be gold');

    // Check that the chest model was created correctly
    world.set_namespace(@"chest");
    let chest: Chest = world.read_model(chest_position);
    assert(chest.placed_by == player_1, 'Chest owner mismatch');
    assert(!chest.is_collected, 'Chest should not be collected');
    assert(chest.position == chest_position, 'Chest position mismatch');
}

#[test]
#[available_gas(3000000000)]
#[should_panic(expected: ("Chest not ready yet", 'ENTRYPOINT_FAILED'))]
fn test_place_chest_on_occupied_position() {
    // Initialize the world
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    let chest_actions = deploy_app(ref world);

    set_caller(player_1);

    let chest_position = Position { x: 10, y: 10 };

    // Place first chest using interact
    chest_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: chest_position,
                color: CHEST_COLOR,
            },
        );

    // Try to place a second chest at the same position - should fail
    chest_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: chest_position,
                color: CHEST_COLOR,
            },
        );
}

#[test]
#[available_gas(3000000000)]
fn test_collect_chest() {
    // Initialize the world
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    let chest_actions = deploy_app(ref world);

    set_caller(player_1);

    // Set the initial timestamp
    let initial_timestamp: u64 = 1000;
    set_block_timestamp(initial_timestamp);

    // Place a chest using interact
    let chest_position = Position { x: 10, y: 10 };
    chest_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: chest_position,
                color: CHEST_COLOR,
            },
        );

    // Fast forward time to enable chest collection (24 hours + 1 second)
    set_block_timestamp(initial_timestamp + COOLDOWN_SECONDS + 1);

    // Collect chest using interact (click on chest)
    chest_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: chest_position,
                color: CHEST_COLOR,
            },
        );

    // Check if the chest was marked as collected
    world.set_namespace(@"chest");
    let chest: Chest = world.read_model(chest_position);
    assert(chest.is_collected, 'Chest should be collected');
    assert(
        chest.last_collected_at == initial_timestamp + COOLDOWN_SECONDS + 1,
        'Last collected time not updated',
    );

    // Check that the chest pixel changed to gray (collected state)
    world.set_namespace(@"pixelaw");
    let chest_pixel: Pixel = world.read_model(chest_position);
    assert(chest_pixel.color == 0x808080FF, 'Collected chest should be gray');
}

#[test]
#[available_gas(3000000000)]
#[should_panic(expected: ("Chest not ready yet", 'ENTRYPOINT_FAILED'))]
fn test_collect_chest_too_soon() {
    // Initialize the world
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    let chest_actions = deploy_app(ref world);

    set_caller(player_1);

    // Set the initial timestamp
    let initial_timestamp: u64 = 1000;
    set_block_timestamp(initial_timestamp);

    // Place a chest using interact
    let chest_position = Position { x: 10, y: 10 };
    chest_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: chest_position,
                color: CHEST_COLOR,
            },
        );

    // Fast forward time but not enough (only half the required time)
    set_block_timestamp(initial_timestamp + COOLDOWN_SECONDS / 2);

    // Try to collect chest too soon - should fail
    chest_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: chest_position,
                color: CHEST_COLOR,
            },
        );
}

#[test]
#[available_gas(3000000000)]
#[should_panic(expected: ("Chest already collected", 'ENTRYPOINT_FAILED'))]
fn test_collect_chest_already_collected() {
    // Initialize the world
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    let chest_actions = deploy_app(ref world);

    set_caller(player_1);

    // Set the initial timestamp
    let initial_timestamp: u64 = 1000;
    set_block_timestamp(initial_timestamp);

    // Place a chest using interact
    let chest_position = Position { x: 10, y: 10 };
    chest_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: chest_position,
                color: CHEST_COLOR,
            },
        );

    // Fast forward time to enable chest collection
    set_block_timestamp(initial_timestamp + COOLDOWN_SECONDS + 5);

    // Collect chest first time - should succeed
    chest_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: chest_position,
                color: CHEST_COLOR,
            },
        );

    // Try to collect the same chest again - should fail
    chest_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: chest_position,
                color: CHEST_COLOR,
            },
        );
}
