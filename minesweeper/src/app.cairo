use pixelaw::core::models::{pixel::{PixelUpdate}, registry::{App}};
use pixelaw::core::utils::{DefaultParameters, Position};
use starknet::{ContractAddress};

/// Minesweeper game state
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct MinesweeperGame {
    #[key]
    pub position: Position,
    pub creator: ContractAddress,
    pub state: u8, // 0=None, 1=Open, 2=Finished, 3=Exploded
    pub size: u32,
    pub mines_amount: u32,
    pub started_timestamp: u64,
    pub flags: u32,
    pub revealed: u32,
}

/// Individual cell state
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct MineCell {
    #[key]
    pub position: Position,
    pub game_position: Position, // Reference to game origin
    pub is_mine: bool,
    pub is_revealed: bool,
    pub is_flagged: bool,
    pub adjacent_mines: u8,
}

#[starknet::interface]
pub trait IMinesweeperActions<T> {
    fn on_pre_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    ) -> Option<PixelUpdate>;

    fn on_post_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    );

    fn interact(ref self: T, default_params: DefaultParameters, size: u32, mines_amount: u32);
    fn reveal(ref self: T, default_params: DefaultParameters);
    fn flag(ref self: T, default_params: DefaultParameters);
}

/// Minesweeper app constants
pub const APP_KEY: felt252 = 'minesweeper';
pub const APP_ICON: felt252 = 0xf09f92a5; // 💥 emoji
pub const MAX_SIZE: u32 = 10;

/// Minesweeper game contract
#[dojo::contract]
pub mod minesweeper_actions {
    use dojo::model::{ModelStorage};
    use pixelaw::core::actions::{IActionsDispatcherTrait as ICoreActionsDispatcherTrait};
    use pixelaw::core::models::pixel::{Pixel, PixelUpdate, PixelUpdateResultTrait};
    use pixelaw::core::models::registry::App;
    use pixelaw::core::utils::{DefaultParameters, Position, get_callers, get_core_actions};
    use starknet::{
        ContractAddress, contract_address_const, get_block_timestamp, get_contract_address,
    };
    use super::{APP_ICON, APP_KEY, IMinesweeperActions, MAX_SIZE, MineCell, MinesweeperGame};

    /// Initialize the Minesweeper App
    fn dojo_init(ref self: ContractState) {
        let mut world = self.world(@"pixelaw");
        let core_actions = get_core_actions(ref world);
        core_actions.new_app(contract_address_const::<0>(), APP_KEY, APP_ICON);
    }

    #[abi(embed_v0)]
    impl ActionsImpl of IMinesweeperActions<ContractState> {
        fn on_pre_update(
            ref self: ContractState,
            pixel_update: PixelUpdate,
            app_caller: App,
            player_caller: ContractAddress,
        ) -> Option<PixelUpdate> {
            // Default: allow no changes
            Option::None
        }

        fn on_post_update(
            ref self: ContractState,
            pixel_update: PixelUpdate,
            app_caller: App,
            player_caller: ContractAddress,
        ) { // React to changes if needed
        }

        fn interact(
            ref self: ContractState,
            default_params: DefaultParameters,
            size: u32,
            mines_amount: u32,
        ) {
            let mut core_world = self.world(@"pixelaw");
            let mut _app_world = self.world(@"minesweeper");

            let _core_actions = get_core_actions(ref core_world);
            let (_player, _system) = get_callers(ref core_world, default_params);
            let position = default_params.position;

            // Validate input
            assert(size > 0 && size <= MAX_SIZE, 'Invalid size');
            assert(mines_amount > 0 && mines_amount < (size * size), 'Invalid mines amount');

            // Check if there's already a game at this position
            let pixel: Pixel = core_world.read_model(position);

            if pixel.app == get_contract_address() { // Game exists, just show current state
            } else {
                // Initialize new game
                self.init_game(default_params, size, mines_amount);
            }
        }

        fn reveal(ref self: ContractState, default_params: DefaultParameters) {
            let mut core_world = self.world(@"pixelaw");
            let mut app_world = self.world(@"minesweeper");

            let core_actions = get_core_actions(ref core_world);
            let (player, system) = get_callers(ref core_world, default_params);
            let position = default_params.position;

            // Find the cell to reveal
            let mut cell: MineCell = app_world.read_model(position);

            if cell.is_revealed || cell.is_flagged { // Already revealed or flagged, can't reveal
            } else {
                // Reveal the cell
                cell.is_revealed = true;
                app_world.write_model(@cell);

                if cell.is_mine {
                    // Game over - mine hit
                    self.explode_game(position, cell.game_position);
                } else {
                    // Update pixel display
                    let color = if cell.adjacent_mines == 0 {
                        0xFFFFFFFF
                    } else {
                        0xFFAAFFAA
                    };
                    let text = if cell.adjacent_mines == 0 {
                        ''
                    } else {
                        cell.adjacent_mines.into()
                    };

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
                                action: Option::Some('revealed'),
                            },
                            Option::None,
                            false,
                        )
                        .unwrap();

                    // Check win condition
                    self.check_win_condition(cell.game_position);
                }
            }
        }

        fn flag(ref self: ContractState, default_params: DefaultParameters) {
            let mut core_world = self.world(@"pixelaw");
            let mut app_world = self.world(@"minesweeper");

            let core_actions = get_core_actions(ref core_world);
            let (player, system) = get_callers(ref core_world, default_params);
            let position = default_params.position;

            // Toggle flag on cell
            let mut cell: MineCell = app_world.read_model(position);

            if !cell.is_revealed {
                cell.is_flagged = !cell.is_flagged;
                app_world.write_model(@cell);

                // Update pixel display
                let color = if cell.is_flagged {
                    0xFFFF0000
                } else {
                    0xFF888888
                };
                let text = if cell.is_flagged {
                    0x1F6A9
                } else {
                    '?'
                }; // 🚩 flag or ?

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
                            action: Option::Some('flag'),
                        },
                        Option::None,
                        false,
                    )
                    .unwrap();
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn init_game(
            ref self: ContractState,
            default_params: DefaultParameters,
            size: u32,
            mines_amount: u32,
        ) {
            let mut core_world = self.world(@"pixelaw");
            let mut app_world = self.world(@"minesweeper");

            let core_actions = get_core_actions(ref core_world);
            let (player, system) = get_callers(ref core_world, default_params);
            let position = default_params.position;
            let current_timestamp = get_block_timestamp();

            // Create game state
            let game_state = MinesweeperGame {
                position,
                creator: player,
                state: 1, // Open
                size,
                mines_amount,
                started_timestamp: current_timestamp,
                flags: 0,
                revealed: 0,
            };
            app_world.write_model(@game_state);

            // Initialize game board
            let mut x = 0;
            while x < size {
                let mut y = 0;
                while y < size {
                    let cell_position = Position {
                        x: position.x + x.try_into().unwrap(),
                        y: position.y + y.try_into().unwrap(),
                    };

                    let cell = MineCell {
                        position: cell_position,
                        game_position: position,
                        is_mine: false, // Will be set randomly later
                        is_revealed: false,
                        is_flagged: false,
                        adjacent_mines: 0,
                    };
                    app_world.write_model(@cell);

                    // Update pixel for game cell
                    core_actions
                        .update_pixel(
                            player,
                            system,
                            PixelUpdate {
                                position: cell_position,
                                color: Option::Some(0xFF888888), // Gray
                                timestamp: Option::None,
                                text: Option::Some('?'),
                                app: Option::Some(system),
                                owner: Option::Some(player),
                                action: Option::Some('cell'),
                            },
                            Option::None,
                            false,
                        )
                        .unwrap();

                    y += 1;
                };
                x += 1;
            };

            // Place mines randomly (simplified random placement)
            self.place_mines_randomly(position, size, mines_amount);

            // Calculate adjacent mine counts
            self.calculate_adjacent_mines(position, size);

            // Send notification
            core_actions
                .notification(
                    position,
                    default_params.color,
                    Option::Some(player),
                    Option::None,
                    'Minesweeper started!',
                );
        }

        fn place_mines_randomly(
            ref self: ContractState, game_position: Position, size: u32, mines_amount: u32,
        ) {
            let mut app_world = self.world(@"minesweeper");
            let timestamp = get_block_timestamp();
            let mut placed_mines = 0;

            // Simple random mine placement using timestamp
            while placed_mines < mines_amount {
                let rand_x = (timestamp + placed_mines.into()) % size.into();
                let rand_y = (timestamp + placed_mines.into() + 17) % size.into();

                let mine_position = Position {
                    x: game_position.x + rand_x.try_into().unwrap(),
                    y: game_position.y + rand_y.try_into().unwrap(),
                };

                let mut cell: MineCell = app_world.read_model(mine_position);
                if !cell.is_mine {
                    cell.is_mine = true;
                    app_world.write_model(@cell);
                    placed_mines += 1;
                }
            };
        }

        fn calculate_adjacent_mines(ref self: ContractState, game_position: Position, size: u32) {
            let mut app_world = self.world(@"minesweeper");

            let mut x = 0;
            while x < size {
                let mut y = 0;
                while y < size {
                    let cell_position = Position {
                        x: game_position.x + x.try_into().unwrap(),
                        y: game_position.y + y.try_into().unwrap(),
                    };

                    let mut cell: MineCell = app_world.read_model(cell_position);

                    if !cell.is_mine {
                        // Count adjacent mines
                        let mut adjacent_count = 0;

                        // Check all 8 adjacent positions (simplified)
                        if x > 0 && y > 0 {
                            let adj_pos = Position {
                                x: cell_position.x - 1, y: cell_position.y - 1,
                            };
                            let adj_cell: MineCell = app_world.read_model(adj_pos);
                            if adj_cell.is_mine {
                                adjacent_count += 1;
                            }
                        }
                        // ... (would implement all 8 directions in full version)

                        cell.adjacent_mines = adjacent_count;
                        app_world.write_model(@cell);
                    }

                    y += 1;
                };
                x += 1;
            };
        }

        fn explode_game(ref self: ContractState, mine_position: Position, game_position: Position) {
            let mut core_world = self.world(@"pixelaw");
            let mut app_world = self.world(@"minesweeper");

            let core_actions = get_core_actions(ref core_world);

            // Update game state to exploded
            let mut game: MinesweeperGame = app_world.read_model(game_position);
            game.state = 3; // Exploded
            app_world.write_model(@game);

            // Update the mine pixel that was hit
            let pixel: Pixel = core_world.read_model(mine_position);
            core_actions
                .update_pixel(
                    pixel.owner,
                    get_contract_address(),
                    PixelUpdate {
                        position: mine_position,
                        color: Option::Some(0xFFFF0000), // Red
                        timestamp: Option::None,
                        text: Option::Some(APP_ICON), // 💥
                        app: Option::Some(get_contract_address()),
                        owner: Option::Some(pixel.owner),
                        action: Option::Some('exploded'),
                    },
                    Option::None,
                    false,
                )
                .unwrap();

            // Send notification
            core_actions
                .notification(
                    mine_position,
                    0xFFFF0000,
                    Option::Some(pixel.owner),
                    Option::None,
                    'BOOM! Game Over',
                );
        }

        fn check_win_condition(ref self: ContractState, game_position: Position) {
            let mut app_world = self.world(@"minesweeper");

            let game: MinesweeperGame = app_world.read_model(game_position);
            let total_cells = game.size * game.size;
            let safe_cells = total_cells - game.mines_amount;

            // Count revealed safe cells
            let mut revealed_safe = 0;
            let mut x = 0;
            while x < game.size {
                let mut y = 0;
                while y < game.size {
                    let cell_position = Position {
                        x: game_position.x + x.try_into().unwrap(),
                        y: game_position.y + y.try_into().unwrap(),
                    };

                    let cell: MineCell = app_world.read_model(cell_position);
                    if !cell.is_mine && cell.is_revealed {
                        revealed_safe += 1;
                    }

                    y += 1;
                };
                x += 1;
            };

            if revealed_safe == safe_cells {
                // Win condition met
                let mut game_state = game;
                game_state.state = 2; // Finished
                app_world.write_model(@game_state);

                let _core_world = self.world(@"pixelaw");
                let mut core_world_mutable = self.world(@"pixelaw");
                let core_actions = get_core_actions(ref core_world_mutable);

                core_actions
                    .notification(
                        game_position,
                        0xFF00FF00,
                        Option::Some(game.creator),
                        Option::None,
                        'You won!',
                    );
            }
        }
    }
}
