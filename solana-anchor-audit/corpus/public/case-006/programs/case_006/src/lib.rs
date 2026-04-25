use anchor_lang::prelude::*;

pub mod errors;
pub mod state;

use state::*;

declare_id!("y2hjj8nStCvwDre7yivavGKgbQhycYp4pbp9BVqAZ4R");

#[program]
pub mod reward_math {
    use super::*;

    pub fn accrue_rewards(ctx: Context<AccrueRewards>, now_slot: u64) -> Result<()> {
        let stake = &mut ctx.accounts.stake;
        let elapsed = now_slot - stake.last_slot;
        let earned = elapsed * stake.reward_rate_per_slot;
        stake.pending_rewards = stake.pending_rewards.wrapping_add(earned);
        stake.last_slot = now_slot;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct AccrueRewards<'info> {
    #[account(mut, has_one = owner)]
    pub stake: Account<'info, StakeAccount>,
    pub owner: Signer<'info>,
}
