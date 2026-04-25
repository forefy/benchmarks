use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

pub mod errors;
pub mod state;

use state::*;

declare_id!("5KKDiDfgCM6njjPuATXnJSJRVrg2Dyx2u9PEZbCwfi6S");

#[program]
pub mod unchecked_vault_authority {
    use super::*;

    pub fn withdraw(ctx: Context<Withdraw>, amount: u64) -> Result<()> {
        require!(ctx.accounts.position.amount >= amount, errors::ErrorCode::InsufficientBalance);
        ctx.accounts.position.amount -= amount;

        let cpi_accounts = Transfer {
            from: ctx.accounts.vault_token.to_account_info(),
            to: ctx.accounts.user_token.to_account_info(),
            authority: ctx.accounts.vault_authority.to_account_info(),
        };
        token::transfer(
            CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts),
            amount,
        )?;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Withdraw<'info> {
    #[account(mut, has_one = owner)]
    pub position: Account<'info, Position>,
    pub owner: Signer<'info>,
    #[account(mut)]
    pub vault_token: Account<'info, TokenAccount>,
    #[account(mut)]
    pub user_token: Account<'info, TokenAccount>,
    /// CHECK: should be the vault PDA but no seeds are enforced
    pub vault_authority: Signer<'info>,
    pub token_program: Program<'info, Token>,
}
