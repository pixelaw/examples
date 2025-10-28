// use pixelaw::apps::player::{Player}; // TODO: Re-enable when Player model is properly set up
use pixelaw::core::models::pixel::PixelUpdate;
use pixelaw::core::models::registry::App;
use pixelaw::core::utils::{DefaultParameters, Position};
use starknet::ContractAddress;

/// Chest Model to keep track of chests and their collection status
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Chest {
    #[key]
    pub position: Position,
    pub placed_by: ContractAddress,
    pub placed_at: u64,
    pub is_collected: bool,
    pub last_collected_at: u64,
}

#[starknet::interface]
pub trait IChestActions<T> {
    fn on_pre_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    ) -> Option<PixelUpdate>;
    fn on_post_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    );
    fn interact(ref self: T, default_params: DefaultParameters);
    fn place_chest(ref self: T, default_params: DefaultParameters);
    fn collect_chest(ref self: T, default_params: DefaultParameters);
}

/// Chest app constants
pub const APP_KEY: felt252 = 'chest';
pub const APP_ICON: felt252 = 0xf09f93a6; // 📦 emoji
pub const LIFE_REWARD: u32 = 1;
pub const COOLDOWN_SECONDS: u64 = 86400; // 24 hours

/// Chest actions contract
#[dojo::contract]
pub mod chest_actions {
    use core::num::traits::Zero;
    use dojo::model::ModelStorage;
    // use pixelaw::apps::player::{Player}; // TODO: Re-enable when Player model is properly set up
    use pixelaw::core::actions::{IActionsDispatcherTrait as ICoreActionsDispatcherTrait};
    use pixelaw::core::models::pixel::{Pixel, PixelUpdate, PixelUpdateResultTrait};
    use pixelaw::core::models::registry::App;
    use pixelaw::core::utils::{DefaultParameters, get_callers, get_core_actions};
    use starknet::{ContractAddress, get_block_timestamp, get_contract_address};
    use super::{APP_ICON, APP_KEY, COOLDOWN_SECONDS, Chest, IChestActions};

    /// Initialize the Chest App
    fn dojo_init(ref self: ContractState) {
        let mut world = self.world(@"pixelaw");
        let core_actions = get_core_actions(ref world);
        core_actions.new_app(0.try_into().unwrap(), APP_KEY, APP_ICON);
    }

    // impl: implement functions specified in trait
    #[abi(embed_v0)]
    impl Actions of IChestActions<ContractState> {
        /// Hook called before a pixel update.
        ///
        /// # Arguments
        ///
        /// * `pixel_update` - The proposed update to the pixel.
        /// * `app_caller` - The app initiating the update.
        /// * `player_caller` - The player initiating the update.
        fn on_pre_update(
            ref self: ContractState,
            pixel_update: PixelUpdate,
            app_caller: App,
            player_caller: ContractAddress,
        ) -> Option<PixelUpdate> {
            // Default is to not allow anything
            Option::None
        }

        /// Hook called after a pixel update.
        ///
        /// # Arguments
        ///
        /// * `pixel_update` - The update that was applied to the pixel.
        /// * `app_caller` - The app that performed the update.
        /// * `player_caller` - The player that performed the update.
        fn on_post_update(
            ref self: ContractState,
            pixel_update: PixelUpdate,
            app_caller: App,
            player_caller: ContractAddress,
        ) { // No action needed
        }

        /// Interacts with a pixel based on default parameters.
        ///
        /// Determines whether to place a chest or collect an existing one.
        ///
        /// # Arguments
        ///
        /// * `default_params` - Default parameters including position and color.
        fn interact(ref self: ContractState, default_params: DefaultParameters) {
            let mut core_world = self.world(@"pixelaw");
            let mut _app_world = self.world(@"chest");
            let position = default_params.position;

            // Check if there's already a chest at this position
            let pixel: Pixel = core_world.read_model(position);

            if pixel.app == get_contract_address() {
                // There's a chest here, try to collect it
                self.collect_chest(default_params);
            } else {
                // No chest here, try to place one
                self.place_chest(default_params);
            }
        }

        /// Place a new chest at the specified position
        ///
        /// # Arguments
        ///
        /// * `default_params` - Default parameters including position
        fn place_chest(ref self: ContractState, default_params: DefaultParameters) {
            let mut core_world = self.world(@"pixelaw");
            let mut app_world = self.world(@"chest");

            // Load important variables
            let core_actions = get_core_actions(ref core_world);
            let (player, system) = get_callers(ref core_world, default_params);

            let position = default_params.position;
            let current_timestamp = get_block_timestamp();

            // Check if position is empty
            let pixel: Pixel = core_world.read_model(position);
            assert!(pixel.app.is_zero(), "Position is not empty");

            // Create chest record
            let chest = Chest {
                position,
                placed_by: player,
                placed_at: current_timestamp,
                is_collected: false,
                last_collected_at: 0,
            };
            app_world.write_model(@chest);

            // Place chest pixel
            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        position,
                        color: Option::Some(0xFFC107FF), // Gold color
                        timestamp: Option::None,
                        text: Option::Some(0xf09f93a6), // 📦 emoji
                        app: Option::Some(get_contract_address()),
                        owner: Option::Some(player),
                        action: Option::None,
                    },
                    Option::None,
                    false,
                )
                .unwrap();

            // Emit notification
            core_actions
                .notification(
                    position,
                    default_params.color,
                    Option::Some(player),
                    Option::None,
                    'Chest placed!',
                );
        }

        /// Collect a chest and gain life
        ///
        /// # Arguments
        ///
        /// * `default_params` - Default parameters including position
        fn collect_chest(ref self: ContractState, default_params: DefaultParameters) {
            let mut core_world = self.world(@"pixelaw");
            let mut app_world = self.world(@"chest");

            // Load important variables
            let core_actions = get_core_actions(ref core_world);
            let (player, system) = get_callers(ref core_world, default_params);

            let position = default_params.position;
            let current_timestamp = get_block_timestamp();

            // Check if there's a chest at this position
            let pixel: Pixel = core_world.read_model(position);
            assert!(pixel.app == get_contract_address(), "No chest at this position");

            // Get the chest data
            let mut chest: Chest = app_world.read_model(position);
            assert!(!chest.is_collected, "Chest already collected");

            // Check cooldown (24 hours from placement or last collection)
            let cooldown_reference = if chest.last_collected_at == 0 {
                chest.placed_at
            } else {
                chest.last_collected_at
            };
            assert!(
                current_timestamp >= cooldown_reference + COOLDOWN_SECONDS, "Chest not ready yet",
            );

            // Update chest collection status
            chest.is_collected = true;
            chest.last_collected_at = current_timestamp;
            app_world.write_model(@chest);

            // TODO: Add life to player when Player model is properly available
            // let mut player_data: Player = core_world.read_model(player);
            // player_data.lives += LIFE_REWARD;
            // core_world.write_model(@player_data);

            // Update pixel to show collected chest
            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        position,
                        color: Option::Some(0x808080FF), // Gray color for collected chest
                        timestamp: Option::None,
                        text: Option::Some(0xf09f93ad), // 📭 empty mailbox emoji
                        app: Option::Some(get_contract_address()),
                        owner: Option::Some(chest.placed_by),
                        action: Option::None,
                    },
                    Option::None,
                    false,
                )
                .unwrap();

            // Send notification
            core_actions
                .notification(
                    position,
                    default_params.color,
                    Option::Some(player),
                    Option::None,
                    'Chest collected! +1 life',
                );
        }
    }
}
