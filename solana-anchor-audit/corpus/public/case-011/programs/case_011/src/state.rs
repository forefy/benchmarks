use anchor_lang::prelude::*;

#[account]
pub struct Order {
    pub buyer: Pubkey,
    pub amount: u64,
    pub cancelled: bool,
}
