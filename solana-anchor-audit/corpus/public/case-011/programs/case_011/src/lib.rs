use anchor_lang::prelude::*;

pub mod errors;
pub mod state;

use state::*;

declare_id!("8fXbzV1QBWAbe4HYecn6CaLyopkvwSBmshb9T2rLYjjW");

#[program]
pub mod refund_order {
    use super::*;

    pub fn claim_refund(ctx: Context<ClaimRefund>) -> Result<()> {
        let amount = ctx.accounts.order.amount;
        require!(ctx.accounts.order.cancelled, errors::ErrorCode::NotCancelled);
        ctx.accounts.order.amount = 0;
        **ctx.accounts.escrow.to_account_info().try_borrow_mut_lamports()? -= amount;
        **ctx.accounts.recipient.try_borrow_mut_lamports()? += amount;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct ClaimRefund<'info> {
    #[account(mut, has_one = buyer)]
    pub order: Account<'info, Order>,
    pub buyer: Signer<'info>,
    /// CHECK: escrow lamports account
    #[account(mut)]
    pub escrow: AccountInfo<'info>,
    /// CHECK: arbitrary refund recipient
    #[account(mut)]
    pub recipient: AccountInfo<'info>,
}
