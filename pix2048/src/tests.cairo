#[cfg(test)]
mod tests {
    use starknet::class_hash::Felt252TryIntoClassHash;
    use debug::PrintTrait;

    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
    use pixelaw::core::models::registry::{app, app_name, core_actions_address};

    use pixelaw::core::models::pixel::{Pixel, PixelUpdate};
    use pixelaw::core::models::pixel::{pixel};
    use pixelaw::core::models::permissions::{permissions};
    use pixelaw::core::utils::{get_core_actions, Direction, Position, DefaultParameters};
    use pixelaw::core::actions::{actions, IActionsDispatcher, IActionsDispatcherTrait};

    use dojo::utils::test::{spawn_test_world, deploy_contract};

    use pix2048::app::{pix2048_actions, INumberActionsDispatcher, INumberActionsDispatcherTrait};
    use pix2048::models::{NumberGame, NumberGameField, NumberValue};

    use zeroable::Zeroable;

    // Helper function: deploys world and actions
    fn deploy_world() -> (IWorldDispatcher, IActionsDispatcher, INumberActionsDispatcher) {
        // Deploy World and models
        let mut models = array![
            pixel::TEST_CLASS_HASH,
            app::TEST_CLASS_HASH,
            app_name::TEST_CLASS_HASH,
            core_actions_address::TEST_CLASS_HASH,
            permissions::TEST_CLASS_HASH,
        ];
        let world = spawn_test_world(["pixelaw"].span(), models.span());

        // Deploy Core actions
        let core_actions_address = world
            .deploy_contract('salt1', actions::TEST_CLASS_HASH.try_into().unwrap());
        let core_actions = IActionsDispatcher { contract_address: core_actions_address };

        // Deploy MyApp actions
        let pix2048_actions_address = world
            .deploy_contract('salt2', pix2048_actions::TEST_CLASS_HASH.try_into().unwrap());
        let pix2048_actions = INumberActionsDispatcher {
            contract_address: pix2048_actions_address
        };

        // Setup dojo auth
        // Grant writer permissions to core actions models
        world.grant_writer(selector_from_tag!("pixelaw-Pixel"), core_actions_address);
        world.grant_writer(selector_from_tag!("pixelaw-App"), core_actions_address);
        world.grant_writer(selector_from_tag!("pixelaw-AppName"), core_actions_address);
        world.grant_writer(selector_from_tag!("pixelaw-Permissions"), core_actions_address);
        world.grant_writer(selector_from_tag!("pixelaw-CoreActionsAddress"), core_actions_address);

        // Grant writer permissions to p_dash actions models
        world.grant_writer(selector_from_tag!("pixelaw-NumberGame"), pix2048_actions_address);
        world.grant_writer(selector_from_tag!("pixelaw-NumberGameField"), pix2048_actions_address);
        world.grant_writer(selector_from_tag!("pixelaw-NumberValue"), pix2048_actions_address);

        (world, core_actions, pix2048_actions)
    }

    #[test]
    #[available_gas(8000000000)]
    fn test_pix2048_actions() {
        // Deploy everything
        let (_world, core_actions, pix2048_actions) = deploy_world();

        core_actions.init();
        pix2048_actions.init();
        let player1 = starknet::contract_address_const::<0x1337>();
        starknet::testing::set_account_contract_address(player1);

        let color = encode_color(1, 1, 1);

        pix2048_actions
            .interact(
                DefaultParameters {
                    for_player: Zeroable::zero(),
                    for_system: Zeroable::zero(),
                    position: Position { x: 1, y: 1 },
                    color: color
                },
            );

        // let pixel_1_1 = get!(world, (1, 1), (Pixel));
        // assert(pixel_1_1.color == color, 'should be the color');
        'Passed test'.print();
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
}
