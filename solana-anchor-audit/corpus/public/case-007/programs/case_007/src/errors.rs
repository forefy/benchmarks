use anchor_lang::prelude::*;

#[error_code]
pub enum ErrorCode {
    #[msg("pool is already initialized")]
    AlreadyInitialized,
}
