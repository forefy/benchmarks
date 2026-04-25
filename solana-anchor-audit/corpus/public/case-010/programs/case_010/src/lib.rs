use anchor_lang::prelude::*;

pub mod errors;
pub mod state;

use state::*;

declare_id!("FujuvooRjd5dcqKFzffir3KNKhckyonUZijwoYrtUWx3");

#[program]
pub mod stale_oracle_lending {
    use super::*;

    pub fn borrow(ctx: Context<Borrow>, amount: u64) -> Result<()> {
        let price = ctx.accounts.oracle.price;
        let max_borrow = ctx.accounts.collateral.amount.checked_mul(price).unwrap() / 2;
        require!(amount <= max_borrow, errors::ErrorCode::TooMuchDebt);
        ctx.accounts.position.debt = ctx.accounts.position.debt.checked_add(amount).unwrap();
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Borrow<'info> {
    #[account(mut, has_one = owner)]
    pub position: Account<'info, Position>,
    pub collateral: Account<'info, Collateral>,
    pub oracle: Account<'info, PriceOracle>,
    pub owner: Signer<'info>,
}
