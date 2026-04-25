use anchor_lang::prelude::*;

#[account]
pub struct PaymentConfig {
    pub authority: Pubkey,
    pub expected_token_program: Pubkey,
}
