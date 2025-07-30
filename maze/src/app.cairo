use pixelaw::core::utils::{DefaultParameters, Position};
use starknet::{ContractAddress};

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
    pub cell_type: felt252, // 'wall', 'path', 'center'
}

#[starknet::interface]
pub trait IMazeActions<T> {
    fn interact(ref self: T, default_params: DefaultParameters);
    fn reveal_cell(ref self: T, default_params: DefaultParameters);
}

/// contracts must be named as such (APP_KEY + underscore + "actions")
#[dojo::contract]
pub mod maze_actions {
    use dojo::model::{ModelStorage};
    use maze::constants::{
        APP_ICON, APP_KEY, MAZE_SIZE, WALL, PATH, CENTER, TRAP
    };
    use pixelaw::core::actions::{IActionsDispatcherTrait as ICoreActionsDispatcherTrait};
    use pixelaw::core::models::pixel::{PixelUpdate, PixelUpdateResultTrait};
    use pixelaw::core::utils::{DefaultParameters, Position, get_callers, get_core_actions};
    use starknet::{contract_address_const, get_block_timestamp};
    use super::{MazeGame, IMazeActions};
    use core::poseidon::poseidon_hash_span;
    use pixelaw::apps::player::{Player};
    use maze::constants::{MAZE_1, MAZE_2, MAZE_3, MAZE_4, MAZE_5};

    /// Initialize the Maze App
    fn dojo_init(ref self: ContractState) {
        let mut world = self.world(@"pixelaw");
        let core_actions = pixelaw::core::utils::get_core_actions(ref world);
        core_actions.new_app(contract_address_const::<0>(), APP_KEY, APP_ICON);
    }

    // impl: implement functions specified in trait
    #[abi(embed_v0)]
    impl ActionsImpl of IMazeActions<ContractState> {
        /// Create a new maze or reveal a cell in an existing maze
        fn interact(ref self: ContractState, default_params: DefaultParameters) {
            let mut core_world = self.world(@"pixelaw");
            let mut app_world = self.world(@"maze");

            // Load important variables
            let (player, system) = get_callers(ref core_world, default_params);

            let position = default_params.position;

            // Load the MazeGame
            let game: MazeGame = app_world.read_model(position);

            // If this is a new maze, create it
            if game.id == 0 {
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
                        
                        let cell_position = Position { x: position.x + j.try_into().unwrap(), y: position.y + i.try_into().unwrap() };
                        let cell_type = self.get_maze_cell_type(maze_layout_id, i, j);
                        
                        let game = MazeGame {
                            position: cell_position,
                            id: id,
                            creator: player,
                            size: MAZE_SIZE,
                            started_timestamp: timestamp,
                            is_revealed: false,
                            cell_type: cell_type
                        };
                        
                        app_world.write_model(@game);
                        
                        // Initialize pixel with hidden state
                        core_actions
                            .update_pixel(
                                player,
                                system,
                                PixelUpdate {
                                    position: cell_position,
                                    color: Option::Some(0x808080), // Gray for hidden
                                    timestamp: Option::None,
                                    text: Option::Some('U+2753'), // Question mark
                                    app: Option::Some(system),
                                    owner: Option::Some(player),
                                    action: Option::None
                                },
                                default_params.area_hint,
                                false
                            )
                            .unwrap();
                        
                        j += 1;
                    };
                    i += 1;
                };
            } else {
                // Reveal the cell
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

                // If it's a trap, reduce player's lives
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
                            app: Option::Some(system),
                            owner: Option::Some(player),
                            action: Option::None
                        },
                        default_params.area_hint,
                        false
                    )
                    .unwrap();
            }
        }
    }

    #[generate_trait]
    impl HelperImpl of HelperTrait {

        /// Generate a unique maze ID
        fn generate_maze_id(
            ref self: ContractState, 
            position: Position, 
            timestamp: u64
        ) -> u32 {
            let hash = poseidon_hash_span(
                array![position.x.into(), position.y.into(), timestamp.into()].span()
            );
            let id: u32 = (hash.into() % 1000000_u256).try_into().unwrap();
            id
        }

        /// Select which maze layout to use (1-5)
        fn select_maze_layout(
            ref self: ContractState, 
            position: Position, 
            timestamp: u64
        ) -> u32 {
            let hash = poseidon_hash_span(
                array![position.x.into(), position.y.into(), timestamp.into(), 42].span()
            );
            let layout: u32 = (hash.into() % 5_u256).try_into().unwrap() + 1;
            layout
        }

        /// Get the cell type for a specific position in the selected maze
        fn get_maze_cell_type(
            ref self: ContractState,
            maze_id: u32,
            row: u32,
            col: u32
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
                ('U+1F9F1', 0x8B4513) // Brick emoji, brown color
            } else if cell_type == PATH {
                ('U+1F7E2', 0x00FF00) // Green circle, green color
            } else if cell_type == TRAP {
                ('U+1F4A5', 0xFF0000) // Explosion emoji, red color
            } else {
                ('U+1F3C6', 0xFFD700) // Trophy emoji, gold color
            }
        }

    }
}
