# Case 008 - Position Close

This case models closing an empty trading position and returning its rent lamports.

Audit focus:
- Whether close recipients are tied to the position owner.
- Whether the position owner relationship is enforced by account constraints.
- Whether close conditions are sufficient before account destruction.
