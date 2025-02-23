use starknet::{ContractAddress};
// use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

use pixelaw::core::utils::{ DefaultParameters};

const APP_KEY: felt252 = 'rps';
const APP_ICON: felt252 = 'U+270A';

const GAME_MAX_DURATION: u64 = 20000;


#[derive(Serde, Copy, Drop, PartialEq, Introspect)]
enum State {
    None: (),
    Created: (),
    Joined: (),
    Finished: ()
}

#[derive(Serde, Copy, Drop, PartialEq, Introspect)]
enum Move {
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
struct Game {
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
    started_timestamp: u64
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct Player {
    #[key]
    player_id: felt252,
    wins: u32
}


#[starknet::interface]
trait IRpsActions<T> {
    fn init(ref self: T);
    fn secondary(ref self: T, default_params: DefaultParameters);
    fn interact(ref self: T, default_params: DefaultParameters, cr_Move_move: felt252);
    fn join(ref self: T, default_params: DefaultParameters, player2_move: Move);
    fn finish(ref self: T, default_params: DefaultParameters, rv_move: Move, rs_move: felt252);
}

#[dojo::contract]
mod rps_actions {
    use dojo::event::EventStorage;
    use dojo::model::{ModelStorage};
    // use dojo::world::storage::WorldStorage;
    use dojo::world::{IWorldDispatcherTrait};
    use core::poseidon::poseidon_hash_span;
    use starknet::{ContractAddress,   get_contract_address};


    use pixelaw::core::models::pixel::{Pixel, PixelUpdate};
    use pixelaw::core::utils::{get_core_actions,  get_callers, DefaultParameters};

    use pixelaw::core::actions::{  IActionsDispatcherTrait};

    use super::IRpsActions;
    use super::{APP_KEY, APP_ICON,  Move, State};
    use super::{Game};

    use core::num::traits::Zero;
    // use dojo::database::introspect::Introspect;
    // use pixelaw::core::traits::IInteroperability;
    // use pixelaw::core::models::registry::{App};

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    struct GameCreated {
        #[key]
        game_id: u32,
        creator: ContractAddress
    }





    // impl: implement functions specified in trait
    #[abi(embed_v0)]
    impl RpsActionsImpl of IRpsActions<ContractState> {
        /// Initialize the Paint App (TODO I think, do we need this??)
        fn init(ref self: ContractState) {
            let mut world = self.world(@"pixelaw");
            let core_actions = get_core_actions(ref world);

            core_actions.new_app(Zero::<ContractAddress>::zero(), APP_KEY, APP_ICON);
        }


        fn interact(ref self: ContractState, default_params: DefaultParameters, cr_Move_move: felt252) {

            let mut world = self.world(@"pixelaw");
            let core_actions = get_core_actions(ref world);
            let position = default_params.position;

            let (player, system) = get_callers(ref world, default_params);

            let pixel: Pixel = world.read_model((position.x, position.y));

            // Bail if the caller is not allowed here
            assert(pixel.owner.is_zero() || pixel.owner == player, 'Pixel is not players');

            // Load the game
            let mut game: Game = world.read_model((position.x, position.y));
            // let mut game = get!(world, (position.x, position.y), Game);

            if game.id != 0 {
                // Bail if we're waiting for other player
                assert(game.state == State::Created, 'cannot reset rps game');

                // Player1 changing their commit
                game.player1_commit = cr_Move_move;
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
                        player1_commit: cr_Move_move,
                        player1_move: Move::None,
                        player2_move: Move::None,
                        started_timestamp: starknet::get_block_timestamp()
                    };
                // Emit event
                // emit!(world, GameCreated { game_id: game.id, creator: player });
                world
                .emit_event(
                    @GameCreated  { game_id: game.id, creator: player },
                );
            }

            // game entity
            // set!(world, (game));
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
                        text: Option::Some(
                            'U+2753'
                        ), // TODO better approach, for now copying unicode codepoint
                        app: Option::Some(get_contract_address().into()),
                        owner: Option::Some(player.into()),
                        action: Option::Some('join')
                    },
                    Option::None,   // area_id hint for this pixel
                    false,          // allow modify of this update
                );
        }


        fn join(ref self: ContractState, default_params: DefaultParameters, player2_move: Move) {
            let mut world = self.world(@"pixelaw");
            let core_actions = get_core_actions(ref world);
            let position = default_params.position;

            let (player, system) = get_callers(ref world, default_params);

            let mut game: Game = world.read_model((position.x, position.y));


            // Bail if theres no game at all
            assert(game.id != 0, 'No game to join');

            // Bail if wrong gamestate
            assert(game.state == State::Created, 'Wrong gamestate');


            // Bail if the player is joining their own game
            assert(game.player1 != player, 'Cant join own game');


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
                        color: Option::None,
                        timestamp: Option::None,
                        text: Option::Some(
                            'U+2757'
                        ), // TODO better approach, for now copying unicode codepoint
                        app: Option::None,
                        owner: Option::None,
                        action: Option::Some('finish')
                    },
                    Option::None,   // area_id hint for this pixel
                    false,          // allow modify of this update
                );
        }


        fn finish(ref self: ContractState, default_params: DefaultParameters, rv_move: Move, rs_move: felt252) {

            let mut world = self.world(@"pixelaw");
            let core_actions = get_core_actions(ref world);
            let position = default_params.position;

            let (player, system) = get_callers(ref world, default_params);

            let mut game: Game = world.read_model((position.x, position.y));

            // Bail if theres no game at all
            assert(game.id != 0, 'No game to finish');

            // Bail if wrong gamestate
            assert(game.state == State::Joined, 'Wrong gamestate');

            // Bail if another player is finishing (has to be player1)
            assert(game.player1 == player, 'Cant finish others game');

            // Check player1's move
            assert(
                validate_commit(game.player1_commit, rv_move, rs_move), 'player1 cheating'
            );

            // Decide the winner
            let winner = decide(rv_move, game.player2_move);

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
                            action: Option::Some(0)
                        },
                        Option::None,   // area_id hint for this pixel
                        false,          // allow modify of this update
                    );
            // TODO emit event
            } else {
                // Update the game
                game.player1_move = rv_move;
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
                                action: Option::Some('finish')  // TODO, probably want to change color still
                            },
                            Option::None,   // area_id hint for this pixel
                            false,          // allow modify of this update
                        );
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
                                action: Option::Some('finish')  // TODO, probably want to change color still
                            },
                            Option::None,   // area_id hint for this pixel
                            false,          // allow modify of this update
                        );
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
            assert(pixel.owner == player, 'player doesnt own pixel');

  
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
                        action: Option::Some(0)
                    },
                    Option::None,   // area_id hint for this pixel
                    false,          // allow modify of this update
                );

        }

    }

    fn get_unicode_for_rps(move: Move) -> felt252 {

        match move {
            Move::None => '',
            Move::Rock => 'U+1FAA8',
            Move::Paper => 'U+1F9FB',
            Move::Scissors => 'U+2702',
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

    // TODO: implement proper psuedo random number generator
    fn random(seed: felt252, min: u128, max: u128) -> u128 {
        let seed: u256 = seed.into();
        let range = max - min;

        (seed.low % range) + min
    }

    fn hash_commit(commit: u8, salt: felt252) -> felt252 {
        let mut hash_span = ArrayTrait::<felt252>::new();
        hash_span.append(commit.into());
        hash_span.append(salt.into());

        poseidon_hash_span(hash_span.span())
    }
}
