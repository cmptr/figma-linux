# Task 4 Report: package-friendly app.asar extraction and patching

## Status
Completed.

## Files changed
- `nix/package.nix` - added `asar` input/native build input, extracts pinned Figma installer and nupkg, stages and patches `app.asar`, installs patched assets and launcher wrapper.
- `nix/patch-app-asar.sh` - new executable helper that custom-extracts `app.asar`, ports required patch logic from `build.sh`, copies native stubs/font enum scripts, and repacks with Nix-provided `asar`.

## Commit
- `f2f9d86` (`feat: build patched figma app asar in nix`)

## Commands and outcomes
- `git add nix/patch-app-asar.sh nix/package.nix && nix build .#figma-desktop --show-trace` - initially failed because `asar extract` could not handle negative-size special entries in Figma's `app.asar` (`ERR_OUT_OF_RANGE`, size `-1000`).
- `git diff --cached --check && nix build .#figma-desktop --show-trace` - passed; produced `/nix/store/l1rjb43m9phps92fy129gcb2bxf444mc-figma-desktop-126.6.9` with `share/figma-desktop/app.asar`.
- `git commit -m "feat: build patched figma app asar in nix"` - passed; created commit `f2f9d86`.

## Concerns
- The helper ports the required build-enabling/app-launch patch blocks, including the argv/auth redirect patch that fails clearly if its minified pattern is missing. Some ancillary UX patches from `build.sh` (for example duplicate-tabs tray/preferences and tray notification CSS/debug tweaks) were not ported because the task scoped this to functional equivalence enough to build and requested only required patch blocks.
- `nix build` warns that the Git tree is dirty while the report file is uncommitted; this report was written after the requested Task 4 commit so the commit contains only Task 4 package changes.

## Task 4 review fixes

## Status
Completed review fixes.

## Files changed
- `nix/patch-app-asar.sh` - copies original unpacked ASAR files into the extracted tree, records their archive-relative paths, repacks with `@electron/asar.createPackageWithOptions` and an unpack glob so ASAR header `unpacked` metadata is preserved; makes required frame/menu/tray/runtime patch targets fail clearly when absent; uses JSON-safe quoting for `frame-fix-entry.js`'s original main require.
- `nix/package.nix` - passes only the repository `scripts` directory to the patch helper instead of the whole source tree.

## Commands and outcomes
- `bash -n nix/patch-app-asar.sh` - passed.
- `nix build .#figma-desktop --show-trace --no-link --print-out-paths` plus header inspection with `@electron/asar` - passed; output retained `share/figma-desktop/app.asar.unpacked` and the repacked ASAR header contains 5 unpacked entries: the three cursor dropper assets, `bindings.node`, and `desktop_rust.node`.
- `nix build .#figma-desktop --show-trace` - passed.
- `git diff --check` - passed.

## Concerns
- `desktop_shell.js` currently has no frame patterns to replace, so that specific shell-frame sed equivalent is reported as an optional skip. The shell menu platform-gate patch remains required and fails if its target is absent.

## Task 4 remaining review fix

## Status
Completed remaining review fix.

## Files changed
- `nix/patch-app-asar.sh` - tracks `bindings_worker.js` native-runtime replacements separately and fails if the required worker patch does not apply or if desktop Rust native require calls remain after patching.

## Commands and outcomes
- `bash -n nix/patch-app-asar.sh` - passed.
- `nix build .#figma-desktop --show-trace` - passed; produced `result` pointing at `/nix/store/1q14kzg25666vvqz07ybkxzffw4lxxsb-figma-desktop-126.6.9`.

## Concerns
- `nix build` warned that the Git tree was dirty because this review fix and report update were uncommitted during the build.
