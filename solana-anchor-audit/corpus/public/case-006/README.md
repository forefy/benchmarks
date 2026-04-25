# Case 006 - Reward Accrual Math

This case models slot-based reward accrual for a staking account.

Audit focus:
- Whether elapsed time and reward rate multiplication are checked.
- Whether stale or backwards slot inputs are handled.
- Whether reward accumulation can wrap or silently truncate.
