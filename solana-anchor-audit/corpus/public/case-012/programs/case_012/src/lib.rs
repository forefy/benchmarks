use anchor_lang::prelude::*;

pub mod errors;
pub mod state;

use state::*;

declare_id!("F3SsSk5zUCpDKYx4iGvSFndE4BLB8ziQHmVu6quZ1rMH");

#[program]
pub mod profile_seed_collision {
    use super::*;

    pub fn create_profile(ctx: Context<CreateProfile>, username: String, domain: String) -> Result<()> {
        let profile = &mut ctx.accounts.profile;
        profile.owner = ctx.accounts.owner.key();
        profile.username = username;
        profile.domain = domain;
        Ok(())
    }
}

#[derive(Accounts)]
#[instruction(username: String, domain: String)]
pub struct CreateProfile<'info> {
    #[account(
        init,
        payer = owner,
        space = 8 + Profile::LEN,
        seeds = [username.as_bytes(), domain.as_bytes()],
        bump
    )]
    pub profile: Account<'info, Profile>,
    #[account(mut)]
    pub owner: Signer<'info>,
    pub system_program: Program<'info, System>,
}
