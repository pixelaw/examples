use pixelaw::core::models::pixel::PixelUpdate;
use pixelaw::core::models::registry::App;
use pixelaw::core::utils::DefaultParameters;
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct LastAttempt {
    #[key]
    pub player: ContractAddress,
    pub timestamp: u64,
}

const APP_KEY: felt252 = 'hunter';
const APP_ICON: felt252 = 0xf09f8faf; // 🏯 target/hunter emoji
/// BASE means using the server's default manifest.json handler

#[starknet::interface]
pub trait IHunterActions<T> {
    fn on_pre_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    ) -> Option<PixelUpdate>;

    fn on_post_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    );

    fn interact(ref self: T, default_params: DefaultParameters);
}


#[dojo::contract]
pub mod hunter_actions {
    use core::num::traits::Zero;
    use core::poseidon::poseidon_hash_span;
    use dojo::model::ModelStorage;
    use pixelaw::core::actions::IActionsDispatcherTrait as ICoreActionsDispatcherTrait;
    use pixelaw::core::models::pixel::{Pixel, PixelUpdate, PixelUpdateResultTrait};
    use pixelaw::core::models::registry::App;
    use pixelaw::core::utils::{DefaultParameters, get_callers, get_core_actions};
    use starknet::{ContractAddress, get_block_timestamp};
    use super::{APP_ICON, APP_KEY, IHunterActions, LastAttempt};

    fn dojo_init(ref self: ContractState) {
        // Try to get pixelaw world first, fallback to default namespace if not available
        let mut world = self.world(@"pixelaw");
        let core_actions = get_core_actions(ref world);
        core_actions.new_app(0.try_into().unwrap(), APP_KEY, APP_ICON);
    }


    #[abi(embed_v0)]
    impl ActionsImpl of IHunterActions<ContractState> {
        fn on_pre_update(
            ref self: ContractState,
            pixel_update: PixelUpdate,
            app_caller: App,
            player_caller: ContractAddress,
        ) -> Option<PixelUpdate> {
            Option::None
        }

        fn on_post_update(
            ref self: ContractState,
            pixel_update: PixelUpdate,
            app_caller: App,
            player_caller: ContractAddress,
        ) {}

        fn interact(ref self: ContractState, default_params: DefaultParameters) {
            let mut world = self.world(@"pixelaw");
            let core_actions = get_core_actions(ref world);
            let (player, system) = get_callers(ref world, default_params);
            let position = default_params.position;

            let pixel: Pixel = world.read_model(position);
            let timestamp = get_block_timestamp();

            assert(pixel.owner.is_zero(), 'Hunt only empty pixels');

            let timestamp_felt252: felt252 = timestamp.into();
            let x_felt252: felt252 = position.x.into();
            let y_felt252: felt252 = position.y.into();

            // Generate hash (timestamp, x, y)
            let hash: u256 = poseidon_hash_span(
                array![timestamp_felt252, x_felt252, y_felt252].span(),
            )
                .into();

            // Check if the last bits match winning condition (1/1024 chance)
            let MASK: u256 = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc00;
            let winning = ((hash | MASK) == MASK);

            let mut text = Option::None;
            let mut owner = Option::None;

            if winning {
                text = Option::Some(0x2B50); // Star emoji
                owner = Option::Some(player);
            }

            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        position,
                        color: Option::Some(default_params.color),
                        timestamp: Option::None,
                        text,
                        app: Option::Some(system),
                        owner,
                        action: Option::None,
                    },
                    Option::None,
                    false,
                )
                .unwrap();

            // Update the timestamp for the cooldown
            let mut hunter_world = self.world(@"hunter");
            let mut last_attempt = LastAttempt { player, timestamp };
            hunter_world.write_model(@last_attempt);
        }
    }
}
