use starknet::{ContractAddress};
use pixelaw::core::utils::{Position};

/// Chest Model to keep track of chests and their types
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Chest {
    #[key]
    position: Position, // Position of the chest
    pub placed_by: ContractAddress, // Who placed the chest
    pub is_collected: bool, // Whether the chest has been collected
    pub lives_reward: u8, // Number of lives to reward
}
