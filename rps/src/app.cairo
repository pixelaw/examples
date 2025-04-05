use starknet::{ContractAddress};
use pixelaw::core::models::{pixel::{PixelUpdate}, registry::{App}};

use pixelaw::core::utils::{DefaultParameters};

const APP_KEY: felt252 = 'rps';
const APP_ICON: felt252 = 0xf09f918a; // 👊

const GAME_MAX_DURATION: u64 = 20000;


#[derive(Serde, Copy, Drop, PartialEq, Introspect)]
pub enum State {
    None: (),
    Created: (),
    Joined: (),
    Finished: (),
}

#[derive(Serde, Copy, Drop, PartialEq, Introspect)]
pub enum Move {
    None: (),
    Rock: (),
    Paper: (),
    Scissors: (),
}

impl MoveIntoFelt252 of Into<Move, felt252> {
    fn into(self: Move) -> felt252 {
        match self {
            Move::None(()) => 0,
            Move::Rock(()) => 1,
            Move::Paper(()) => 2,
            Move::Scissors(()) => 3,
        }
    }
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Game {
    #[key]
    x: u16,
    #[key]
    y: u16,
    id: u32,
    state: State,
    player1: ContractAddress,
    player2: ContractAddress,
    player1_commit: felt252,
    player1_move: Move,
    player2_move: Move,
    started_timestamp: u64,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Player {
    #[key]
    player_id: felt252,
    wins: u32,
}


#[starknet::interface]
pub trait IRpsActions<T> {
    fn secondary(ref self: T, default_params: DefaultParameters);
    fn interact(ref self: T, default_params: DefaultParameters, crc_move_Move: felt252);
    fn join(ref self: T, default_params: DefaultParameters, player2_move: Move);
    fn finish(ref self: T, default_params: DefaultParameters, crv_move: Move, crs_move: felt252);
    fn on_pre_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    ) -> Option<PixelUpdate>;

    fn on_post_update(
        ref self: T, pixel_update: PixelUpdate, app_caller: App, player_caller: ContractAddress,
    );
}

#[dojo::contract]
pub mod rps_actions {
    use pixelaw::core::models::pixel::PixelUpdateResultTrait;

    use dojo::model::{ModelStorage};
    use dojo::world::{IWorldDispatcherTrait};
    use core::poseidon::poseidon_hash_span;
    use starknet::{ContractAddress, get_contract_address};
    use starknet::{contract_address_const};
    use pixelaw::core::models::registry::App;

    use pixelaw::core::models::pixel::{Pixel, PixelUpdate};
    use pixelaw::core::utils::{get_core_actions, get_callers, DefaultParameters};

    use pixelaw::core::actions::{IActionsDispatcherTrait};

    use super::IRpsActions;
    use super::{APP_KEY, APP_ICON, Move, State};
    use super::{Game};

    use core::num::traits::Zero;

    const ICON_QUESTIONMARK: felt252 = 0xe29d93efb88f; // ❓
    const ICON_EXCLAMATION_MARK: felt252 = 0xe29d97; // ❗
    const ICON_FIST: felt252 = 0xf09fa49b; // 🤛
    const ICON_PAPER: felt252 = 0xf09f9690; // 🖐
    const ICON_SCISSOR: felt252 = 0xe29c8cefb88f; // ✌️

    fn dojo_init(ref self: ContractState) {
        let mut world = self.world(@"pixelaw");
        let core_actions = get_core_actions(ref world);

        core_actions.new_app(contract_address_const::<0>(), APP_KEY, APP_ICON);
    }

    // impl: implement functions specified in trait
    #[abi(embed_v0)]
    impl RpsActionsImpl of IRpsActions<ContractState> {
        fn on_pre_update(
            ref self: ContractState,
            pixel_update: PixelUpdate,
            app_caller: App,
            player_caller: ContractAddress,
        ) -> Option<PixelUpdate> {
            let mut result = Option::None; //Default is to not allow anything

            // Only RPS app can call this update
            // TODO is this secure enough? And maybe move this to core?
            if app_caller.name == APP_KEY {
                result = Option::Some(pixel_update);
            }

            result
        }


        fn on_post_update(
            ref self: ContractState,
            pixel_update: PixelUpdate,
            app_caller: App,
            player_caller: ContractAddress,
        ) { // No action
        }

        fn interact(
            ref self: ContractState, default_params: DefaultParameters, crc_move_Move: felt252,
        ) {
            let mut world = self.world(@"pixelaw");
            let core_actions = get_core_actions(ref world);
            let position = default_params.position;

            let (player, system) = get_callers(ref world, default_params);

            let pixel: Pixel = world.read_model((position.x, position.y));

            // Bail if the caller is not allowed here
            assert!(
                pixel.owner.is_zero() || pixel.owner == player,
                "{:?}_{:?} Pixel is not players",
                position.x,
                position.y,
            );

            // Load the game
            let mut game: Game = world.read_model((position.x, position.y));

            if game.id != 0 {
                // Bail if we're waiting for other player
                assert!(
                    game.state == State::Created,
                    "{:?}_{:?} Cannot reset rps game",
                    position.x,
                    position.y,
                );

                // Player1 changing their commit
                game.player1_commit = crc_move_Move;
            } else {
                let mut id = world.dispatcher.uuid();
                if id == 0 {
                    id = world.dispatcher.uuid();
                }

                game =
                    Game {
                        x: position.x,
                        y: position.y,
                        id,
                        state: State::Created,
                        player1: player,
                        player2: Zero::<ContractAddress>::zero(),
                        player1_commit: crc_move_Move,
                        player1_move: Move::None,
                        player2_move: Move::None,
                        started_timestamp: starknet::get_block_timestamp(),
                    };
                // TODO Emit event

            }

            // game entity
            world.write_model(@game);

            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        x: position.x,
                        y: position.y,
                        color: Option::Some(default_params.color),
                        timestamp: Option::None,
                        text: Option::Some(ICON_QUESTIONMARK),
                        app: Option::Some(get_contract_address().into()),
                        owner: Option::Some(player.into()),
                        action: Option::Some('join'),
                    },
                    Option::None, // area_id hint for this pixel
                    false // allow modify of this update
                )
                .unwrap();
        }


        fn join(ref self: ContractState, default_params: DefaultParameters, player2_move: Move) {
            let mut world = self.world(@"pixelaw");
            let core_actions = get_core_actions(ref world);
            let position = default_params.position;

            let (player, system) = get_callers(ref world, default_params);

            let mut game: Game = world.read_model((position.x, position.y));

            // Bail if theres no game at all
            assert!(game.id != 0, "{:?}_{:?} No game to join", position.x, position.y);

            // Bail if wrong gamestate
            assert!(
                game.state == State::Created, "{:?}_{:?} Wrong gamestate", position.x, position.y,
            );

            // Bail if the player is joining their own game
            assert!(
                game.player1 != player, "{:?}_{:?} Cannot join own game", position.x, position.y,
            );

            // Update the game
            game.player2 = player;
            game.player2_move = player2_move;
            game.state = State::Joined;

            // game entity
            world.write_model(@game);

            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        x: position.x,
                        y: position.y,
                        color: Option::Some(default_params.color),
                        timestamp: Option::None,
                        text: Option::Some(ICON_EXCLAMATION_MARK),
                        app: Option::None,
                        owner: Option::None,
                        action: Option::Some('finish'),
                    },
                    Option::None, // area_id hint for this pixel
                    false // allow modify of this update
                )
                .unwrap();
        }


        fn finish(
            ref self: ContractState,
            default_params: DefaultParameters,
            crv_move: Move,
            crs_move: felt252,
        ) {
            let mut world = self.world(@"pixelaw");
            let core_actions = get_core_actions(ref world);
            let position = default_params.position;

            let (player, system) = get_callers(ref world, default_params);

            let mut game: Game = world.read_model((position.x, position.y));

            // Bail if theres no game at all
            assert!(game.id != 0, "{:?}_{:?} No game to finish", position.x, position.y);

            // Bail if wrong gamestate
            assert!(
                game.state == State::Joined, "{:?}_{:?} Wrong gamestate", position.x, position.y,
            );

            // Bail if another player is finishing (has to be player1)
            assert!(
                game.player1 == player, "{:?}_{:?} Cant finish others game", position.x, position.y,
            );

            // Check player1's move
            assert!(
                validate_commit(game.player1_commit, crv_move, crs_move),
                "{:?}_{:?} player1 invalid commitreveal",
                position.x,
                position.y,
            );

            // Decide the winner
            let winner = decide(crv_move, game.player2_move);

            if winner == 0 { // No winner: Wipe the pixel
                core_actions
                    .update_pixel(
                        player,
                        system,
                        PixelUpdate {
                            x: position.x,
                            y: position.y,
                            color: Option::None,
                            timestamp: Option::None,
                            text: Option::Some(0),
                            app: Option::Some(Zero::<ContractAddress>::zero()),
                            owner: Option::Some(Zero::<ContractAddress>::zero()),
                            action: Option::Some(0),
                        },
                        Option::None, // area_id hint for this pixel
                        false // allow modify of this update
                    )
                    .unwrap();
                // TODO emit event
            } else {
                // Update the game
                game.player1_move = crv_move;
                game.state = State::Finished;

                if winner == 2 {
                    // Change ownership of Pixel to player2
                    // TODO refactor, this could be cleaner
                    core_actions
                        .update_pixel(
                            player,
                            system,
                            PixelUpdate {
                                x: position.x,
                                y: position.y,
                                color: Option::None,
                                timestamp: Option::None,
                                text: Option::Some(get_unicode_for_rps(game.player2_move)),
                                app: Option::None,
                                owner: Option::Some(game.player2),
                                action: Option::Some(
                                    'finish',
                                ) // TODO, probably want to change color still
                            },
                            Option::None, // area_id hint for this pixel
                            false // allow modify of this update
                        )
                        .unwrap();
                } else {
                    core_actions
                        .update_pixel(
                            player,
                            system,
                            PixelUpdate {
                                x: position.x,
                                y: position.y,
                                color: Option::None,
                                timestamp: Option::None,
                                text: Option::Some(get_unicode_for_rps(game.player1_move)),
                                app: Option::None,
                                owner: Option::None,
                                action: Option::Some(
                                    'finish',
                                ) // TODO, probably want to change color still
                            },
                            Option::None, // area_id hint for this pixel
                            false // allow modify of this update
                        )
                        .unwrap();
                }
            }

            // game entity
            world.write_model(@game);
        }

        fn secondary(ref self: ContractState, default_params: DefaultParameters) {
            let mut world = self.world(@"pixelaw");
            let core_actions = get_core_actions(ref world);
            let position = default_params.position;

            let (player, system) = get_callers(ref world, default_params);

            let mut game: Game = world.read_model((position.x, position.y));
            let pixel: Pixel = world.read_model((position.x, position.y));

            // reset the pixel in the right circumstances
            assert!(
                pixel.owner == player, "{:?}_{:?} player doesnt own pixel", position.x, position.y,
            );

            world.erase_model(@game);

            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        x: position.x,
                        y: position.y,
                        color: Option::Some(0),
                        timestamp: Option::None,
                        text: Option::Some(0),
                        app: Option::Some(Zero::<ContractAddress>::zero()),
                        owner: Option::Some(Zero::<ContractAddress>::zero()),
                        action: Option::Some(0),
                    },
                    Option::None, // area_id hint for this pixel
                    false // allow modify of this update
                )
                .unwrap();
        }
    }


    fn get_unicode_for_rps(move: Move) -> felt252 {
        match move {
            Move::None => 0x00,
            Move::Rock => ICON_FIST,
            Move::Paper => ICON_PAPER,
            Move::Scissors => ICON_SCISSOR,
        }
    }

    fn validate_commit(committed_hash: felt252, move: Move, salt: felt252) -> bool {
        let mut hash_span = ArrayTrait::<felt252>::new();
        hash_span.append(move.into());
        hash_span.append(salt.into());

        let computed_hash: felt252 = poseidon_hash_span(hash_span.span());

        committed_hash == computed_hash
    }


    fn decide(player1_commit: Move, player2_commit: Move) -> u8 {
        if player1_commit == Move::Rock && player2_commit == Move::Paper {
            2
        } else if player1_commit == Move::Paper && player2_commit == Move::Rock {
            1
        } else if player1_commit == Move::Rock && player2_commit == Move::Scissors {
            1
        } else if player1_commit == Move::Scissors && player2_commit == Move::Rock {
            2
        } else if player1_commit == Move::Scissors && player2_commit == Move::Paper {
            1
        } else if player1_commit == Move::Paper && player2_commit == Move::Scissors {
            2
        } else {
            0
        }
    }
}
