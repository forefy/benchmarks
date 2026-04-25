# Case 007 - Pool Initialization

This case models a singleton pool account derived from a fixed PDA seed.

Audit focus:
- Whether initialization can be safely retried.
- Whether mutable configuration fields are protected after first setup.
- Whether `init_if_needed` is paired with an explicit initialized flag.
