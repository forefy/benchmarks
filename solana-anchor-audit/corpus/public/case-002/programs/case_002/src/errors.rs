use anchor_lang::prelude::*;

#[error_code]
pub enum ErrorCode {
    #[msg("wrong owner")]
    WrongOwner,
    #[msg("insufficient balance")]
    InsufficientBalance,
}
