use anchor_lang::prelude::*;

#[account]
pub struct Profile {
    pub owner: Pubkey,
    pub username: String,
    pub domain: String,
}

impl Profile {
    pub const LEN: usize = 32 + 4 + 32 + 4 + 32;
}
