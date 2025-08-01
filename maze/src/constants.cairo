/// APP_KEY must be unique across the entire platform
pub const APP_KEY: felt252 = 'maze';

/// Core only supports unicode icons for now
pub const APP_ICON: felt252 = 'U+1F3F0';

/// Maze dimensions
pub const MAZE_SIZE: u32 = 5;

/// Maze cell types
pub const WALL: felt252 = 'wall';
pub const PATH: felt252 = 'path';
pub const CENTER: felt252 = 'center';
pub const TRAP: felt252 = 'trap';

/// Predefined maze layouts (5x5 grids)
/// 0 = path, 1 = wall, 2 = center reward, 3 = trap
pub const MAZE_1: [u8; 25] = [
    1, 1, 1, 1, 1, 1, 0, 3, 0, 1, 1, 0, 2, 0, 1, 1, 0, 3, 0, 1, 1, 1, 1, 1, 1,
];

pub const MAZE_2: [u8; 25] = [
    1, 1, 1, 1, 1, 1, 3, 1, 3, 1, 1, 0, 2, 0, 1, 1, 3, 1, 3, 1, 1, 1, 1, 1, 1,
];

pub const MAZE_3: [u8; 25] = [
    1, 1, 1, 1, 1, 1, 0, 3, 0, 1, 1, 1, 2, 1, 1, 1, 0, 3, 0, 1, 1, 1, 1, 1, 1,
];

pub const MAZE_4: [u8; 25] = [
    1, 3, 1, 3, 1, 3, 0, 1, 0, 3, 1, 1, 2, 1, 1, 3, 0, 1, 0, 3, 1, 3, 1, 3, 1,
];

pub const MAZE_5: [u8; 25] = [
    1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 1, 3, 2, 3, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 1,
];
