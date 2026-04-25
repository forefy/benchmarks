use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer};

pub mod errors;
pub mod state;

use state::*;

declare_id!("9gw4aWDrWv4vxhefYQC7iATGZrhUxYHC216KqEHp6wM");

#[program]
pub mod safe_rewards {
    use super::*;

    pub fn claim(ctx: Context<Claim>) -> Result<()> {
        let amount = ctx.accounts.claim_state.pending;
        require!(amount > 0, errors::ErrorCode::NothingToClaim);
        ctx.accounts.claim_state.pending = 0;

        let mint_key = ctx.accounts.mint.key();
        let seeds: &[&[u8]] = &[b"reward_authority", mint_key.as_ref(), &[ctx.accounts.reward_authority.bump]];
        let signer = &[seeds];
        let cpi_accounts = Transfer {
            from: ctx.accounts.reward_vault.to_account_info(),
            to: ctx.accounts.user_reward_token.to_account_info(),
            authority: ctx.accounts.reward_authority.to_account_info(),
        };
        token::transfer(
            CpiContext::new_with_signer(ctx.accounts.token_program.to_account_info(), cpi_accounts, signer),
            amount,
        )?;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Claim<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    pub mint: Account<'info, Mint>,
    #[account(mut, seeds = [b"claim", user.key().as_ref(), mint.key().as_ref()], bump, has_one = user)]
    pub claim_state: Account<'info, ClaimState>,
    #[account(seeds = [b"reward_authority", mint.key().as_ref()], bump = reward_authority.bump)]
    pub reward_authority: Account<'info, RewardAuthority>,
    #[account(mut, constraint = reward_vault.owner == reward_authority.key(), constraint = reward_vault.mint == mint.key())]
    pub reward_vault: Account<'info, TokenAccount>,
    #[account(mut, constraint = user_reward_token.owner == user.key(), constraint = user_reward_token.mint == mint.key())]
    pub user_reward_token: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
}
