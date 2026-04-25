use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

pub mod errors;
pub mod state;

use state::*;

declare_id!("Gb9sZugNPUffU92yibEKTc8CJFMfDiEnyPKAjpiJMkLd");

#[program]
pub mod loose_token_deposit {
    use super::*;

    pub fn deposit(ctx: Context<Deposit>, amount: u64) -> Result<()> {
        let cpi_accounts = Transfer {
            from: ctx.accounts.user_token.to_account_info(),
            to: ctx.accounts.vault_token.to_account_info(),
            authority: ctx.accounts.user.to_account_info(),
        };
        token::transfer(
            CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts),
            amount,
        )?;

        ctx.accounts.receipt.owner = ctx.accounts.user.key();
        ctx.accounts.receipt.deposited = ctx.accounts.receipt.deposited.checked_add(amount).unwrap();
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Deposit<'info> {
    #[account(init_if_needed, payer = user, space = 8 + Receipt::LEN)]
    pub receipt: Account<'info, Receipt>,
    #[account(mut)]
    pub user: Signer<'info>,
    #[account(mut)]
    pub user_token: Account<'info, TokenAccount>,
    #[account(mut)]
    pub vault_token: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}
