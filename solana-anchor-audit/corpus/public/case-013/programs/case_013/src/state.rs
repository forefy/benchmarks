use anchor_lang::prelude::*;

#[account]
pub struct Vault {
    pub bump: u8,
}

#[account]
pub struct Receipt {
    pub amount: u64,
}

impl Receipt {
    pub const LEN: usize = 8;
}
