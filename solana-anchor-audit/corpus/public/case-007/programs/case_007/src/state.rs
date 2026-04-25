use anchor_lang::prelude::*;

#[account]
pub struct Pool {
    pub authority: Pubkey,
    pub mint: Pubkey,
    pub bump: u8,
}

impl Pool {
    pub const LEN: usize = 32 + 32 + 1;
}
