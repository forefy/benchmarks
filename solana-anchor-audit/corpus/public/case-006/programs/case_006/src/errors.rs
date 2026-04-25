use anchor_lang::prelude::*;

#[error_code]
pub enum ErrorCode {
    #[msg("slot moved backwards")]
    SlotRegression,
    #[msg("reward math overflowed")]
    MathOverflow,
}
