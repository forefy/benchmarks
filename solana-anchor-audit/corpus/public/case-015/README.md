# Case 015 - Safe Reward Claim

This case models a clean reward-claim flow backed by a PDA reward authority and mint-bound token accounts.

Audit focus:
- Whether claim state belongs to the signing user.
- Whether reward vault and recipient token accounts use the configured mint.
- Whether pending rewards are cleared before token transfer.
