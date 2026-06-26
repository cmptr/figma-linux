#!/usr/bin/env bash
set -euo pipefail

releases_url='https://desktop.figma.com/win/RELEASES'
installer_url='https://desktop.figma.com/win/FigmaSetup.exe'

echo "Checking Figma releases: $releases_url" >&2
releases_content=$(curl -fsSL -H 'User-Agent: Figma/1 (Windows; x64)' "$releases_url")
release_line=${releases_content%%$'\n'*}

upstream_package_name=$(awk '{print $2}' <<<"$release_line")
version=$(sed -nE 's/^Figma-([0-9]+(\.[0-9]+)+)-.*$/\1/p' <<<"$upstream_package_name")
if [ -z "$version" ]; then
  version='unknown'
fi

source_file='nix/figma-source.nix'
expected_electron_major='39'
if [ -f "$source_file" ]; then
  expected_electron_major=$(sed -nE 's/^[[:space:]]*expectedElectronMajor[[:space:]]*=[[:space:]]*([0-9]+);[[:space:]]*$/\1/p' "$source_file" | head -n1)
fi
if [ -z "$expected_electron_major" ]; then
  expected_electron_major='39'
fi

echo "Computing Nix hash for: $installer_url" >&2
hash=$(nix store prefetch-file --json "$installer_url" | jq -r .hash)
echo "WARNING: carrying forward expectedElectronMajor = $expected_electron_major from $source_file/manual default." >&2
echo "WARNING: verify this Electron major against the Figma installer before updating nix/figma-source.nix." >&2

cat <<EOF
{
  version = "$version";
  # upstreamPackageName = "$upstream_package_name";
  url = "$installer_url";
  hash = "$hash";
  expectedElectronMajor = $expected_electron_major;
}
EOF
