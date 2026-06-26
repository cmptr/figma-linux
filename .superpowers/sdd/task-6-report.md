# Task 6 Report

## Status
Complete. Added the Figma update helper flake app and documented the native Nix package/update workflow.

## Files
- `nix/update-figma.sh` - new executable helper that reads Figma RELEASES, prefetches the installer, and prints `figma-source.nix` metadata.
- `flake.nix` - added `apps.x86_64-linux.update-figma` via `pkgs.writeShellApplication` with curl, jq, and nix runtime inputs.
- `README.md` - documented native Nix build/run/install and update-helper usage.

## Commit
`b45fab760ea0740eb9adef8fc5b811d99b410871` (`docs: document native nix package workflow`)

## Commands / Outcomes
- `nix eval .#apps.x86_64-linux.update-figma.program` before implementation: failed because the app was missing (expected RED check).
- `nix eval .#apps.x86_64-linux.update-figma.type && nix eval .#apps.x86_64-linux.update-figma.program`: passed after staging new script for Nix visibility.
- `nix run .#update-figma`: passed; printed metadata with current upstream hash `sha256-CBITK3TyG2dLEbDMXsQEOJHdMGDMjlEQ+tsYCDQg18c=`.
- `nix fmt`: exited 0.
- `nix flake check`: exited 0; all checks passed. Nix warned that flake apps lack `meta`, pre-existing style for the default app and also applies to new app.
- `nix build .#figma-desktop`: exited 0.

## Concerns
- The helper follows the brief exactly, including `awk '{print $2}'`; current upstream RELEASES makes this print `Figma-126.6.9-full.nupkg` rather than only `126.6.9`.
- `nix flake check` emits app `meta` warnings, but exits 0.

## Review Fix Report - SIGPIPE-safe update helper

- Reworked `nix/update-figma.sh` to fetch the full upstream `RELEASES` response before selecting the first line, avoiding `curl | head` fragility under `set -o pipefail`.
- Updated README Nix update-helper note to clarify that the helper's `version` value follows the upstream `RELEASES` field format, e.g. `Figma-126.6.9-full.nupkg`.

Verification:
- `nix run .#update-figma` — passed; reported `version = "Figma-126.6.9-full.nupkg"` and hash `sha256-CBITK3TyG2dLEbDMXsQEOJHdMGDMjlEQ+tsYCDQg18c=`.
- `nix flake check` — passed; all checks passed (apps still warn that `meta` is missing).
- `nix build .#figma-desktop` — passed.
