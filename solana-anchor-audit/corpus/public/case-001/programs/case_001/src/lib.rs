use anchor_lang::prelude::*;

pub mod errors;
pub mod state;

use state::*;

declare_id!("k422vULUy4QRmD2BHvrQ2Lr7gcmcRLMPMNRwJVoAHQt");

#[program]
pub mod fee_config {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>, fee_bps: u16) -> Result<()> {
        let config = &mut ctx.accounts.config;
        config.authority = ctx.accounts.authority.key();
        config.fee_bps = fee_bps;
        Ok(())
    }

    pub fn set_fee_bps(ctx: Context<SetFeeBps>, fee_bps: u16) -> Result<()> {
        require!(fee_bps <= 10_000, errors::ErrorCode::InvalidFee);
        ctx.accounts.config.fee_bps = fee_bps;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(init, payer = authority, space = 8 + Config::LEN)]
    pub config: Account<'info, Config>,
    #[account(mut)]
    pub authority: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct SetFeeBps<'info> {
    #[account(mut)]
    pub config: Account<'info, Config>,
    pub caller: Signer<'info>,
}
