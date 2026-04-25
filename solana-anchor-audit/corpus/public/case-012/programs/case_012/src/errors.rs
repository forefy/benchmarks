use anchor_lang::prelude::*;

#[error_code]
pub enum ErrorCode {
    #[msg("profile namespace is invalid")]
    InvalidNamespace,
}
