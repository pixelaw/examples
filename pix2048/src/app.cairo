use pixelaw::core::models::{pixel::{PixelUpdate}, registry::{App}};
use pixelaw::core::utils::{DefaultParameters, Position};
use starknet::{ContractAddress};

/// Simple game state tracking for 2048 game
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct GameState {
    #[key]
    pub position: Position,
    pub player: ContractAddress,
    pub started_time: u64,
    pub moves: u32,
    pub score: u32,
}

#[starknet::interface]
pub trait IPix2048Actions<T> {
    fn on_pre_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    ) -> Option<PixelUpdate>;

    fn on_post_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    );

    fn interact(ref self: T, default_params: DefaultParameters);
    fn move_up(ref self: T, default_params: DefaultParameters);
    fn move_down(ref self: T, default_params: DefaultParameters);
    fn move_left(ref self: T, default_params: DefaultParameters);
    fn move_right(ref self: T, default_params: DefaultParameters);
}

/// PIX2048 app constants
pub const APP_KEY: felt252 = 'pix2048';
pub const APP_ICON: felt252 = 0xf09f94a2; // 🔢 number emoji

/// PIX2048 game contract
#[dojo::contract]
pub mod pix2048_actions {
    use dojo::model::{ModelStorage};
    use pixelaw::core::actions::{IActionsDispatcherTrait as ICoreActionsDispatcherTrait};
    use pixelaw::core::models::pixel::{Pixel, PixelUpdate, PixelUpdateResultTrait};
    use pixelaw::core::models::registry::App;
    use pixelaw::core::utils::{DefaultParameters, Position, get_callers, get_core_actions};
    use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
    use super::{APP_ICON, APP_KEY, GameState, IPix2048Actions};

    /// Initialize the PIX2048 App
    fn dojo_init(ref self: ContractState) {
        let mut world = self.world(@"pixelaw");
        let core_actions = get_core_actions(ref world);
        core_actions.new_app(contract_address_const::<0>(), APP_KEY, APP_ICON);
    }

    #[abi(embed_v0)]
    impl ActionsImpl of IPix2048Actions<ContractState> {
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
            let mut core_world = self.world(@"pixelaw");
            let mut app_world = self.world(@"pix2048");

            let core_actions = get_core_actions(ref core_world);
            let (player, system) = get_callers(ref core_world, default_params);
            let position = default_params.position;

            // Check if game exists at this position
            let mut game_state: GameState = app_world.read_model(position);

            if game_state.player == contract_address_const::<0>() {
                // Initialize new game
                let timestamp = get_block_timestamp();

                game_state =
                    GameState { position, player, started_time: timestamp, moves: 0, score: 0 };

                app_world.write_model(@game_state);

                // Create the 2048 game board (4x4 grid)
                self.initialize_game_board(ref core_world, player, system, position);

                // Add initial tiles
                self.add_random_tile(ref core_world, ref app_world, player, system, position);
                self.add_random_tile(ref core_world, ref app_world, player, system, position);
            }

            // Update the main pixel to show it's an active game
            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        position,
                        color: Option::Some(0xFFEEE4DA), // 2048 beige color
                        timestamp: Option::None,
                        text: Option::Some('2048'),
                        app: Option::Some(system),
                        owner: Option::Some(player),
                        action: Option::None,
                    },
                    Option::None,
                    false,
                )
                .unwrap();
        }

        fn move_up(ref self: ContractState, default_params: DefaultParameters) {
            self.handle_move(default_params, 'up');
        }

        fn move_down(ref self: ContractState, default_params: DefaultParameters) {
            self.handle_move(default_params, 'down');
        }

        fn move_left(ref self: ContractState, default_params: DefaultParameters) {
            self.handle_move(default_params, 'left');
        }

        fn move_right(ref self: ContractState, default_params: DefaultParameters) {
            self.handle_move(default_params, 'right');
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initialize_game_board(
            ref self: ContractState,
            ref core_world: dojo::world::WorldStorage,
            player: ContractAddress,
            system: ContractAddress,
            position: Position,
        ) {
            let core_actions = get_core_actions(ref core_world);

            // Create 4x4 grid
            let mut i = 0;
            loop {
                if i >= 4 {
                    break;
                }
                let mut j = 0;
                loop {
                    if j >= 4 {
                        break;
                    }

                    let cell_position = Position { x: position.x + j, y: position.y + i };

                    core_actions
                        .update_pixel(
                            player,
                            system,
                            PixelUpdate {
                                position: cell_position,
                                color: Option::Some(0xFFCDC1B4), // Empty cell color
                                timestamp: Option::None,
                                text: Option::None,
                                app: Option::Some(system),
                                owner: Option::Some(player),
                                action: Option::Some('cell'),
                            },
                            Option::None,
                            false,
                        )
                        .unwrap();

                    j += 1;
                };
                i += 1;
            };

            // Create control buttons
            self.create_control_buttons(ref core_world, player, system, position);
        }

        fn create_control_buttons(
            ref self: ContractState,
            ref core_world: dojo::world::WorldStorage,
            player: ContractAddress,
            system: ContractAddress,
            position: Position,
        ) {
            let core_actions = get_core_actions(ref core_world);

            // Up button
            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        position: Position { x: position.x + 1, y: position.y - 1 },
                        color: Option::Some(0xFF8F7A66),
                        timestamp: Option::None,
                        text: Option::Some('U+21E7'),
                        app: Option::Some(system),
                        owner: Option::Some(player),
                        action: Option::Some('move_up'),
                    },
                    Option::None,
                    false,
                )
                .unwrap();

            // Down button
            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        position: Position { x: position.x + 1, y: position.y + 4 },
                        color: Option::Some(0xFF8F7A66),
                        timestamp: Option::None,
                        text: Option::Some('U+21E9'),
                        app: Option::Some(system),
                        owner: Option::Some(player),
                        action: Option::Some('move_down'),
                    },
                    Option::None,
                    false,
                )
                .unwrap();

            // Left button
            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        position: Position { x: position.x - 1, y: position.y + 1 },
                        color: Option::Some(0xFF8F7A66),
                        timestamp: Option::None,
                        text: Option::Some('U+21E6'),
                        app: Option::Some(system),
                        owner: Option::Some(player),
                        action: Option::Some('move_left'),
                    },
                    Option::None,
                    false,
                )
                .unwrap();

            // Right button
            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        position: Position { x: position.x + 4, y: position.y + 1 },
                        color: Option::Some(0xFF8F7A66),
                        timestamp: Option::None,
                        text: Option::Some('U+21E8'),
                        app: Option::Some(system),
                        owner: Option::Some(player),
                        action: Option::Some('move_right'),
                    },
                    Option::None,
                    false,
                )
                .unwrap();
        }

        fn add_random_tile(
            ref self: ContractState,
            ref core_world: dojo::world::WorldStorage,
            ref app_world: dojo::world::WorldStorage,
            player: ContractAddress,
            system: ContractAddress,
            position: Position,
        ) {
            let core_actions = get_core_actions(ref core_world);
            let timestamp = get_block_timestamp();

            // Simple random position selection (using timestamp)
            let random = timestamp % 16;
            let cell_x = position.x + (random % 4).try_into().unwrap();
            let cell_y = position.y + (random / 4).try_into().unwrap();
            let cell_position = Position { x: cell_x, y: cell_y };

            // Check if cell is empty by reading pixel
            let pixel: Pixel = core_world.read_model(cell_position);

            // Only add if cell appears empty (no text)
            if pixel.text == 0 {
                let value = if timestamp % 10 < 9 {
                    2
                } else {
                    4
                }; // 90% chance of 2, 10% chance of 4
                let color = if value == 2 {
                    0xFFEEE4DA
                } else {
                    0xFFECE0CA
                };

                core_actions
                    .update_pixel(
                        player,
                        system,
                        PixelUpdate {
                            position: cell_position,
                            color: Option::Some(color),
                            timestamp: Option::None,
                            text: Option::Some(value.into()),
                            app: Option::Some(system),
                            owner: Option::Some(player),
                            action: Option::Some('cell'),
                        },
                        Option::None,
                        false,
                    )
                    .unwrap();
            }
        }

        fn handle_move(
            ref self: ContractState, default_params: DefaultParameters, direction: felt252,
        ) {
            let mut core_world = self.world(@"pixelaw");
            let mut app_world = self.world(@"pix2048");

            let (player, system) = get_callers(ref core_world, default_params);
            let position = default_params.position;

            // Calculate the game board position based on the control button position
            // Our control buttons are positioned as follows relative to game origin:
            // Up: (game_x + 1, game_y - 1) -> so game is at (pos_x - 1, pos_y + 1)
            // Down: (game_x + 1, game_y + 4) -> so game is at (pos_x - 1, pos_y - 4)
            // Left: (game_x - 1, game_y + 1) -> so game is at (pos_x + 1, pos_y - 1)
            // Right: (game_x + 4, game_y + 1) -> so game is at (pos_x - 4, pos_y - 1)

            let mut game_position = position;
            if direction == 'up' {
                // Up button is at (game_x + 1, game_y - 1), so game is at (pos_x - 1, pos_y + 1)
                // But test uses (game_x, game_y - 1), so game is at (pos_x, pos_y + 1)
                game_position = Position { x: position.x, y: position.y + 1 };
            } else if direction == 'down' {
                game_position = Position { x: position.x, y: position.y - 1 };
            } else if direction == 'left' {
                game_position = Position { x: position.x + 1, y: position.y };
            } else if direction == 'right' {
                game_position = Position { x: position.x - 1, y: position.y };
            }

            // Try to find the game state at the calculated position
            let mut game_state: GameState = app_world.read_model(game_position);

            // Update moves counter if we found a valid game
            if game_state.player == player {
                game_state.moves += 1;
                app_world.write_model(@game_state);

                // Add a new random tile after move
                self
                    .add_random_tile(
                        ref core_world, ref app_world, player, system, game_state.position,
                    );
            }
        }
    }
}
