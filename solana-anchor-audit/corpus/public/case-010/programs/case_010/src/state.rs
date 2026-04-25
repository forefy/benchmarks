use anchor_lang::prelude::*;

#[account]
pub struct Position {
    pub owner: Pubkey,
    pub debt: u64,
}

#[account]
pub struct Collateral {
    pub owner: Pubkey,
    pub amount: u64,
}

#[account]
pub struct PriceOracle {
    pub price: u64,
    pub last_update_slot: u64,
}
