use anchor_lang::prelude::*;

#[error_code]
pub enum ErrorCode {
    #[msg("unexpected token mint")]
    UnexpectedMint,
    #[msg("unexpected token authority")]
    UnexpectedAuthority,
}
