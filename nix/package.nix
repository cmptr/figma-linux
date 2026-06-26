{ lib
, stdenv
, fetchurl
, electron
, makeWrapper
, p7zip
, nodejs_20
, figmaSource
}:

let
  electronMajor = lib.toInt (builtins.head (lib.splitString "." electron.version));
in
stdenv.mkDerivation {
  pname = "figma-desktop";
  version = figmaSource.version;

  src = fetchurl {
    inherit (figmaSource) url hash;
  };

  nativeBuildInputs = [
    makeWrapper
    p7zip
    nodejs_20
  ];

  dontUnpack = true;

  preBuild = ''
    if [ "${toString electronMajor}" != "${toString figmaSource.expectedElectronMajor}" ]; then
      echo "Figma expects Electron major ${toString figmaSource.expectedElectronMajor}, but nixpkgs electron is ${electron.version}." >&2
      echo "Update nix/figma-source.nix or select a compatible nixpkgs Electron package." >&2
      exit 1
    fi
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/figma-desktop
    cat > $out/share/figma-desktop/README.native-package-skeleton <<'EOF'
This is a packaging skeleton. The app.asar extraction and patching steps are added in the next task.
EOF

    makeWrapper ${electron}/bin/electron $out/bin/figma-desktop \
      --add-flags "$out/share/figma-desktop/app.asar"

    runHook postInstall
  '';

  meta = {
    description = "Figma Desktop for Linux";
    homepage = "https://github.com/IliyaBrook/figma-linux";
    platforms = [ "x86_64-linux" ];
    license = lib.licenses.unfree;
    mainProgram = "figma-desktop";
  };
}
