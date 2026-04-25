# Case 013 - Safe Token Vault

This case models a clean token vault with PDA authority, receipt accounting, and typed SPL token CPI.

Audit focus:
- Whether mint and token owner constraints are complete.
- Whether withdrawal signer seeds match the vault PDA.
- Whether receipt accounting is updated before value leaves the vault.
