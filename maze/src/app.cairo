use pixelaw::core::models::pixel::PixelUpdate;
use pixelaw::core::models::registry::App;
use pixelaw::core::utils::{DefaultParameters, Position};
use starknet::ContractAddress;


#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct MazeGame {
    #[key]
    position: Position,
    pub id: u32,
    pub creator: ContractAddress,
    pub size: u32,
    pub started_timestamp: u64,
    pub is_revealed: bool,
    pub cell_type: felt252,
}

#[starknet::interface]
pub trait IMazeActions<T> {
    fn on_pre_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    ) -> Option<PixelUpdate>;

    fn on_post_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    );

    fn interact(ref self: T, default_params: DefaultParameters);
    fn reveal_cell(ref self: T, default_params: DefaultParameters);
}

/// contracts must be named as such (APP_KEY + underscore + "actions")
#[dojo::contract]
pub mod maze_actions {
    use core::poseidon::poseidon_hash_span;
    use dojo::model::ModelStorage;
    use maze::constants::{
        APP_ICON, APP_KEY, CENTER, MAZE_1, MAZE_2, MAZE_3, MAZE_4, MAZE_5, MAZE_SIZE, PATH, TRAP,
        WALL,
    };
    use pixelaw::apps::player::Player;
    use pixelaw::core::actions::IActionsDispatcherTrait as ICoreActionsDispatcherTrait;
    use pixelaw::core::models::pixel::{PixelUpdate, PixelUpdateResultTrait};
    use pixelaw::core::models::registry::App;
    use pixelaw::core::utils::{
        DefaultParameters, Position, get_callers, get_core_actions, is_area_free, panic_at_position,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_contract_address};
    use super::{IMazeActions, MazeGame};

    /// Initialize the Maze App
    fn dojo_init(ref self: ContractState) {
        let mut world = self.world(@"pixelaw");
        let core_actions = pixelaw::core::utils::get_core_actions(ref world);
        core_actions.new_app(0.try_into().unwrap(), APP_KEY, APP_ICON);
    }

    // impl: implement functions specified in trait
    #[abi(embed_v0)]
    impl ActionsImpl of IMazeActions<ContractState> {
        /// Hook called before a pixel update - reveals maze cell when player is about to move onto
        /// it
        fn on_pre_update(
            ref self: ContractState,
            pixel_update: PixelUpdate,
            app_caller: App,
            player_caller: ContractAddress,
        ) -> Option<PixelUpdate> {
            if app_caller.name == 'player' {
                let mut app_world = self.world(@"maze");
                let mut core_world = self.world(@"core");
                let position = pixel_update.position;
                let game: MazeGame = app_world.read_model(position);
                let core_actions = get_core_actions(ref core_world);

                core_actions
                    .notification(
                        position,
                        pixel_update.color.unwrap(),
                        Option::None,
                        Option::None,
                        'Life collected!',
                    );

                // Only process if this is a valid maze cell
                if game.id != 0 {
                    // Always reveal the cell when player approaches
                    if !game.is_revealed {
                        self
                            .reveal_cell(
                                DefaultParameters {
                                    player_override: Option::Some(player_caller),
                                    system_override: Option::Some(get_contract_address()),
                                    area_hint: Option::None,
                                    position: position,
                                    color: 0x000000 // Color doesn't matter for reveal
                                },
                            );
                    }

                    // Check if player can actually move onto this cell
                    if game.cell_type == WALL {
                        // Reveal the wall but don't allow player to move onto it
                        return Option::None;
                    }
                }

                // Allow player to move onto non-wall cells
                Option::Some(pixel_update)
            } else {
                // Don't allow other apps to modify maze pixels
                Option::None
            }
        }

        /// Hook called after a pixel update - no longer needed since we reveal in pre_update
        fn on_post_update(
            ref self: ContractState,
            pixel_update: PixelUpdate,
            app_caller: App,
            player_caller: ContractAddress,
        ) { // Revelation is now handled in on_pre_update
        // This hook is kept for potential future use
        }

        /// Create a new maze at the specified position
        fn interact(ref self: ContractState, default_params: DefaultParameters) {
            let mut core_world = self.world(@"pixelaw");
            let mut app_world = self.world(@"maze");

            // Load important variables
            let (player, _system) = get_callers(ref core_world, default_params);

            let position = default_params.position;

            // Load the MazeGame
            let game: MazeGame = app_world.read_model(position);

            // Only create maze if this is a new location
            if game.id == 0 {
                // Check if the maze area is free before creating
                let maze_size_u16: u16 = MAZE_SIZE.try_into().unwrap();
                if !is_area_free(ref core_world, position, maze_size_u16, maze_size_u16) {
                    panic_at_position(position, "Area not free for maze");
                }

                let core_actions = get_core_actions(ref core_world);
                let timestamp = get_block_timestamp();

                // Generate maze ID based on position and timestamp
                let id = self.generate_maze_id(position, timestamp);

                // Select a random maze layout
                let maze_layout_id = self.select_maze_layout(position, timestamp);

                // Create maze cells
                let mut i: u32 = 0;
                let mut j: u32 = 0;
                loop {
                    if i >= MAZE_SIZE {
                        break;
                    }
                    j = 0;
                    loop {
                        if j >= MAZE_SIZE {
                            break;
                        }

                        let cell_position = Position {
                            x: position.x + j.try_into().unwrap(),
                            y: position.y + i.try_into().unwrap(),
                        };
                        let cell_type = self.get_maze_cell_type(maze_layout_id, i, j);

                        let game = MazeGame {
                            position: cell_position,
                            id: id,
                            creator: player,
                            size: MAZE_SIZE,
                            started_timestamp: timestamp,
                            is_revealed: false,
                            cell_type: cell_type,
                        };

                        app_world.write_model(@game);

                        // Initialize pixel with maze app control but no owner (shared space)
                        core_actions
                            .update_pixel(
                                player,
                                get_contract_address(), // Use maze contract as system caller
                                PixelUpdate {
                                    position: cell_position,
                                    color: Option::Some(0x808080), // Gray for hidden
                                    timestamp: Option::None,
                                    text: Option::Some(0xe29d93), // ❓ Question mark
                                    app: Option::Some(
                                        get_contract_address(),
                                    ), // Maze app controls behavior
                                    owner: Option::None, // Unowned - any player can traverse
                                    action: Option::None,
                                },
                                Option::None,
                                false,
                            )
                            .unwrap();

                        j += 1;
                    }
                    i += 1;
                };
            } else {
                self.reveal_cell(default_params);
            }
        }

        /// Reveal a cell in the maze
        fn reveal_cell(ref self: ContractState, default_params: DefaultParameters) {
            let mut core_world = self.world(@"pixelaw");
            let mut app_world = self.world(@"maze");

            let core_actions = get_core_actions(ref core_world);
            let (player, system) = get_callers(ref core_world, default_params);
            let position = default_params.position;

            let mut game: MazeGame = app_world.read_model(position);

            // Only reveal if not already revealed
            if !game.is_revealed && game.id != 0 {
                game.is_revealed = true;
                app_world.write_model(@game);

                let (emoji, color) = self.get_cell_display(game.cell_type);

                if game.cell_type == TRAP {
                    let mut player_model: Player = core_world.read_model(player);
                    if player_model.lives > 0 {
                        player_model.lives -= 1;
                        core_world.write_model(@player_model);
                    }
                }

                core_actions
                    .update_pixel(
                        player,
                        system,
                        PixelUpdate {
                            position,
                            color: Option::Some(color),
                            timestamp: Option::None,
                            text: Option::Some(emoji),
                            app: Option::None, // Don't change app ownership
                            owner: Option::None, // Don't change owner
                            action: Option::None,
                        },
                        default_params.area_hint,
                        false,
                    )
                    .unwrap();
            }
        }
    }

    #[generate_trait]
    impl HelperImpl of HelperTrait {
        /// Generate a unique maze ID
        fn generate_maze_id(ref self: ContractState, position: Position, timestamp: u64) -> u32 {
            let hash = poseidon_hash_span(
                array![position.x.into(), position.y.into(), timestamp.into()].span(),
            );
            let id: u32 = (hash.into() % 1000000_u256).try_into().unwrap();
            id
        }

        /// Select which maze layout to use (1-5)
        fn select_maze_layout(ref self: ContractState, position: Position, timestamp: u64) -> u32 {
            let hash = poseidon_hash_span(
                array![position.x.into(), position.y.into(), timestamp.into(), 42].span(),
            );
            let layout: u32 = (hash.into() % 5_u256).try_into().unwrap() + 1;
            layout
        }

        /// Get the cell type for a specific position in the selected maze
        fn get_maze_cell_type(
            ref self: ContractState, maze_id: u32, row: u32, col: u32,
        ) -> felt252 {
            let index: u32 = row * MAZE_SIZE + col;
            let cell_value: u8 = self.get_maze_cell_value(maze_id, index);

            if cell_value == 0 {
                PATH
            } else if cell_value == 1 {
                WALL
            } else if cell_value == 2 {
                CENTER
            } else {
                TRAP
            }
        }

        /// Get maze layout by ID and return the array directly
        fn get_maze_layout(maze_id: u32) -> [u8; 25] {
            if maze_id == 1 {
                MAZE_1
            } else if maze_id == 2 {
                MAZE_2
            } else if maze_id == 3 {
                MAZE_3
            } else if maze_id == 4 {
                MAZE_4
            } else {
                MAZE_5
            }
        }

        /// Optimized helper function to get cell value directly from maze arrays
        fn get_maze_cell_value(ref self: ContractState, maze_id: u32, index: u32) -> u8 {
            let maze_layout = Self::get_maze_layout(maze_id);
            *maze_layout.span().at(index)
        }

        /// Get emoji and color for cell display
        fn get_cell_display(ref self: ContractState, cell_type: felt252) -> (felt252, u32) {
            if cell_type == WALL {
                (0xf09f9fb1, 0x8B4513) // 🧱 Brick emoji, brown color
            } else if cell_type == PATH {
                (0xf09f9fa2, 0x00FF00) // 🟢 Green circle, green color
            } else if cell_type == TRAP {
                (0xf09f92a5, 0xFF0000) // 💥 Explosion emoji, red color
            } else {
                (0xf09f8f86, 0xFFD700) // 🏆 Trophy emoji, gold color
            }
        }
    }
}
