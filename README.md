# IXNAY

IXNAY is a pragmatic TUI-style wrapper around the Nix toolchain. It focuses on the day-to-day workflows that are still awkward while Nix transitions between the legacy `nix-*` utilities and the newer `nix` CLI. IXNAY standardises the commands you run, keeps declarative package blocks in sync, and explains exactly what it is doing so you always know the underlying Nix invocation.

## Highlights

- **Consistent UX** – single entry point for both legacy and modern Nix subcommands, with the executed command echoed in yellow unless muted.
- **Declarative package management** – `ixnay add/remove` keep per-system or per-user marker blocks alphabetised, channel-aware, and annotated with upstream descriptions.
- **Safe automation** – duplicate adds are idempotent, channel changes require explicit removal, and marker insertion tolerates both `environment.systemPackages = [ … ]` and nested `environment = { systemPackages = …; };` layouts.
- **Test-friendly** – `ixnay test` runs the full shell-based suite, while `ixnay --test` runs it silently. `IXNAY_TEST_RUNNER` can point at any compatible runner binary.
- **Quick metadata** – `ixnay describe <pkg>` fetches the `nixpkgs` description without digging through search results.
- **Transparent diagnostics** – helper routines parse common `nix` evaluation/build failures and print actionable hints.

## Requirements

- A POSIX shell environment with Bash 5+
- GNU coreutils, `gawk`, `rg`, and Nix installed with flakes enabled
- `luajit` (preferred) or `lua` available for marker management scripts

## Common Commands

| Command | Purpose |
| --- | --- |
| `ixnay add <user|system> <stable|unstable|master> <pkg>` | Inserts an ixnay-managed package entry with description into the appropriate config file. |
| `ixnay remove <user|system> <stable|unstable|master> <pkg>` | Removes the exact entry previously created by `add`. |
| `ixnay describe <pkg>` | Prints the nixpkgs description via `nix eval --raw`. |
| `ixnay test [args…]` | Runs the full test suite (default `./test`) with live output. |
| `ixnay --test [args…]` | Runs the same suite quietly and exits with the failure count. |
| `ixnay -a` / `ixnay --about` | Prints the one-line project description. |

All commands honour `IXNAY_MUTE_CMD_ECHO` (suppress underlying command output) and `DRY_RUN` (show what would happen without executing it). Declarative operations additionally use `IXNAY_ADD_PLATFORM`, `IXNAY_DARWIN_FLAKE`, and `IXNAY_NIXOS_CONFIG` to override target files during testing.

## Testing

```bash
# Verbose run
./test

# Silence output but preserve exit status (e.g. for CI)
IXNAY_TEST_RUNNER=./test ixnay --test
```

Each individual suite exits with the number of failed assertions, so the aggregated runner returns the total failure count.

## Contributing

1. Enable flakes and ensure `luajit`, `gawk`, `rg`, and `shellcheck` are available.
2. Make changes and add focused regression tests under `tests/`.
3. Run `./test` (or `ixnay test`) and confirm a zero exit code.
4. Mention any new files in `FILES.md` to keep the tracking table current.

Issues and PRs that simplify UX, improve diagnostics, or broaden platform coverage are welcome.
