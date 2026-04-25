use anchor_lang::prelude::*;

#[account]
pub struct StakeAccount {
    pub owner: Pubkey,
    pub last_slot: u64,
    pub reward_rate_per_slot: u64,
    pub pending_rewards: u64,
}
