use anchor_lang::prelude::*;

#[error_code]
pub enum ErrorCode {
    #[msg("too much debt")]
    TooMuchDebt,
    #[msg("oracle price is stale")]
    StaleOracle,
}
