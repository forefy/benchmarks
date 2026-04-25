# Case 010 - Oracle-Backed Borrowing

This case models collateralized borrowing where a local oracle account supplies the collateral price.

Audit focus:
- Whether oracle data is fresh for the current slot.
- Whether collateral and position ownership are consistently related.
- Whether arithmetic around collateral value and borrow limits is checked.
