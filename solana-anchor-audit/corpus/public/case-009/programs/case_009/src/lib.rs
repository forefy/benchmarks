use anchor_lang::prelude::*;

pub mod errors;
pub mod state;

use state::*;

declare_id!("LaWkQdqx4dZyNWPTTNwhFx8vsC1koYcdqGizdAtJgK7");

#[program]
pub mod remaining_rewards {
    use super::*;

    pub fn sweep_remaining_rewards(ctx: Context<SweepRemainingRewards>) -> Result<()> {
        for account in ctx.remaining_accounts.iter() {
            if account.is_writable {
                let mut data = account.try_borrow_mut_data()?;
                if data.len() >= 8 {
                    data[0..8].copy_from_slice(&0u64.to_le_bytes());
                }
            }
        }
        ctx.accounts.pool.last_sweep_slot = Clock::get()?.slot;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct SweepRemainingRewards<'info> {
    #[account(mut, has_one = authority)]
    pub pool: Account<'info, RewardPool>,
    pub authority: Signer<'info>,
}
