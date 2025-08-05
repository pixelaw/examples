use pixelaw::core::models::{pixel::{PixelUpdate}, registry::{App}};
use pixelaw::core::utils::{DefaultParameters, Position};
use starknet::{ContractAddress};

/// Game states for TicTacToe
#[derive(Serde, Copy, Drop, PartialEq, Introspect)]
pub enum GameState {
    None: (),
    Active: (),
    PlayerWon: (),
    AIWon: (),
    Tie: (),
}

/// Cell states for TicTacToe grid
#[derive(Serde, Copy, Drop, PartialEq, Introspect)]
pub enum CellState {
    Empty: (),
    Player: (), // X
    AI: (),
}

/// Main game model
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct TicTacToeGame {
    #[key]
    pub position: Position,
    pub player: ContractAddress,
    pub state: GameState,
    pub started_timestamp: u64,
    pub moves_left: u8,
}

/// Individual cell model
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct TicTacToeCell {
    #[key]
    pub position: Position,
    pub game_position: Position, // Reference to game origin
    pub cell_state: CellState,
    pub grid_index: u8,
}

#[starknet::interface]
pub trait ITicTacToeActions<T> {
    fn on_pre_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    ) -> Option<PixelUpdate>;

    fn on_post_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    );

    fn interact(ref self: T, default_params: DefaultParameters);
    fn make_move(ref self: T, default_params: DefaultParameters);
}

/// TicTacToe app constants
pub const APP_KEY: felt252 = 'tictactoe';
pub const APP_ICON: felt252 = 0xf09f8e96; // 🎖️ game/competition emoji
pub const GAME_GRIDSIZE: u16 = 3;

// Visual constants
pub const EMPTY_CELL_COLOR: u32 = 0xFFEEEEEE; // Light gray
pub const PLAYER_X_COLOR: u32 = 0xFFFF0000; // Red
pub const AI_O_COLOR: u32 = 0xFF00FF00; // Green
pub const X_SYMBOL: felt252 = 0x58; // X
pub const O_SYMBOL: felt252 = 0x4F; // O

/// TicTacToe actions contract
#[dojo::contract]
pub mod tictactoe_actions {
    use dojo::model::{ModelStorage};
    use pixelaw::core::actions::{IActionsDispatcherTrait as ICoreActionsDispatcherTrait};
    use pixelaw::core::models::pixel::{Pixel, PixelUpdate, PixelUpdateResultTrait};
    use pixelaw::core::models::registry::App;
    use pixelaw::core::utils::{DefaultParameters, Position, get_callers, get_core_actions};
    use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
    use super::{
        APP_ICON, APP_KEY, ITicTacToeActions, TicTacToeGame, TicTacToeCell, GameState, CellState,
        GAME_GRIDSIZE, EMPTY_CELL_COLOR, PLAYER_X_COLOR, AI_O_COLOR, X_SYMBOL, O_SYMBOL,
    };

    // Import ML inference
    use tictactoe::inference::move_selector;

    /// Initialize the TicTacToe App
    fn dojo_init(ref self: ContractState) {
        let mut world = self.world(@"pixelaw");
        let core_actions = get_core_actions(ref world);
        core_actions.new_app(contract_address_const::<0>(), APP_KEY, APP_ICON);
    }

    #[abi(embed_v0)]
    impl ActionsImpl of ITicTacToeActions<ContractState> {
        fn on_pre_update(
            ref self: ContractState,
            pixel_update: PixelUpdate,
            app_caller: App,
            player_caller: ContractAddress,
        ) -> Option<PixelUpdate> {
            // Allow updates only from tictactoe app
            if app_caller.name == APP_KEY {
                Option::Some(pixel_update)
            } else {
                Option::None
            }
        }

        fn on_post_update(
            ref self: ContractState,
            pixel_update: PixelUpdate,
            app_caller: App,
            player_caller: ContractAddress,
        ) { // No post-update actions needed
        }

        fn interact(ref self: ContractState, default_params: DefaultParameters) {
            let mut _core_world = self.world(@"pixelaw");
            let mut app_world = self.world(@"tictactoe");
            let position = default_params.position;

            // Check if there's already a cell here (indicating an existing game)
            let existing_cell: TicTacToeCell = app_world.read_model(position);

            if existing_cell.game_position.x == 0 && existing_cell.game_position.y == 0 {
                // No cell exists, create new game
                self.init_game(default_params);
            } else {
                // Cell exists, try to make a move
                self.make_move(default_params);
            }
        }

        fn make_move(ref self: ContractState, default_params: DefaultParameters) {
            let mut core_world = self.world(@"pixelaw");
            let mut app_world = self.world(@"tictactoe");

            let core_actions = get_core_actions(ref core_world);
            let (player, system) = get_callers(ref core_world, default_params);
            let position = default_params.position;

            // Get the cell
            let mut cell: TicTacToeCell = app_world.read_model(position);
            assert!(cell.cell_state == CellState::Empty, "Cell already occupied");

            // Get the game
            let mut game: TicTacToeGame = app_world.read_model(cell.game_position);
            assert!(game.state == GameState::Active, "Game not active");
            assert!(game.player == player, "Not your game");

            // Make player move
            cell.cell_state = CellState::Player;
            app_world.write_model(@cell);

            // Update pixel
            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        position,
                        color: Option::Some(PLAYER_X_COLOR),
                        timestamp: Option::None,
                        text: Option::Some(X_SYMBOL),
                        app: Option::Some(system),
                        owner: Option::Some(player),
                        action: Option::None,
                    },
                    Option::None,
                    false,
                )
                .unwrap();

            game.moves_left -= 1;
            app_world.write_model(@game);

            // Check for win/tie
            let winner = self.check_winner(game.position);
            if winner == CellState::Player {
                game.state = GameState::PlayerWon;
                app_world.write_model(@game);

                core_actions
                    .notification(
                        position, PLAYER_X_COLOR, Option::Some(player), Option::None, 'You won!',
                    );
                return;
            } else if game.moves_left == 0 {
                game.state = GameState::Tie;
                app_world.write_model(@game);

                core_actions
                    .notification(
                        position, EMPTY_CELL_COLOR, Option::Some(player), Option::None, 'Tie game!',
                    );
                return;
            }

            // AI move
            let ai_move_index = self.get_ai_move(game.position);
            if ai_move_index < 9 {
                let ai_position = self.index_to_position(game.position, ai_move_index);
                let mut ai_cell: TicTacToeCell = app_world.read_model(ai_position);

                ai_cell.cell_state = CellState::AI;
                app_world.write_model(@ai_cell);

                core_actions
                    .update_pixel(
                        player,
                        system,
                        PixelUpdate {
                            position: ai_position,
                            color: Option::Some(AI_O_COLOR),
                            timestamp: Option::None,
                            text: Option::Some(O_SYMBOL),
                            app: Option::Some(system),
                            owner: Option::Some(player),
                            action: Option::None,
                        },
                        Option::None,
                        false,
                    )
                    .unwrap();

                game.moves_left -= 1;
                app_world.write_model(@game);

                // Check AI win
                let winner = self.check_winner(game.position);
                if winner == CellState::AI {
                    game.state = GameState::AIWon;
                    app_world.write_model(@game);

                    core_actions
                        .notification(
                            position, AI_O_COLOR, Option::Some(player), Option::None, 'AI won!',
                        );
                } else if game.moves_left == 0 {
                    game.state = GameState::Tie;
                    app_world.write_model(@game);

                    core_actions
                        .notification(
                            position,
                            EMPTY_CELL_COLOR,
                            Option::Some(player),
                            Option::None,
                            'Tie game!',
                        );
                }
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn init_game(ref self: ContractState, default_params: DefaultParameters) {
            let mut core_world = self.world(@"pixelaw");
            let mut app_world = self.world(@"tictactoe");

            let core_actions = get_core_actions(ref core_world);
            let (player, system) = get_callers(ref core_world, default_params);
            let position = default_params.position;
            let current_timestamp = get_block_timestamp();

            // Validate 3x3 area is empty
            self.validate_empty_area(position);

            // Create game
            let game = TicTacToeGame {
                position,
                player,
                state: GameState::Active,
                started_timestamp: current_timestamp,
                moves_left: 9,
            };
            app_world.write_model(@game);

            // Initialize 3x3 grid
            let mut index = 0;
            let mut x = 0;
            while x < GAME_GRIDSIZE {
                let mut y = 0;
                while y < GAME_GRIDSIZE {
                    let cell_position = Position { x: position.x + x, y: position.y + y };

                    // Create cell model
                    let cell = TicTacToeCell {
                        position: cell_position,
                        game_position: position,
                        cell_state: CellState::Empty,
                        grid_index: index,
                    };
                    app_world.write_model(@cell);

                    // Update pixel
                    core_actions
                        .update_pixel(
                            player,
                            system,
                            PixelUpdate {
                                position: cell_position,
                                color: Option::Some(EMPTY_CELL_COLOR),
                                timestamp: Option::None,
                                text: Option::None,
                                app: Option::Some(system),
                                owner: Option::Some(player),
                                action: Option::Some('play'),
                            },
                            Option::None,
                            false,
                        )
                        .unwrap();

                    index += 1;
                    y += 1;
                };
                x += 1;
            };

            // Send notification
            core_actions
                .notification(
                    position,
                    default_params.color,
                    Option::Some(player),
                    Option::None,
                    'TicTacToe started!',
                );
        }

        fn validate_empty_area(ref self: ContractState, position: Position) {
            let mut core_world = self.world(@"pixelaw");

            let mut x = 0;
            while x < GAME_GRIDSIZE {
                let mut y = 0;
                while y < GAME_GRIDSIZE {
                    let check_position = Position { x: position.x + x, y: position.y + y };
                    let pixel: Pixel = core_world.read_model(check_position);
                    assert!(pixel.owner == contract_address_const::<0>(), "Need 3x3 empty area");
                    y += 1;
                };
                x += 1;
            };
        }

        fn get_board_state(ref self: ContractState, game_position: Position) -> Array<u8> {
            let mut app_world = self.world(@"tictactoe");
            let mut board = ArrayTrait::new();

            let mut x = 0;
            while x < GAME_GRIDSIZE {
                let mut y = 0;
                while y < GAME_GRIDSIZE {
                    let cell_position = Position { x: game_position.x + x, y: game_position.y + y };
                    let cell: TicTacToeCell = app_world.read_model(cell_position);

                    let state_value = match cell.cell_state {
                        CellState::Empty => 0_u8,
                        CellState::Player => 1_u8,
                        CellState::AI => 2_u8,
                    };
                    board.append(state_value);
                    y += 1;
                };
                x += 1;
            };
            board
        }

        fn get_ai_move(ref self: ContractState, game_position: Position) -> u8 {
            let board_state = self.get_board_state(game_position);

            // Try to use ML inference, fallback to simple AI if it fails
            match move_selector(board_state.clone()) {
                Option::Some(ai_move) => {
                    if ai_move < 9 {
                        ai_move.try_into().unwrap()
                    } else {
                        self.simple_ai_move(board_state)
                    }
                },
                Option::None => self.simple_ai_move(board_state),
            }
        }

        fn simple_ai_move(ref self: ContractState, board_state: Array<u8>) -> u8 {
            // Simple AI: find first empty cell
            let mut index: u32 = 0;
            let mut result: u8 = 9; // Default: no move available
            while index < 9 {
                if *board_state.at(index) == 0 {
                    result = index.try_into().unwrap();
                    break;
                }
                index += 1;
            };
            result
        }

        fn index_to_position(ref self: ContractState, origin: Position, index: u8) -> Position {
            Position { x: origin.x + (index % 3).into(), y: origin.y + (index / 3).into() }
        }

        fn check_winner(ref self: ContractState, game_position: Position) -> CellState {
            let board = self.get_board_state(game_position);
            let mut winner = CellState::Empty;

            // Check rows
            let mut row = 0;
            while row < 3 {
                let start_idx = row * 3;
                if *board.at(start_idx) != 0
                    && *board.at(start_idx) == *board.at(start_idx + 1)
                    && *board.at(start_idx) == *board.at(start_idx + 2) {
                    winner = self.u8_to_cell_state(*board.at(start_idx));
                    break;
                }
                row += 1;
            };

            if winner != CellState::Empty {
                winner
            } else {
                // Check columns
                let mut col = 0;
                while col < 3 {
                    if *board.at(col) != 0
                        && *board.at(col) == *board.at(col + 3)
                        && *board.at(col) == *board.at(col + 6) {
                        winner = self.u8_to_cell_state(*board.at(col));
                        break;
                    }
                    col += 1;
                };

                if winner != CellState::Empty {
                    winner
                } else {
                    // Check diagonals
                    if *board.at(0) != 0
                        && *board.at(0) == *board.at(4)
                        && *board.at(0) == *board.at(8) {
                        self.u8_to_cell_state(*board.at(0))
                    } else if *board.at(2) != 0
                        && *board.at(2) == *board.at(4)
                        && *board.at(2) == *board.at(6) {
                        self.u8_to_cell_state(*board.at(2))
                    } else {
                        CellState::Empty // No winner
                    }
                }
            }
        }

        fn u8_to_cell_state(ref self: ContractState, value: u8) -> CellState {
            if value == 1 {
                CellState::Player
            } else if value == 2 {
                CellState::AI
            } else {
                CellState::Empty
            }
        }
    }
}
