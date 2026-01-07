# Created Files

| Path | Purpose |
| --- | --- |
| `FILES.md` | Master list of files created during this session. |
| `PLAN.md` | Project plan and running status. |
| `test` | Top-level script to run all unit tests. |
| `tests/test_helper.sh` | Shared assertion helpers for shell-based unit tests. |
| `tests/add_command_test.sh` | Tests for the new `ixnay add` command behavior. |
| `tests/add_target_test.sh` | Tests for locating the correct config file target. |
| `tests/fixtures/nixos_system_example.nix` | Fixture snippet for NixOS system packages list with ixnay markers. |
| `tests/fixtures/nixos_system_nomarker.nix` | Fixture snippet lacking ixnay markers for system packages list. |
| `tests/fixtures/nixos_user_example.nix` | Fixture snippet for per-user packages with ixnay markers. |
| `tests/fixtures/nixos_two_users_example.nix` | Fixture snippet with multiple user blocks for targeted insertion tests. |
| `tests/fixtures/nixos_user_comment_brackets.nix` | Fixture with bracketed comments inside user packages list. |
| `tests/fixtures/nixos_system_with_entries.nix` | Fixture snippet pre-populated with ixnay-managed system entries. |
| `tests/fixtures/nixos_system_environment_attr.nix` | Fixture with `environment = { systemPackages = ...; };` layout for system package tests. |
| `tests/add_insert_test.sh` | Tests for inserting package entries into marker blocks. |
| `tests/remove_operation_test.sh` | Tests for removing ixnay-managed package entries. |
| `tests/remove_cli_test.sh` | CLI-level tests for `ixnay remove`. |
| `tests/legacy_commands_test.sh` | DRY_RUN command emission tests for legacy commands. |
| `tests/bin/nix` | Stubbed `nix` executable for tests. |
| `tests/add_description_test.sh` | Tests for fetching package descriptions via nix. |
| `tests/add_cli_test.sh` | CLI-level tests for `ixnay add`. |
| `tests/meta_commands_test.sh` | Tests for `ixnay test`, `ixnay --test`, and about flag behavior. |
| `lib/add_command.sh` | Implementation module for `ixnay add` logic. |
| `tests/fixtures/nixos_user_broken_end.nix` | Fixture representing marker end sharing a line with closing bracket. |
| `tests/fixtures/darwin_home_manager_user.nix` | Fixture snippet for nix-darwin home-manager user packages list. |
| `tests/fixtures/darwin_system_packages.nix` | Fixture snippet for nix-darwin system packages list without per-user packages. |
| `tests/fixtures/darwin_system_base_list.nix` | Fixture snippet for nix-darwin system packages sourced from a base list binding. |
