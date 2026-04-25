use anchor_lang::prelude::*;

pub mod errors;
pub mod state;

use state::*;

declare_id!("5TZimxwZJDLGrvaAGeFVChyXHkpHR4VFcwfytYV2Tt9u");

#[program]
pub mod pool_reinit {
    use super::*;

    pub fn initialize_pool(ctx: Context<InitializePool>, mint: Pubkey) -> Result<()> {
        let pool = &mut ctx.accounts.pool;
        pool.authority = ctx.accounts.authority.key();
        pool.mint = mint;
        pool.bump = ctx.bumps.pool;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct InitializePool<'info> {
    #[account(
        init_if_needed,
        payer = authority,
        space = 8 + Pool::LEN,
        seeds = [b"pool"],
        bump
    )]
    pub pool: Account<'info, Pool>,
    #[account(mut)]
    pub authority: Signer<'info>,
    pub system_program: Program<'info, System>,
}
