use anchor_lang::prelude::*;

#[account]
pub struct Config {
    pub authority: Pubkey,
    pub fee_bps: u16,
}

impl Config {
    pub const LEN: usize = 32 + 2;
}
