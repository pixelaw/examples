use dojo::world::{IWorldDispatcherTrait, WorldStorage, WorldStorageTrait};
use dojo_cairo_test::{
    ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
};
use pixelaw::core::utils::{DefaultParameters, Position};
use pixelaw_test_utils::{set_caller, setup_core, update_test_world};
use rps::app::{IRpsActionsDispatcher, IRpsActionsDispatcherTrait, m_Game, m_Player, rps_actions};


fn deploy_app(ref world: WorldStorage) -> IRpsActionsDispatcher {
    let namespace = "rps";

    world.dispatcher.register_namespace(namespace.clone());

    let ndef = NamespaceDef {
        namespace: namespace.clone(),
        resources: [
            TestResource::Model(m_Player::TEST_CLASS_HASH),
            TestResource::Model(m_Game::TEST_CLASS_HASH),
            TestResource::Contract(rps_actions::TEST_CLASS_HASH),
        ]
            .span(),
    };

    let cdefs: Span<ContractDef> = [
        ContractDefTrait::new(@namespace, @"rps_actions")
            .with_writer_of([dojo::utils::bytearray_hash(@namespace)].span())
    ]
        .span();

    update_test_world(ref world, [ndef].span());

    world.sync_perms_and_inits(cdefs);

    // Set the namespace so the myapp_actions can be found
    world.set_namespace(@namespace);

    let rps_actions_address = world.dns_address(@"rps_actions").unwrap();

    // Set the namespace back to pixelaw so everything still works afterwards
    world.set_namespace(@"pixelaw");

    IRpsActionsDispatcher { contract_address: rps_actions_address }
}

#[test]
#[available_gas(3000000000)]
fn test_playthrough() {
    // Deploy everything
    let (mut world, _core_actions, player_1, player_2) = setup_core();

    // Deploy rps actions
    let rps_actions = deploy_app(ref world);

    set_caller(player_1);

    // Set the players commitments (0=None, 1=Rock, 2=Paper, 3=Scissors)
    let player_1_commit: u8 = 3; // Scissors
    let player_2_commit: u8 = 2; // Paper

    // Set the player's secret salt. For the test its just different, client will send truly random
    let player_1_salt = '1';
    let player_1_hash: felt252 = hash_commit(player_1_commit, player_1_salt.into());

    // Player 1 submits their hashed commit
    rps_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: Position { x: 1, y: 1 },
                color: 0,
            },
            player_1_hash,
        );

    // Player 1 submits their hashed commit
    rps_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: Position { x: 1, y: 1 },
                color: 0,
            },
            player_1_hash,
        );

    // TODO assert state
    set_caller(player_2);

    // player_2 joins
    rps_actions
        .join(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: Position { x: 1, y: 1 },
                color: 0,
            },
            player_2_commit,
        );

    set_caller(player_1);

    // player_1 finishes
    rps_actions
        .finish(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: Position { x: 1, y: 1 },
                color: 0,
            },
            player_1_commit,
            player_1_salt,
        );

    // player_1 secondary (reset pixel)
    rps_actions
        .secondary(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position: Position { x: 1, y: 1 },
                color: 0,
            },
        );
}
use core::poseidon::poseidon_hash_span;
// TODO: implement proper psuedo random number generator
fn random(seed: felt252, min: u128, max: u128) -> u128 {
    let seed: u256 = seed.into();
    let range = max - min;

    (seed.low % range) + min
}

fn hash_commit(commit: u8, salt: felt252) -> felt252 {
    let mut hash_span = ArrayTrait::<felt252>::new();
    hash_span.append(commit.into());
    hash_span.append(salt.into());

    poseidon_hash_span(hash_span.span())
}
