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
}

#[derive(Debug, PartialEq, Serde, Copy, Drop, Introspect)]
pub enum Difficulty {
    None,
    Easy,
    Medium,
    Hard,
}

#[starknet::interface]
pub trait IMinesweeperActions<T> {
    fn on_pre_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    ) -> Option<PixelUpdate>;

    fn on_post_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    );

    fn interact(ref self: T, default_params: DefaultParameters, difficulty: Difficulty);
    fn reveal(ref self: T, default_params: DefaultParameters);
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
    use super::{
        APP_ICON, APP_KEY, Difficulty, IMinesweeperActions, MAX_SIZE, MineCell, MinesweeperGame,
    };

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
            ref self: ContractState, default_params: DefaultParameters, difficulty: Difficulty,
        ) {
            let mut core_world = self.world(@"pixelaw");
            let mut _app_world = self.world(@"minesweeper");

            let _core_actions = get_core_actions(ref core_world);
            let (_player, _system) = get_callers(ref core_world, default_params);
            let position = default_params.position;
            let pixel: Pixel = core_world.read_model(position);

            // Check if there's already a game at this position
            if pixel.app == get_contract_address() { // Game exists, just show current state
                self.reveal(default_params);
            } else {
                // Initialize new game
                self.init_game(default_params, difficulty);
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

            // Check if cell exists and is part of a game
            let game: MinesweeperGame = app_world.read_model(cell.game_position);
            assert!(game.state == 1_u8, "Game not active");

            if cell.is_revealed { // Already revealed, can't reveal
                return;
            } else {
                // Reveal the cell
                cell.is_revealed = true;
                app_world.write_model(@cell);

                if cell.is_mine {
                    // Game over - mine hit
                    self.explode_game(position, cell.game_position);
                } else {
                    // Update pixel display for safe cell
                    core_actions
                        .update_pixel(
                            player,
                            system,
                            PixelUpdate {
                                position,
                                color: Option::Some(0xFFAAFFAA), // Light green
                                timestamp: Option::None,
                                text: Option::Some('v'), // Check mark (v for safe)
                                app: Option::Some(system),
                                owner: Option::Some(player),
                                action: Option::None,
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
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn init_game(
            ref self: ContractState, default_params: DefaultParameters, difficulty: Difficulty,
        ) {
            // Early return for None difficulty - no game initialization needed
            if difficulty == Difficulty::None {
                return;
            }

            let mut core_world = self.world(@"pixelaw");
            let mut app_world = self.world(@"minesweeper");

            let core_actions = get_core_actions(ref core_world);
            let (player, system) = get_callers(ref core_world, default_params);
            let position = default_params.position;
            let current_timestamp = get_block_timestamp();

            // Check if there's already a game at this position
            let pixel: Pixel = core_world.read_model(position);
            assert!(
                pixel.app == contract_address_const::<0>() || pixel.app == get_contract_address(),
                "Position occupied",
            );

            // Determine field size and mine count based on difficulty
            let (size, mines_amount) = match difficulty {
                Difficulty::None => panic!(
                    "None difficulty should have been handled by early return",
                ),
                Difficulty::Easy => (4_u32, 3_u32), // 4x4 grid with 3 mines
                Difficulty::Medium => (5_u32, 6_u32), // 5x5 grid with 6 mines
                Difficulty::Hard => (7_u32, 12_u32) // 7x7 grid with 12 mines
            };

            // Validate input
            assert(size > 0 && size <= MAX_SIZE, 'Invalid size');
            assert(mines_amount > 0 && mines_amount < (size * size), 'Invalid mines amount');

            // Create game state
            let game_state = MinesweeperGame {
                position,
                creator: player,
                state: 1, // Open
                size,
                mines_amount,
                started_timestamp: current_timestamp,
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
                                action: Option::Some('reveal'),
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
                        action: Option::None,
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
            let mut core_world = self.world(@"pixelaw");

            let game: MinesweeperGame = app_world.read_model(game_position);
            let safe_cells = (game.size * game.size) - game.mines_amount;

            // Count revealed safe cells and stop early if all found
            let mut revealed_safe = 0;
            let mut x = 0;
            while x < game.size && revealed_safe < safe_cells {
                let mut y = 0;
                while y < game.size && revealed_safe < safe_cells {
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

            // Check win condition
            if revealed_safe == safe_cells {
                // Update game state to finished
                let mut game_state = game;
                game_state.state = 2; // Finished
                app_world.write_model(@game_state);

                let core_actions = get_core_actions(ref core_world);
                core_actions
                    .notification(
                        game_position,
                        0xFF00FF00, // Green
                        Option::Some(game.creator),
                        Option::None,
                        'You won!',
                    );
            }
        }
    }
}
