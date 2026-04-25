use anchor_lang::prelude::*;

#[account]
pub struct Receipt {
    pub owner: Pubkey,
    pub deposited: u64,
}

impl Receipt {
    pub const LEN: usize = 32 + 8;
}
