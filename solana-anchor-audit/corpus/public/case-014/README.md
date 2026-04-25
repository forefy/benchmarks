# Case 014 - Safe Global Config

This case models a clean singleton config account with an authority-controlled treasury update.

Audit focus:
- Whether singleton PDA seeds are enforced.
- Whether the stored authority must sign updates.
- Whether initialization and update paths have distinct account constraints.
