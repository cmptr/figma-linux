#!/usr/bin/env bash
set -euo pipefail

releases_url='https://desktop.figma.com/win/RELEASES'
installer_url='https://desktop.figma.com/win/FigmaSetup.exe'

echo "Checking Figma releases: $releases_url" >&2
releases_content=$(curl -fsSL -H 'User-Agent: Figma/1 (Windows; x64)' "$releases_url")
release_line=${releases_content%%$'\n'*}

version=$(awk '{print $2}' <<<"$release_line")
if [ -z "$version" ]; then
  version='unknown'
fi

echo "Computing Nix hash for: $installer_url" >&2
hash=$(nix store prefetch-file --json "$installer_url" | jq -r .hash)

cat <<EOF
{
  version = "$version";
  url = "$installer_url";
  hash = "$hash";
  expectedElectronMajor = 39;
}
EOF
