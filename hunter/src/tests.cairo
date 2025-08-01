use dojo::model::{ModelStorage};
use dojo::world::{IWorldDispatcherTrait, WorldStorage, WorldStorageTrait};
use dojo_cairo_test::{
    ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
};
use hunter::app::{
    IHunterActionsDispatcher, IHunterActionsDispatcherTrait, LastAttempt, hunter_actions,
    m_LastAttempt,
};
use pixelaw::core::models::pixel::{Pixel};

use pixelaw::core::utils::{DefaultParameters, Position, encode_rgba};
use pixelaw_testing::helpers::{set_caller, setup_core, update_test_world};

fn deploy_app(ref world: WorldStorage) -> IHunterActionsDispatcher {
    let namespace = "hunter";

    world.dispatcher.register_namespace(namespace.clone());

    let ndef = NamespaceDef {
        namespace: namespace.clone(),
        resources: [
            TestResource::Model(m_LastAttempt::TEST_CLASS_HASH),
            TestResource::Contract(hunter_actions::TEST_CLASS_HASH),
        ]
            .span(),
    };
    let cdefs: Span<ContractDef> = [
        ContractDefTrait::new(@namespace, @"hunter_actions")
            .with_writer_of([dojo::utils::bytearray_hash(@namespace)].span())
    ]
        .span();

    update_test_world(ref world, [ndef].span());
    world.sync_perms_and_inits(cdefs);

    world.set_namespace(@namespace);
    let hunter_actions_address = world.dns_address(@"hunter_actions").unwrap();
    world.set_namespace(@"pixelaw");

    IHunterActionsDispatcher { contract_address: hunter_actions_address }
}

#[test]
fn test_hunter_actions() {
    // Deploy everything
    let (mut world, _core_actions, player_1, _player_2) = setup_core();
    set_caller(player_1);

    // Deploy Hunter actions
    let hunter_actions = deploy_app(ref world);

    let color = encode_rgba(1, 1, 1, 1);
    let position = Position { x: 1, y: 1 };

    hunter_actions
        .interact(
            DefaultParameters {
                player_override: Option::None,
                system_override: Option::None,
                area_hint: Option::None,
                position,
                color: color,
            },
        );

    let pixel_1_1: Pixel = world.read_model(position);
    // The pixel should now have a color and potentially other properties set
    assert(pixel_1_1.color == color, 'pixel color should match');

    // Test that LastAttempt was recorded
    world.set_namespace(@"hunter");
    let last_attempt: LastAttempt = world.read_model(player_1);
    world.set_namespace(@"pixelaw");

    // Test that LastAttempt was recorded correctly
    assert(last_attempt.player == player_1, 'player should match');
    // In test environment, timestamp is 0 due to test setup
    assert(last_attempt.timestamp == 0, 'timestamp should be 0');
}

fn encode_color(r: u8, g: u8, b: u8) -> u32 {
    (r.into() * 0x10000) + (g.into() * 0x100) + b.into()
}

fn decode_color(color: u32) -> (u8, u8, u8) {
    let r = (color / 0x10000);
    let g = (color / 0x100) & 0xff;
    let b = color & 0xff;

    (r.try_into().unwrap(), g.try_into().unwrap(), b.try_into().unwrap())
}
