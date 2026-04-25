use anchor_lang::prelude::*;

#[account]
pub struct RewardPool {
    pub authority: Pubkey,
    pub last_sweep_slot: u64,
}
