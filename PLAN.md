# ixnay Plan

- [x] Select a flake output from the declared NixOS host name when a hostname
  rename is pending, while preserving explicit override precedence. (2026-07-11 13:48 EDT)
  - Curiosity poke: `ixnay reify --no-update` must never fall back to a retired
    generic output merely because the running hostname has not rebooted yet.
- [x] Make `ixnay reify --help` informational rather than a command-rendering
  reify invocation. (2026-07-11 13:48 EDT)
