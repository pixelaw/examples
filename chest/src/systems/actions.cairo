use pixelaw::core::utils::{DefaultParameters, Position};
use starknet::{ContractAddress};

#[starknet::interface]
pub trait IChestsActions<T> {
    fn place_chest(ref self: T, default_params: DefaultParameters, chest_type: u8);
    fn collect_chest(ref self: T, default_params: DefaultParameters);
}

/// Chests actions contract
#[dojo::contract]
pub mod chests_actions {
    use dojo::model::{ModelStorage};
    /// Initialize the Chests App
    fn dojo_init(ref self: ContractState) {
        let mut world = self.world(@"pixelaw");
        let core_actions = pixelaw::core::utils::get_core_actions(ref world);
        core_actions.new_app(contract_address_const::<0>(), CHESTS_APP_KEY, CHESTS_APP_ICON);
    }

    // impl: implement functions specified in trait
    #[abi(embed_v0)]
    impl ActionsImpl of IChestsActions<ContractState> {
        /// Place a new chest at the specified position
        ///
        /// # Arguments
        ///
        /// * `default_params` - Default parameters including position
        /// * `chest_type` - Type of chest (1=single player, 2=multi-player)
        fn place_chest(ref self: ContractState, default_params: DefaultParameters, chest_type: u8) {
            let mut core_world = self.world(@"pixelaw");
            let mut app_world = self.world(@"chests");

            // Load important variables
            let core_actions = get_core_actions(ref core_world);
            let (player, system) = get_callers(ref core_world, default_params);
            
            let position = default_params.position;
            let current_timestamp = get_block_timestamp();

            // Check if the position is empty
            let pixel: Pixel = core_world.read_model(position);
            assert!(pixel.app == contract_address_const::<0>(), "Position is not empty");

            // Create the chest
            let chest = Chest {
                position,
                chest_type,
                placed_by: player,
                is_collected: false,
                lives_award: 3,
            };
            app_world.write_model(@chest);

            // Update the pixel to show the chest
            let (color, text) = (0xFFC107FF, "U+1F4E6"); // Gold color with package emoji for single player

            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        position,
                        color: Option::Some(color),
                        timestamp: Option::None,
                        text: Option::Some(text),
                        app: Option::Some(system),
                        owner: Option::Some(player),
                        action: Option::None
                    },
                    default_params.area_hint,
                    false
                )
                .unwrap();                // Notify the player
            let chest_type_str = if chest_type == SINGLE_PLAYER_CHEST {
                "single-player"
            } else {
                "multi-player"
            };

            // Emit chest placed event
            app_world.emit_event(ChestPlaced {
                player,
                position,
                chest_type,
                lives_reward,
                moves_reward,
            });
        }

        /// Attempt to collect a chest
        ///
        /// # Arguments
        ///
        /// * `default_params` - Default parameters including position
        fn collect_chest(ref self: ContractState, default_params: DefaultParameters) {
            let mut core_world = self.world(@"pixelaw");
            let mut app_world = self.world(@"chests");

            // Load important variables
            let core_actions = get_core_actions(ref core_world);
            let (player, system) = get_callers(ref core_world, default_params);
            
            let position = default_params.position;

            // Check if there's a chest at this position
            let pixel: Pixel = core_world.read_model(position);
            assert!(pixel.app == system, "No chest at this position");

            // Get the chest
            let mut chest: Chest = app_world.read_model(position);
            assert!(!chest.is_collected, "Chest already collected");

            let mut can_collect = false;
            
            if chest.chest_type == SINGLE_PLAYER_CHEST {
                // Single player chest can be collected immediately
                can_collect = true;
            } else if chest.chest_type == MULTI_PLAYER_CHEST {
                // Multi-player chest needs multiple players around it
                let chest_players: ChestPlayers = app_world.read_model(position);
                
                // Check if there are enough players
                if chest_players.players.len() >= MULTI_PLAYER_MIN_PLAYERS.into() {
                    can_collect = true;
                    
                    // Reward all players around the chest
                    let mut i: u32 = 0;
                    while i < chest_players.players.len() {
                        let current_player = *chest_players.players.at(i);
                        
                        // Reward this player
                        let mut player_data: Player = core_world.read_model(current_player);
                        player_data.lives += chest.lives_reward;
                        player_data.moves += chest.moves_reward;
                        core_world.write_model(@player_data);
                        
                        // Emit event for multi-player chest collection for this player
                        app_world.emit_event(ChestCollected {
                            position,
                            collector: current_player,
                            is_multi_player: true,
                            lives_reward: chest.lives_reward,
                            moves_reward: chest.moves_reward,
                        });
                        
                        i += 1;
                    }
                } else {
                    // Not enough players
                    core_actions.notify(
                        player,
                        system,
                        format!("Not enough players around the chest. Need at least {} players.", MULTI_PLAYER_MIN_PLAYERS),
                        0,
                        0
                    );
                }
            }

            if can_collect {
                // Mark chest as collected
                chest.is_collected = true;
                app_world.write_model(@chest);
                
                // If it's a single player chest, reward only the collector
                if chest.chest_type == SINGLE_PLAYER_CHEST {
                    // Update player stats
                    let mut player_data: Player = core_world.read_model(player);
                    player_data.lives += chest.lives_reward;
                    player_data.moves += chest.moves_reward;
                    core_world.write_model(@player_data);
                    
                    // Notify the player
                    core_actions.notify(
                        player,
                        system,
                        format!("You collected a chest! Received {} lives and {} moves.", chest.lives_reward, chest.moves_reward),
                        0,
                        0
                    );
                }
                
                // Update the pixel to show an empty chest
                core_actions
                    .update_pixel(
                        player,
                        system,
                        PixelUpdate {
                            position,
                            color: Option::Some(0x808080FF), // Gray color for empty chest
                            timestamp: Option::None,
                            text: Option::Some("U+1F4ED"), // Empty mailbox emoji
                            app: Option::Some(system),
                            owner: Option::Some(chest.placed_by),
                            action: Option::None
                        },
                        default_params.area_hint,
                        false
                    )
                    .unwrap();

                // Emit chest collected event
                app_world.emit_event(ChestCollected {
                    position,
                    collector: player,
                    is_multi_player: chest.chest_type == MULTI_PLAYER_CHEST,
                    lives_reward: chest.lives_reward,
                    moves_reward: chest.moves_reward,
                });
            }
        }
    }
}
