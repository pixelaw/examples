use starknet::{ContractAddress};

#[derive(Serde, Copy, Drop, PartialEq, Introspect)]
pub enum State {
    None: (),
    Open: (),
    Finished: ()
}

#[derive(Copy, Drop, Serde)]
#[dojo::model(namespace: "pixelaw", nomapping: true)]
pub struct NumberGame {
    #[key]
    id: u32,
    player: ContractAddress,
    started_time: u64,
    state: State,
    x: u32,
    y: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model(namespace: "pixelaw", nomapping: true)]
pub struct NumberGameField {
    #[key]
    x: u32,
    #[key]
    y: u32,
    id: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model(namespace: "pixelaw", nomapping: true)]
pub struct NumberValue {
    #[key]
    x: u32,
    #[key]
    y: u32,
    value: u32,
}
