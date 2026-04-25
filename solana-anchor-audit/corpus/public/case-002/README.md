# Case 002 - Delegated Vault Withdrawals

This case models a lamport-backed vault where a stored owner can withdraw accounting balance to a destination account.

Audit focus:
- Whether identity checks also require transaction authorization.
- Whether lamport movements stay aligned with internal accounting.
- Whether unchecked accounts are justified by explicit runtime checks.
