use anchor_lang::prelude::*;

pub mod errors;
pub mod state;

use state::*;

declare_id!("5SDiX5L1K9m4vSMVhE13nfk5GEgRnHbm57b5rNPWMVj9");

#[program]
pub mod signer_vault {
    use super::*;

    pub fn deposit(ctx: Context<Deposit>, amount: u64) -> Result<()> {
        let vault = &mut ctx.accounts.vault;
        vault.owner = ctx.accounts.owner.key();
        vault.balance = vault.balance.checked_add(amount).unwrap();
        Ok(())
    }

    pub fn delegate_withdraw(ctx: Context<DelegateWithdraw>, amount: u64) -> Result<()> {
        let vault = &mut ctx.accounts.vault;
        require_keys_eq!(vault.owner, ctx.accounts.owner.key(), errors::ErrorCode::WrongOwner);
        require!(vault.balance >= amount, errors::ErrorCode::InsufficientBalance);
        vault.balance -= amount;
        **vault.to_account_info().try_borrow_mut_lamports()? -= amount;
        **ctx.accounts.destination.try_borrow_mut_lamports()? += amount;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Deposit<'info> {
    #[account(init_if_needed, payer = owner, space = 8 + Vault::LEN)]
    pub vault: Account<'info, Vault>,
    #[account(mut)]
    pub owner: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct DelegateWithdraw<'info> {
    #[account(mut)]
    pub vault: Account<'info, Vault>,
    /// CHECK: compared to vault.owner but not required to sign
    pub owner: AccountInfo<'info>,
    /// CHECK: receives lamports
    #[account(mut)]
    pub destination: AccountInfo<'info>,
}
