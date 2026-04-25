# Case 004 - External Payment CPI

This case models a payment helper that forwards writable accounts into a CPI selected at runtime.

Audit focus:
- Whether external programs are constrained to trusted program IDs.
- Whether writable accounts are exposed to arbitrary code.
- Whether low-level `invoke` usage preserves the same assumptions as typed Anchor CPI.
