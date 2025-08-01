// Simplified TicTacToe AI without complex ML dependencies
use core::array::ArrayTrait;

const MOVE_PLAYER: u8 = 1;    // Human player (X)
const MOVE_AI: u8 = 2;        // AI player (O)  
const MOVE_EMPTY: u8 = 0;     // Empty cell

// Simplified AI that uses basic strategy instead of ML
pub fn move_selector(current_board_state: Array<u8>) -> Option<u32> {
    // Strategy priority:
    // 1. Win if possible
    // 2. Block opponent win
    // 3. Take center if available
    // 4. Take corner if available
    // 5. Take any available spot

    // Check for winning move
    if let Option::Some(winning_move) = find_winning_move(@current_board_state, MOVE_AI) {
        return Option::Some(winning_move);
    }

    // Check for blocking move
    if let Option::Some(blocking_move) = find_winning_move(@current_board_state, MOVE_PLAYER) {
        return Option::Some(blocking_move);
    }

    // Take center if available
    if *current_board_state.at(4) == MOVE_EMPTY {
        return Option::Some(4);
    }

    // Take corners in order of preference
    let corners = array![0, 2, 6, 8];
    let mut i = 0;
    let mut corner_move = Option::None;
    while i < corners.len() {
        let corner = *corners.at(i);
        if *current_board_state.at(corner) == MOVE_EMPTY {
            corner_move = Option::Some(corner);
            break;
        }
        i += 1;
    };
    
    if corner_move.is_some() {
        return corner_move;
    }

    // Take any available edge
    let edges = array![1, 3, 5, 7];
    let mut i = 0;
    let mut edge_move = Option::None;
    while i < edges.len() {
        let edge = *edges.at(i);
        if *current_board_state.at(edge) == MOVE_EMPTY {
            edge_move = Option::Some(edge);
            break;
        }
        i += 1;
    };
    
    if edge_move.is_some() {
        return edge_move;
    }

    // Fallback: take first available spot
    let mut i = 0;
    let mut fallback_move = Option::None;
    while i < 9 {
        if *current_board_state.at(i) == MOVE_EMPTY {
            fallback_move = Option::Some(i);
            break;
        }
        i += 1;
    };

    fallback_move
}

// Helper function to find winning moves
fn find_winning_move(board: @Array<u8>, player: u8) -> Option<u32> {
    // Check all winning combinations
    let winning_combinations = array![
        array![0, 1, 2], // Top row
        array![3, 4, 5], // Middle row
        array![6, 7, 8], // Bottom row
        array![0, 3, 6], // Left column
        array![1, 4, 7], // Middle column
        array![2, 5, 8], // Right column
        array![0, 4, 8], // Main diagonal
        array![2, 4, 6], // Anti-diagonal
    ];

    let mut combo_idx = 0;
    let mut winning_move = Option::None;
    while combo_idx < winning_combinations.len() {
        let combo = winning_combinations.at(combo_idx);
        let pos1 = *combo.at(0);
        let pos2 = *combo.at(1);
        let pos3 = *combo.at(2);

        // Check if we can win by playing in this combination
        if can_win_with_combination(board, player, pos1, pos2, pos3) {
            // Find the empty position
            if *board.at(pos1) == MOVE_EMPTY {
                winning_move = Option::Some(pos1);
                break;
            } else if *board.at(pos2) == MOVE_EMPTY {
                winning_move = Option::Some(pos2);
                break;
            } else if *board.at(pos3) == MOVE_EMPTY {
                winning_move = Option::Some(pos3);
                break;
            }
        }
        combo_idx += 1;
    };

    winning_move
}

// Check if a player can win by playing in a specific combination
fn can_win_with_combination(board: @Array<u8>, player: u8, pos1: u32, pos2: u32, pos3: u32) -> bool {
    let val1 = *board.at(pos1);
    let val2 = *board.at(pos2);
    let val3 = *board.at(pos3);

    // Count player pieces and empty spots in this combination
    let mut player_count = 0;
    let mut empty_count = 0;

    if val1 == player {
        player_count += 1;
    } else if val1 == MOVE_EMPTY {
        empty_count += 1;
    }

    if val2 == player {
        player_count += 1;
    } else if val2 == MOVE_EMPTY {
        empty_count += 1;
    }

    if val3 == player {
        player_count += 1;
    } else if val3 == MOVE_EMPTY {
        empty_count += 1;
    }

    // Can win if we have 2 pieces and 1 empty spot
    player_count == 2 && empty_count == 1
}

#[cfg(test)]
mod tests {
    use super::{move_selector, MOVE_PLAYER, MOVE_AI, MOVE_EMPTY};

    #[test]
    #[available_gas(2000000000)]
    fn test_winning_move() {
        // AI can win by playing at position 2
        // X | O | _
        // X | O | _  
        // _ | _ | _
        let state = array![
            MOVE_PLAYER, MOVE_AI, MOVE_EMPTY,
            MOVE_PLAYER, MOVE_AI, MOVE_EMPTY,
            MOVE_EMPTY, MOVE_EMPTY, MOVE_EMPTY,
        ];

        let ai_move = move_selector(state).unwrap();
        assert(ai_move == 7, 'AI should win at position 7');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_blocking_move() {
        // AI should block player from winning
        // X | X | _
        // O | _ | _
        // _ | _ | _
        let state = array![
            MOVE_PLAYER, MOVE_PLAYER, MOVE_EMPTY,
            MOVE_AI, MOVE_EMPTY, MOVE_EMPTY,
            MOVE_EMPTY, MOVE_EMPTY, MOVE_EMPTY,
        ];

        let ai_move = move_selector(state).unwrap();
        assert(ai_move == 2, 'AI should block at position 2');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_center_preference() {
        // AI should prefer center when no immediate threats
        // X | _ | _
        // _ | _ | _
        // _ | _ | _
        let state = array![
            MOVE_PLAYER, MOVE_EMPTY, MOVE_EMPTY,
            MOVE_EMPTY, MOVE_EMPTY, MOVE_EMPTY,
            MOVE_EMPTY, MOVE_EMPTY, MOVE_EMPTY,
        ];

        let ai_move = move_selector(state).unwrap();
        assert(ai_move == 4, 'AI should take center');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_corner_preference() {
        // AI should prefer corners when center is taken
        // _ | _ | _
        // _ | X | _
        // _ | _ | _
        let state = array![
            MOVE_EMPTY, MOVE_EMPTY, MOVE_EMPTY,
            MOVE_EMPTY, MOVE_PLAYER, MOVE_EMPTY,
            MOVE_EMPTY, MOVE_EMPTY, MOVE_EMPTY,
        ];

        let ai_move = move_selector(state).unwrap();
        // Should be one of the corners: 0, 2, 6, 8
        assert(
            ai_move == 0 || ai_move == 2 || ai_move == 6 || ai_move == 8,
            'AI should take a corner'
        );
    }
}