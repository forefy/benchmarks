use anchor_lang::prelude::*;
use anchor_lang::solana_program::{instruction::Instruction, program::invoke};

pub mod errors;
pub mod state;

declare_id!("Fi94R1ffAjHg7W3aPkN5Cfkq8YVVC9rp8zQ4fjqtKRfW");

#[program]
pub mod arbitrary_cpi_payment {
    use super::*;

    pub fn pay(ctx: Context<Pay>, amount: u64) -> Result<()> {
        let ix = Instruction {
            program_id: ctx.accounts.token_program.key(),
            accounts: vec![],
            data: amount.to_le_bytes().to_vec(),
        };
        invoke(
            &ix,
            &[
                ctx.accounts.token_program.clone(),
                ctx.accounts.source.clone(),
                ctx.accounts.destination.clone(),
                ctx.accounts.authority.to_account_info(),
            ],
        )?;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Pay<'info> {
    /// CHECK: writable token source passed through to CPI
    #[account(mut)]
    pub source: AccountInfo<'info>,
    /// CHECK: writable token destination passed through to CPI
    #[account(mut)]
    pub destination: AccountInfo<'info>,
    pub authority: Signer<'info>,
    /// CHECK: caller chooses the CPI program
    pub token_program: AccountInfo<'info>,
}
