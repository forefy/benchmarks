# Case 009 - Reward Sweep With Remaining Accounts

This case models a batch maintenance instruction that receives dynamic accounts through `remaining_accounts`.

Audit focus:
- Whether every dynamic account is validated before mutation.
- Whether account owner and discriminator checks are performed.
- Whether writable arbitrary accounts can be corrupted by maintenance logic.
