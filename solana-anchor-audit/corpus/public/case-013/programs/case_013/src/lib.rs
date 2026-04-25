use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer};

pub mod errors;
pub mod state;

use state::*;

declare_id!("F7jfkDB7YdsxS6SxqM7NzhysmVmCsAivNCLSNKXEV5vN");

#[program]
pub mod safe_vault {
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
        ctx.accounts.receipt.amount = ctx.accounts.receipt.amount.checked_add(amount).unwrap();
        Ok(())
    }

    pub fn withdraw(ctx: Context<Withdraw>, amount: u64) -> Result<()> {
        require!(ctx.accounts.receipt.amount >= amount, errors::ErrorCode::InsufficientBalance);
        ctx.accounts.receipt.amount -= amount;
        let mint_key = ctx.accounts.mint.key();
        let seeds: &[&[u8]] = &[b"vault", mint_key.as_ref(), &[ctx.accounts.vault.bump]];
        let signer = &[seeds];
        let cpi_accounts = Transfer {
            from: ctx.accounts.vault_token.to_account_info(),
            to: ctx.accounts.user_token.to_account_info(),
            authority: ctx.accounts.vault.to_account_info(),
        };
        token::transfer(
            CpiContext::new_with_signer(ctx.accounts.token_program.to_account_info(), cpi_accounts, signer),
            amount,
        )?;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Deposit<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    pub mint: Account<'info, Mint>,
    #[account(mut, constraint = user_token.owner == user.key(), constraint = user_token.mint == mint.key())]
    pub user_token: Account<'info, TokenAccount>,
    #[account(seeds = [b"vault", mint.key().as_ref()], bump = vault.bump)]
    pub vault: Account<'info, Vault>,
    #[account(mut, constraint = vault_token.owner == vault.key(), constraint = vault_token.mint == mint.key())]
    pub vault_token: Account<'info, TokenAccount>,
    #[account(init_if_needed, payer = user, space = 8 + Receipt::LEN, seeds = [b"receipt", user.key().as_ref(), mint.key().as_ref()], bump)]
    pub receipt: Account<'info, Receipt>,
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Withdraw<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    pub mint: Account<'info, Mint>,
    #[account(mut, constraint = user_token.owner == user.key(), constraint = user_token.mint == mint.key())]
    pub user_token: Account<'info, TokenAccount>,
    #[account(seeds = [b"vault", mint.key().as_ref()], bump = vault.bump)]
    pub vault: Account<'info, Vault>,
    #[account(mut, constraint = vault_token.owner == vault.key(), constraint = vault_token.mint == mint.key())]
    pub vault_token: Account<'info, TokenAccount>,
    #[account(mut, seeds = [b"receipt", user.key().as_ref(), mint.key().as_ref()], bump)]
    pub receipt: Account<'info, Receipt>,
    pub token_program: Program<'info, Token>,
}
