# Mistakes

- 2026-07-11: `ixnay reify --help` was interpreted as a normal reify argument,
  so it rendered—and outside dry-run mode could execute—a rebuild. Treat
  subcommand help as a first-class non-mutating path and test it explicitly.
