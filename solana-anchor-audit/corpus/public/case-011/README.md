# Case 011 - Refund Claims

This case models refunding a cancelled order from an escrow account.

Audit focus:
- Whether the refund destination is bound to the original buyer.
- Whether the escrow account is associated with the order.
- Whether internal refund amount is zeroed before value transfer.
