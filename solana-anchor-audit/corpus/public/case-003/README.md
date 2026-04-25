# Case 003 - Token Vault Authority

This case models token withdrawals from a vault where user balances are tracked in a position account.

Audit focus:
- Whether token authority accounts are derived from the expected PDA seeds.
- Whether token movement and position accounting refer to the same vault domain.
- Whether signer accounts are sufficient proof of protocol authority.
