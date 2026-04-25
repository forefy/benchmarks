use anchor_lang::prelude::*;

#[error_code]
pub enum ErrorCode {
    #[msg("order is not cancelled")]
    NotCancelled,
}
