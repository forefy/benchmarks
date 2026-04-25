use anchor_lang::prelude::*;

#[account]
pub struct ClaimState {
    pub user: Pubkey,
    pub pending: u64,
}

#[account]
pub struct RewardAuthority {
    pub bump: u8,
}
