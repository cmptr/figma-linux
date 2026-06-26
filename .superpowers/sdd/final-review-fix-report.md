# Final Review Fix Report

## Changes

- `nix/update-figma.sh`
  - Parses the numeric Figma version from the RELEASES package filename (`Figma-126.6.9-full.nupkg` -> `126.6.9`).
  - Emits the upstream package filename as a commented `upstreamPackageName` hint so copying the output into `figma-source.nix` does not add an extra attr.
  - Carries forward `expectedElectronMajor` from `nix/figma-source.nix` when available, defaulting to `39` only as a fallback.
  - Prints stderr warnings that the Electron major is carried forward and must be verified against the installer before updating the pin.
- `flake.nix`
  - Added comments documenting why Node 20 and Electron 39 are currently permitted insecure packages and when to revisit them.
  - Added a comment explaining explicit Electron fallback selection.

## Verification

- `nix run .#update-figma`
  - Outcome: passed.
  - Output version is `126.6.9`.
  - Output hash matches existing pin: `sha256-CBITK3TyG2dLEbDMXsQEOJHdMGDMjlEQ+tsYCDQg18c=`.
  - Stderr includes warnings about carrying forward/verifying `expectedElectronMajor = 39`.
- `nix flake check`
  - Outcome: passed.
  - Note: existing warnings remain that apps lack `meta` attributes.
- `nix build .#figma-desktop`
  - Outcome: passed.

## Concerns

- `expectedElectronMajor` is still a manual/carry-forward value by design; it must be verified whenever the Figma installer pin changes.
- The insecure package allowances are documented but unchanged for compatibility.
