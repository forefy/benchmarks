use anchor_lang::prelude::*;

pub mod errors;
pub mod state;

use state::*;

declare_id!("APzoQoppD38FonB48EYbqyxpdXrayUaZPSfcb42i6Tbu");

#[program]
pub mod close_position {
    use super::*;

    pub fn close_position(ctx: Context<ClosePosition>) -> Result<()> {
        require!(ctx.accounts.position.size == 0, errors::ErrorCode::PositionOpen);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct ClosePosition<'info> {
    #[account(mut, close = receiver)]
    pub position: Account<'info, Position>,
    /// CHECK: arbitrary rent receiver
    #[account(mut)]
    pub receiver: AccountInfo<'info>,
    pub owner: Signer<'info>,
}
