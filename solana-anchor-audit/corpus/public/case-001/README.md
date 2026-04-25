# Case 001 - Fee Configuration

This case models a protocol-wide fee configuration account. The program stores an authority and lets the configured fee basis points be updated after initialization.

Audit focus:
- Whether the update path is limited to the recorded authority.
- Whether fee bounds are enforced consistently.
- Whether the account model prevents accidental replacement of global configuration.
