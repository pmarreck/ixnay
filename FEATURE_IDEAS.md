---
purpose: Backlog of proposed ixnay features not yet implemented
audience: both
maintained_by: both
---

# ixnay — Feature Ideas

Running backlog of proposed features. Promote an item to `PLAN.md` when picked up.

## Package-set search & audit (proposed 2026-07-02)

**Motivation:** the NixOS config ixnay drives uses several named nixpkgs scopes
(base `pkgs`, `unstable`, `master`, and a pinned `stable`). Answering "which
scope has package X?" and "will this config even evaluate before I reify?"
currently means hand-building `nix-instantiate --eval` one-liners every time.
Two subcommands would fold that friction into the tool.

### `ixnay which <pkg>`
Show which configured scopes provide `<pkg>` and at what version:

```
$ ixnay which limo
  base        MISSING
  unstable    MISSING   (channel snapshot lags branch tip)
  master      MISSING
  stable      limo-1.2.2   ← pinned nixpkgs release-26.05
```

Would have instantly resolved the "where is limo / why isn't it in unstable"
confusion — `nix-channel` snapshots lag the branch tip that search.nixos.org
shows, so a package can be "in unstable" on the website yet absent locally.

### `ixnay audit`
Pre-flight gate: parse every `<scope>.<attr>` reference in the NixOS config and
verify each resolves in its target nixpkgs **before** `reify`. Reports missing or
renamed attrs (e.g. `stable.nvtop` → `nvtopPackages.*` after a channel bump) so
the rename is caught *before* a failed `nixos-rebuild`, not halfway through it.

This is an MFIC-style control: it mechanically sweeps the whole reference set,
its truth source (the target nixpkgs) is independent of whoever edited the
config, and it has the authority to fail the run — "run toward problems" turned
into a reusable check.

**Caveat (scope boundary):** `audit` catches missing/renamed *attributes*
(eval-time). It does NOT catch transitive-insecure deps (e.g. `olm-3.2.16`
pulled in by a Matrix client) or build failures (e.g. tome2's vendored jsoncons
breaking under a newer GCC) — those only surface in an actual build. Consider an
optional `ixnay audit --build` that additionally runs a non-switching
`nixos-rebuild build` for full coverage.

**Origin:** surfaced 2026-07-02 while modernizing the `stable` scope from an EOL
22.11 channel to a pinned nixpkgs release-26.05, which triggered exactly these
three failure classes in sequence — `nvtop` rename (eval), `olm` insecure
(transitive), tome2 build break (compile). An `audit` gate would have caught the
first before the reify; the latter two argue for the `--build` variant.
