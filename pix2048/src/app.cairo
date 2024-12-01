use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
use pixelaw::core::models::pixel::{Pixel, PixelUpdate};
use pixelaw::core::utils::{get_core_actions, Direction, Position, DefaultParameters};
use starknet::{get_caller_address, get_contract_address, get_execution_info, ContractAddress};
// use myapp::vec::{Felt252Vec, VecTrait};
use core::array::ArrayTrait;

#[dojo::interface]
trait INumberActions<TContractState> {
    fn init(ref world: IWorldDispatcher);
    fn interact(ref world: IWorldDispatcher, default_params: DefaultParameters);
    fn init_game(ref world: IWorldDispatcher, default_params: DefaultParameters);
    fn gen_random(ref world: IWorldDispatcher, default_params: DefaultParameters);
    fn move_right(ref world: IWorldDispatcher, default_params: DefaultParameters);
    fn move_up(ref world: IWorldDispatcher, default_params: DefaultParameters);
    fn move_left(ref world: IWorldDispatcher, default_params: DefaultParameters);
    fn move_down(ref world: IWorldDispatcher, default_params: DefaultParameters);
    fn is_game_over(ref world: IWorldDispatcher, default_params: DefaultParameters) -> bool;
    fn ownerless_space(ref world: IWorldDispatcher, default_params: DefaultParameters) -> bool;
    // fn get_digits(ref world: IWorldDispatcher, default_params: DefaultParameters, number: u32) ->
// u32;
// fn get_power(ref world: IWorldDispatcher, default_params: DefaultParameters, base: u32,
// power: u32) -> u32;
// fn to_short_string(ref world: IWorldDispatcher, default_params: DefaultParameters, number:
// u32) -> felt252;
}

/// APP_KEY must be unique across the entire platform
const APP_KEY: felt252 = 'pix2048';

/// Core only supports unicode icons for now
const APP_ICON: felt252 = 'U+1699';


/// contracts must be named as such (APP_KEY + underscore + "actions")
#[dojo::contract(namespace: "pixelaw", nomapping: true)]
mod pix2048_actions {
    use core::option::OptionTrait;
    use core::traits::TryInto;
    use core::array::ArrayTrait;
    use starknet::{
        get_tx_info, get_caller_address, get_contract_address, get_execution_info, ContractAddress
    };

    use pix2048::vec::{Felt252Vec, NullableVec, VecTrait};
    use super::INumberActions;
    use pixelaw::core::models::pixel::{Pixel, PixelUpdate};
    use pixelaw::core::models::registry::{App};
    use pixelaw::core::models::permissions::{Permission};
    use pixelaw::core::actions::{
        IActionsDispatcher as ICoreActionsDispatcher,
        IActionsDispatcherTrait as ICoreActionsDispatcherTrait
    };
    use super::{APP_KEY, APP_ICON};
    use pixelaw::core::utils::{get_core_actions, Direction, Position, DefaultParameters};

    use debug::PrintTrait;
    use pixelaw::core::traits::IInteroperability;
    use pix2048::models::{NumberGame, State, NumberGameField, NumberValue};
    use starknet::{contract_address_const};


    #[derive(Drop, starknet::Event)]
    struct GameOpened {
        game_id: u32,
        player: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        GameOpened: GameOpened
    }

    const size: u32 = 4;

    #[abi(embed_v0)]
    impl ActionsInteroperability of IInteroperability<ContractState> {
        fn on_pre_update(
            ref world: IWorldDispatcher,
            pixel_update: PixelUpdate,
            app_caller: App,
            player_caller: ContractAddress
        ) { // do nothing
        }

        fn on_post_update(
            ref world: IWorldDispatcher,
            pixel_update: PixelUpdate,
            app_caller: App,
            player_caller: ContractAddress
        ) { // do nothing
        }
    }

    #[abi(embed_v0)]
    impl ActionsImpl of INumberActions<ContractState> {
        /// Initialize the MyApp App (TODO I think, do we need this??)

        fn init(ref world: IWorldDispatcher) {
            let core_actions = pixelaw::core::utils::get_core_actions(world);
            core_actions.new_app(contract_address_const::<0>(), APP_KEY, APP_ICON);
        }

        fn interact(ref world: IWorldDispatcher, default_params: DefaultParameters) {
            let position = default_params.position;
            let mut pixel = get!(world, (position.x, position.y), (Pixel));
            if pixel.action == '' {
                assert(self.ownerless_space(default_params) == true, 'Not enough pixels');
                self.init_game(default_params);
                self.gen_random(default_params);
                self.gen_random(default_params);
            } else {
                // assert(self.is_game_over(default_params) == true, 'Game Over!');
                if pixel.action == 'move_left' {
                    self.move_left(default_params);
                } else if pixel.action == 'move_right' {
                    self.move_right(default_params);
                } else if pixel.action == 'move_up' {
                    self.move_up(default_params);
                } else if pixel.action == 'move_down' {
                    self.move_down(default_params);
                }
            }
        }

        fn init_game(ref world: IWorldDispatcher, default_params: DefaultParameters) {
            let core_actions = get_core_actions(world);
            let position = default_params.position;
            let player = core_actions.get_player_address(default_params.for_player);
            let system = core_actions.get_system_address(default_params.for_system);
            let timestamp = starknet::get_block_timestamp();

            let mut pixel = get!(world, (position.x, position.y), (Pixel));
            let caller_address = get_caller_address();
            let mut game = get!(world, (position.x, position.y), NumberGame);
            let mut id = world.uuid();

            game =
                NumberGame {
                    x: position.x,
                    y: position.y,
                    id,
                    player: player,
                    state: State::Open,
                    started_time: timestamp,
                };

            emit!(world, GameOpened { game_id: id, player: player });
            set!(world, (game));

            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        x: position.x + 4,
                        y: position.y,
                        color: Option::Some(
                            0xFF00FF80
                        ), //should I pass in a color to define the minesweepers field color?
                        timestamp: Option::None,
                        text: Option::Some('U+21E7'),
                        app: Option::Some(system),
                        owner: Option::Some(player),
                        action: Option::Some('move_up'),
                    }
                );
            set!(world, (NumberGameField { x: position.x + 4, y: position.y + 2, id: id }));

            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        x: position.x + 4,
                        y: position.y + 1,
                        color: Option::Some(
                            0xFF00FF80
                        ), //should I pass in a color to define the minesweepers field color?
                        timestamp: Option::None,
                        text: Option::Some('U+21E9'),
                        app: Option::Some(system),
                        owner: Option::Some(player),
                        action: Option::Some('move_down'),
                    }
                );
            set!(world, (NumberGameField { x: position.x + 4, y: position.y + 3, id: id }));

            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        x: position.x + 4,
                        y: position.y + 2,
                        color: Option::Some(
                            0xFF00FF80
                        ), //should I pass in a color to define the minesweepers field color?
                        timestamp: Option::None,
                        text: Option::Some('U+21E6'),
                        app: Option::Some(system),
                        owner: Option::Some(player),
                        action: Option::Some('move_left'),
                    }
                );
            set!(world, (NumberGameField { x: position.x + 4, y: position.y, id: id }));

            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        x: position.x + 4,
                        y: position.y + 3,
                        color: Option::Some(
                            0xFF00FF80
                        ), //should I pass in a color to define the minesweepers field color?
                        timestamp: Option::None,
                        text: Option::Some('U+21E8'),
                        app: Option::Some(system),
                        owner: Option::Some(player),
                        action: Option::Some('move_right'),
                    }
                );
            set!(world, (NumberGameField { x: position.x + 4, y: position.y + 1, id: id }));
            // let mut matrix = VecTrait::<Felt252Vec, u128>::new();
            let mut i: u32 = 0;
            let mut j: u32 = 0;
            loop {
                if i >= size {
                    break;
                }

                j = 0;
                loop {
                    if j >= size {
                        break;
                    }
                    // let mut t: u32 = 0;

                    // if i == 1{
                    //     if j == 3 || j==2{
                    //         t = 25;
                    //     };
                    // };
                    core_actions
                        .update_pixel(
                            player,
                            system,
                            PixelUpdate {
                                x: position.x + j,
                                y: position.y + i,
                                color: Option::Some(0xFFFFFFFF),
                                timestamp: Option::None,
                                text: Option::None,
                                app: Option::Some(system),
                                owner: Option::Some(player),
                                action: Option::Some('game_board'),
                            }
                        );
                    set!(world, (NumberGameField { x: position.x + j, y: position.y + i, id: id }));
                    set!(world, (NumberValue { x: position.x + j, y: position.y + i, value: 0 }));
                    j += 1;
                };
                i += 1;
            };
        }

        // random
        fn gen_random(ref world: IWorldDispatcher, default_params: DefaultParameters) {
            let core_actions = get_core_actions(world);
            let position = default_params.position;
            let mut field = get!(world, (position.x, position.y), NumberGameField);
            // let position = default_params.position;
            let player = core_actions.get_player_address(default_params.for_player);
            let system = core_actions.get_system_address(default_params.for_system);
            let mut game = get!(world, (field.id), NumberGame);
            let origin_position = Position { x: game.x, y: game.y };

            let mut zero_index: Array<u32> = ArrayTrait::new();
            let timestamp = starknet::get_block_timestamp();

            let mut random: u32 = 0;
            let mut i: u32 = 0;
            let mut j: u32 = 0;
            loop {
                if i >= size {
                    break;
                }
                j = 0;
                loop {
                    if j >= size {
                        break;
                    }
                    // let mut pixel = get!(world, (origin_position.x+j, origin_position.y+i),
                    // (Pixel));
                    let mut nv = get!(
                        world, (origin_position.x + j, origin_position.y + i), NumberValue
                    );
                    if nv.value == '' {
                        zero_index.append(i * 4 + j);
                    }
                    j += 1;
                };
                i += 1;
            };

            let zero_index_len = zero_index.len();
            // !!
            // if zero_index_len == 0{
            // }
            let mut gen_num: u32 = 0;

            random = (timestamp.try_into().unwrap() + position.x + position.y);
            let random_zero_index_len: u32 = random % zero_index_len;
            let random_size = random % (size * size);
            if zero_index_len >= 14 || random_size > 5 {
                gen_num = 2;
            } else {
                gen_num = 4;
            }
            set!(
                world,
                (NumberValue {
                    x: origin_position.x + (*zero_index.at(random_zero_index_len) % 4),
                    y: origin_position.y + (*zero_index.at(random_zero_index_len) / 4),
                    value: gen_num
                })
            );
            core_actions
                .update_pixel(
                    player,
                    system,
                    PixelUpdate {
                        x: origin_position.x + (*zero_index.at(random_zero_index_len) % 4),
                        y: origin_position.y + (*zero_index.at(random_zero_index_len) / 4),
                        color: Option::Some(get_color(gen_num)),
                        timestamp: Option::None,
                        text: Option::Some(to_short_string(gen_num)),
                        app: Option::Some(system),
                        owner: Option::Some(player),
                        action: Option::Some('game_borad'),
                    }
                );
        }

        fn move_right(ref world: IWorldDispatcher, default_params: DefaultParameters) {
            let core_actions = get_core_actions(world);
            let position = default_params.position;
            let mut field = get!(world, (position.x, position.y), NumberGameField);
            // let position = default_params.position;
            let player = core_actions.get_player_address(default_params.for_player);
            let system = core_actions.get_system_address(default_params.for_system);
            let mut game = get!(world, (field.id), NumberGame);
            let origin_position = Position { x: game.x, y: game.y };

            let timestamp = starknet::get_block_timestamp();

            let mut is_change: bool = false;
            let pixel = get!(world, (position.x, position.y), Pixel);
            let mut random: u32 = 0;
            let mut i: u32 = 0;
            let mut j: u32 = 0;
            let mut matrix = VecTrait::<Felt252Vec, u32>::new();
            loop {
                if i >= size {
                    break;
                }
                j = 0;
                loop {
                    if j >= size {
                        break;
                    }
                    let n = 0;
                    // let pixel = get!(world, (position.x, position.y), Pixel);
                    // let pixel = get!(world, (origin_position.x+j, origin_position.y+i), (Pixel));
                    // matrix.push(pixel.text.try_into().unwrap());

                    let mut nv = get!(
                        world, (origin_position.x + j, origin_position.y + i), NumberValue
                    );
                    matrix.push(nv.value);
                    j += 1;
                };
                i += 1;
            };

            i = 0;
            let mut k = 0;
            loop {
                if i >= 4 {
                    break;
                }
                let mut p_index = i * 4 + 2;
                j = 0;

                loop {
                    if j >= 3 {
                        break;
                    }
                    let mut index = i * 4 + 3 - j;
                    //d
                    if matrix.at(index) != 0 {
                        loop {
                            if j < 2 && matrix.at(p_index - j) == 0 {
                                j += 1;
                            } else {
                                break;
                            }
                        };
                        //
                        if matrix.at(p_index - j) == matrix.at(index) {
                            //ischange
                            if !is_change {
                                is_change = true;
                            }
                            let value = matrix.at(index);
                            matrix.set(index, value * 2);
                            matrix.set(p_index - j, 0);
                            // score
                        }
                    }
                    j += 1;
                };

                k = 0;
                loop {
                    if k >= 3 {
                        break;
                    }
                    let mut zero_index = i * 4 + 3 - k;
                    let mut new_k = k;
                    if matrix.at(zero_index) == 0 {
                        loop {
                            if new_k < 2 && matrix.at(p_index - new_k) == 0 {
                                new_k += 1;
                            } else {
                                break;
                            }
                        };
                        if matrix.at(p_index - new_k) != 0 {
                            // change
                            if !is_change {
                                is_change = true;
                            }
                            let value = matrix.at(p_index - new_k);
                            matrix.set(zero_index, value);
                            matrix.set(p_index - new_k, 0);
                        }
                    }
                    k += 1;
                };
                i += 1;
            };
            i = 0;
            let mut matrix_num: u32 = 0;
            loop {
                if i >= 16 {
                    break;
                }
                matrix_num = matrix.at(i);
                set!(
                    world,
                    (NumberValue {
                        x: origin_position.x + i % 4,
                        y: origin_position.y + i / 4,
                        value: matrix_num
                    })
                );
                core_actions
                    .update_pixel(
                        player,
                        system,
                        PixelUpdate {
                            x: origin_position.x + i % 4,
                            y: origin_position.y + i / 4,
                            color: Option::Some(
                                get_color(matrix_num)
                            ), //should I pass in a color to define the minesweepers field color?
                            timestamp: Option::None,
                            // text: Option::Some(matrix.at(i).into()),
                            text: Option::Some(to_short_string(matrix_num)),
                            app: Option::Some(system),
                            owner: Option::Some(player),
                            action: Option::None,
                        }
                    );
                i += 1;
            };
            if is_change {
                self.gen_random(default_params);
            }
        }

        fn move_left(ref world: IWorldDispatcher, default_params: DefaultParameters) {
            let core_actions = get_core_actions(world);
            let position = default_params.position;
            let mut field = get!(world, (position.x, position.y), NumberGameField);
            // let position = default_params.position;
            let player = core_actions.get_player_address(default_params.for_player);
            let system = core_actions.get_system_address(default_params.for_system);
            let mut game = get!(world, (field.id), NumberGame);
            let origin_position = Position { x: game.x, y: game.y };

            let timestamp = starknet::get_block_timestamp();

            let mut is_change: bool = false;
            let pixel = get!(world, (position.x, position.y), Pixel);
            let mut random: u32 = 0;
            let mut i: u32 = 0;
            let mut j: u32 = 0;
            let mut matrix = VecTrait::<Felt252Vec, u32>::new();
            loop {
                if i >= size {
                    break;
                }
                j = 0;
                loop {
                    if j >= size {
                        break;
                    }
                    let n = 0;
                    // let pixel = get!(world, (position.x, position.y), Pixel);
                    // let pixel = get!(world, (origin_position.x+j, origin_position.y+i), (Pixel));
                    // matrix.push(pixel.text.try_into().unwrap());

                    let mut nv = get!(
                        world, (origin_position.x + j, origin_position.y + i), NumberValue
                    );
                    matrix.push(nv.value);
                    j += 1;
                };
                i += 1;
            };
            i = 0;
            let mut k = 0;
            loop {
                if i >= 4 {
                    break;
                }
                j = 0;
                let mut p_index = i * 4 + 1;
                loop {
                    if j >= 3 {
                        break;
                    }
                    let mut index = i * 4 + j;

                    if matrix.at(index) != 0 {
                        loop {
                            if j < 2 && matrix.at(p_index + j) == 0 {
                                j += 1;
                            } else {
                                break;
                            }
                        };
                        if matrix.at(p_index + j) == matrix.at(index) {
                            //change
                            if !is_change {
                                is_change = true;
                            }
                            let value = matrix.at(index);
                            matrix.set(index, value * 2);
                            matrix.set(p_index + j, 0);
                        };
                    }
                    j += 1;
                };

                k = 0;
                loop {
                    if k >= 3 {
                        break;
                    }
                    let mut zero_index = i * 4 + k;
                    let mut new_k = k;
                    if matrix.at(zero_index) == 0 {
                        loop {
                            if new_k < 2 && matrix.at(p_index + new_k) == 0 {
                                new_k += 1;
                            } else {
                                break;
                            }
                        };
                        if matrix.at(p_index + new_k) != 0 {
                            //change
                            if !is_change {
                                is_change = true;
                            }
                            let value = matrix.at(p_index + new_k);
                            matrix.set(zero_index, value);
                            matrix.set(p_index + new_k, 0);
                        }
                    }
                    k += 1;
                };
                i += 1;
            };
            i = 0;
            let mut matrix_num: u32 = 0;
            loop {
                if i >= 16 {
                    break;
                }
                matrix_num = matrix.at(i);
                set!(
                    world,
                    (NumberValue {
                        x: origin_position.x + i % 4,
                        y: origin_position.y + i / 4,
                        value: matrix_num
                    })
                );
                core_actions
                    .update_pixel(
                        player,
                        system,
                        PixelUpdate {
                            x: origin_position.x + i % 4,
                            y: origin_position.y + i / 4,
                            color: Option::Some(
                                get_color(matrix_num)
                            ), //should I pass in a color to define the minesweepers field color?
                            timestamp: Option::None,
                            // text: Option::Some(matrix.at(i).into()),
                            text: Option::Some(to_short_string(matrix_num)),
                            app: Option::Some(system),
                            owner: Option::Some(player),
                            action: Option::None,
                        }
                    );
                // matrix.at(i).print();
                i += 1;
            };
            if is_change {
                self.gen_random(default_params);
            }
        }

        fn move_up(ref world: IWorldDispatcher, default_params: DefaultParameters) {
            let core_actions = get_core_actions(world);
            let position = default_params.position;
            let mut field = get!(world, (position.x, position.y), NumberGameField);
            // let position = default_params.position;
            let player = core_actions.get_player_address(default_params.for_player);
            let system = core_actions.get_system_address(default_params.for_system);
            let mut game = get!(world, (field.id), NumberGame);
            let origin_position = Position { x: game.x, y: game.y };

            let timestamp = starknet::get_block_timestamp();
            let mut is_change: bool = false;
            let pixel = get!(world, (position.x, position.y), Pixel);
            let mut random: u32 = 0;
            let mut i: u32 = 0;
            let mut j: u32 = 0;
            let mut matrix = VecTrait::<Felt252Vec, u32>::new();
            loop {
                if i >= size {
                    break;
                }
                j = 0;
                loop {
                    if j >= size {
                        break;
                    }
                    let n = 0;
                    // let pixel = get!(world, (position.x, position.y), Pixel);
                    // let pixel = get!(world, (origin_position.x+j, origin_position.y+i), (Pixel));
                    // matrix.push(pixel.text.try_into().unwrap());
                    let mut nv = get!(
                        world, (origin_position.x + j, origin_position.y + i), NumberValue
                    );
                    matrix.push(nv.value);
                    j += 1;
                };
                i += 1;
            };

            i = 0;
            let mut k = 0;
            loop {
                if i >= 4 {
                    break;
                }
                j = 0;
                loop {
                    if j >= 3 {
                        break;
                    };
                    let mut index = j * 4 + i;
                    if matrix.at(index) != 0 {
                        loop {
                            if j < 2 && matrix.at((j + 1) * 4 + i) == 0 {
                                j += 1;
                            } else {
                                break;
                            }
                        };
                        if matrix.at(index) == matrix.at((j + 1) * 4 + i) {
                            if !is_change {
                                is_change = true;
                            }
                            let value = matrix.at(index);
                            matrix.set(index, value * 2);
                            matrix.set((j + 1) * 4 + i, 0);
                        }
                    }
                    j += 1;
                };
                k = 0;
                loop {
                    if k >= 3 {
                        break;
                    }
                    let mut zero_index = k * 4 + i;
                    let mut new_k = k;
                    if matrix.at(zero_index) == 0 {
                        loop {
                            if new_k < 2 && matrix.at((new_k + 1) * 4 + i) == 0 {
                                new_k += 1;
                            } else {
                                break;
                            }
                        };
                        if matrix.at((new_k + 1) * 4 + i) != 0 {
                            if !is_change {
                                is_change = true;
                            }
                            let value = matrix.at((new_k + 1) * 4 + i);
                            matrix.set(zero_index, value);
                            matrix.set((new_k + 1) * 4 + i, 0);
                        }
                    }
                    k += 1;
                };
                i += 1
            };
            i = 0;
            let mut matrix_num: u32 = 0;
            loop {
                if i >= 16 {
                    break;
                }
                matrix_num = matrix.at(i);
                set!(
                    world,
                    (NumberValue {
                        x: origin_position.x + i % 4,
                        y: origin_position.y + i / 4,
                        value: matrix_num
                    })
                );
                core_actions
                    .update_pixel(
                        player,
                        system,
                        PixelUpdate {
                            x: origin_position.x + i % 4,
                            y: origin_position.y + i / 4,
                            color: Option::Some(
                                get_color(matrix_num)
                            ), //should I pass in a color to define the minesweepers field color?
                            timestamp: Option::None,
                            // text: Option::Some(matrix.at(i).into()),
                            text: Option::Some(to_short_string(matrix_num)),
                            app: Option::Some(system),
                            owner: Option::Some(player),
                            action: Option::None,
                        }
                    );
                // matrix.at(i).print();
                i += 1;
            };
            if is_change {
                self.gen_random(default_params);
            }
        }

        fn move_down(ref world: IWorldDispatcher, default_params: DefaultParameters) {
            let core_actions = get_core_actions(world);
            let position = default_params.position;
            let mut field = get!(world, (position.x, position.y), NumberGameField);
            // let position = default_params.position;
            let player = core_actions.get_player_address(default_params.for_player);
            let system = core_actions.get_system_address(default_params.for_system);
            let mut game = get!(world, (field.id), NumberGame);
            let origin_position = Position { x: game.x, y: game.y };
            let timestamp = starknet::get_block_timestamp();

            let mut is_change: bool = false;
            let pixel = get!(world, (position.x, position.y), Pixel);
            let mut random: u32 = 0;
            let mut i: u32 = 0;
            let mut j: u32 = 0;
            let mut matrix = VecTrait::<Felt252Vec, u32>::new();
            loop {
                if i >= size {
                    break;
                }
                j = 0;
                loop {
                    if j >= size {
                        break;
                    }
                    let n = 0;
                    // let pixel = get!(world, (position.x, position.y), Pixel);
                    // let pixel = get!(world, (origin_position.x+j, origin_position.y+i), (Pixel));
                    // matrix.push(pixel.text.try_into().unwrap());
                    let mut nv = get!(
                        world, (origin_position.x + j, origin_position.y + i), NumberValue
                    );
                    matrix.push(nv.value);
                    j += 1;
                };
                i += 1;
            };

            i = 0;
            j = 3;
            let mut k = 0;
            loop {
                if i >= 4 {
                    break;
                }
                j = 3;
                loop {
                    if j <= 0 {
                        break;
                    }
                    let mut index = j * 4 + i;
                    if matrix.at(index) != 0 {
                        loop {
                            if j > 1 && matrix.at((j - 1) * 4 + i) == 0 {
                                j -= 1;
                            } else {
                                break;
                            }
                        };
                        if matrix.at(index) == matrix.at((j - 1) * 4 + i) {
                            if !is_change {
                                is_change = true;
                            }
                            let value = matrix.at(index);
                            matrix.set(index, value * 2);
                            matrix.set((j - 1) * 4 + i, 0);
                        }
                    }
                    j -= 1;
                };

                let mut k = 3;
                loop {
                    if k <= 0 {
                        break;
                    }
                    let mut zero_index = k * 4 + i;
                    let mut new_k = k;
                    if matrix.at(zero_index) == 0 {
                        loop {
                            if new_k > 1 && matrix.at((new_k - 1) * 4 + i) == 0 {
                                new_k -= 1;
                            } else {
                                break;
                            }
                        };
                        if matrix.at((new_k - 1) * 4 + i) != 0 {
                            if !is_change {
                                is_change = true;
                            }
                            let value = matrix.at((new_k - 1) * 4 + i);
                            matrix.set(zero_index, value);
                            matrix.set((new_k - 1) * 4 + i, 0);
                        }
                    }
                    k -= 1;
                };
                i += 1;
            };
            i = 0;
            let mut matrix_num: u32 = 0;
            loop {
                if i >= 16 {
                    break;
                }
                matrix_num = matrix.at(i);
                set!(
                    world,
                    (NumberValue {
                        x: origin_position.x + i % 4,
                        y: origin_position.y + i / 4,
                        value: matrix_num
                    })
                );
                core_actions
                    .update_pixel(
                        player,
                        system,
                        PixelUpdate {
                            x: origin_position.x + i % 4,
                            y: origin_position.y + i / 4,
                            color: Option::Some(
                                get_color(matrix_num)
                            ), //should I pass in a color to define the minesweepers field color?
                            timestamp: Option::None,
                            // text: Option::Some(matrix.at(i).into()),
                            text: Option::Some(to_short_string(matrix_num)),
                            app: Option::Some(system),
                            owner: Option::Some(player),
                            action: Option::None,
                        }
                    );
                // matrix.at(i).print();
                i += 1;
            };
            if is_change {
                self.gen_random(default_params);
            }
        }

        fn ownerless_space(ref world: IWorldDispatcher, default_params: DefaultParameters) -> bool {
            let core_actions = get_core_actions(world);
            let position = default_params.position;
            let mut pixel = get!(world, (position.x, position.y), (Pixel));

            let mut i: u32 = 0;
            let mut j: u32 = 0;
            // let mut check_test: bool = true;

            let check = loop {
                if i >= size {
                    break true;
                }
                j = 0;
                loop {
                    if j > size {
                        break;
                    }
                    pixel = get!(world, (position.x + j, (position.y + i)), (Pixel));
                    if !(pixel.owner.is_zero()) {
                        i = 5;
                        break;
                    }
                    j += 1;
                };
                if i == 5 {
                    break false;
                };
                i += 1;
            };

            check
        }

        fn is_game_over(ref world: IWorldDispatcher, default_params: DefaultParameters) -> bool {
            let core_actions = get_core_actions(world);
            let position = default_params.position;
            let mut field = get!(world, (position.x, position.y), NumberGameField);
            // let position = default_params.position;
            let player = core_actions.get_player_address(default_params.for_player);
            let system = core_actions.get_system_address(default_params.for_system);
            let mut game = get!(world, (field.id), NumberGame);
            let origin_position = Position { x: game.x, y: game.y };
            let mut matrix: Array<u32> = ArrayTrait::new();
            let timestamp = starknet::get_block_timestamp();

            let mut random: u32 = 0;
            let mut i: u32 = 0;
            let mut j: u32 = 0;
            let mut matrix = VecTrait::<Felt252Vec, u128>::new();
            loop {
                if i >= size {
                    break;
                }
                j = 0;
                loop {
                    if j >= size {
                        break;
                    }
                    let n = 0;
                    // let pixel = get!(world, (position.x, position.y), Pixel);
                    let pixel = get!(
                        world, (origin_position.x + j, origin_position.y + i), (Pixel)
                    );
                    matrix.push(pixel.text.try_into().unwrap());
                    j += 1;
                };
                i += 1;
            };

            i = 0;
            j = 0;
            let mut is_over: bool = true;

            loop {
                if i >= 4 {
                    break;
                }
                let mut row_p_index = i * 4 + 1;
                j = 0;
                loop {
                    if j >= 3 {
                        break;
                    }
                    let row_index = i * 4 + j;
                    let col_p_index = (j + 1) * 4 + i;
                    let col_index = j * 4 + i;
                    //false
                    if matrix.at(row_index) == '' || matrix.at(col_index) == '' {
                        is_over = false;
                        i = 4;
                        break;
                    };
                    if matrix.at(row_index) == matrix.at(row_p_index + j)
                        || matrix.at(col_index) == matrix.at(col_p_index) {
                        is_over = false;
                        i = 4;
                        break;
                    }
                    j += 1;
                };
                i += 1;
            };
            is_over
        }
    }
    fn get_digits(number: u32) -> u32 {
        let mut digits: u32 = 0;
        let mut current_number: u32 = number;
        loop {
            current_number /= 10;
            digits += 1;
            if current_number == 0 {
                break;
            }
        };
        digits
    }

    fn get_power(base: u32, power: u32) -> u32 {
        let mut i: u32 = 0;
        let mut result: u32 = 1;
        loop {
            if i >= power {
                break;
            }
            result *= base;
            i += 1;
        };
        result
    }

    fn to_short_string(number: u32) -> felt252 {
        let mut result: u32 = 0;
        if number != 0 {
            let mut digits = get_digits(number);
            loop {
                if digits == 0 {
                    break;
                }
                let mut current_digit = number / get_power(10, digits - 1);
                // current digit % 10
                current_digit = (current_digit - 10 * (current_digit / 10));
                let ascii_representation = current_digit + 48;
                result += ascii_representation * get_power(256, digits - 1);
                digits -= 1;
            };
        }

        result.into()
    }

    fn get_color(number: u32) -> u32 {
        if number == 2 {
            0xFFEEE4DA
        } else if number == 4 {
            0xFFECE0CA
        } else if number == 8 {
            0xFFEFB883
        } else if number == 16 {
            0xFFF57C5F
        } else if number == 32 {
            0xFFEA4C3C
        } else if number == 64 {
            0xFFD83A2B
        } else if number == 128 {
            0xFFF9D976
        } else if number == 256 {
            0xFFBE67FF
        } else if number == 512 {
            0xFF7D6CFF
        } else if number == 1024 {
            0xFF26A69A
        } else if number == 2048 {
            0xFFFFE74C
        } else if number == 4096 {
            0xFFB19CD9
        } else if number == 8192 {
            0xFF85C1E9
        } else if number == 16384 {
            0xFF76D7C4
        } else if number == 32768 {
            0xFFF9A825
        } else if number == 65536 {
            0xFFFF8F00
        } else {
            0xFFFFFFFF
        }
    }
}
