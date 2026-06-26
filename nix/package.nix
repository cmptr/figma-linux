{ lib
, stdenv
, fetchurl
, electron
, makeWrapper
, p7zip
, nodejs_20
, asar
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
    asar
  ];

  dontUnpack = true;

  preBuild = ''
    if [ "${toString electronMajor}" != "${toString figmaSource.expectedElectronMajor}" ]; then
      echo "Figma expects Electron major ${toString figmaSource.expectedElectronMajor}, but nixpkgs electron is ${electron.version}." >&2
      echo "Update nix/figma-source.nix or select a compatible nixpkgs Electron package." >&2
      exit 1
    fi
  '';

  buildPhase = ''
    runHook preBuild

    mkdir -p build/exe build/nupkg build/staging
    7z x -y "$src" -obuild/exe

    nupkg=$(find build/exe -name '*.nupkg' -print -quit)
    if [ -z "$nupkg" ]; then
      echo "Could not find Figma .nupkg inside installer" >&2
      exit 1
    fi

    7z x -y "$nupkg" -obuild/nupkg

    asar_source="build/nupkg/lib/net45/resources/app.asar"
    unpacked_source="build/nupkg/lib/net45/resources/app.asar.unpacked"

    if [ ! -f "$asar_source" ]; then
      echo "app.asar not found at $asar_source" >&2
      exit 1
    fi

    cp "$asar_source" build/staging/app.asar
    if [ -d "$unpacked_source" ]; then
      cp -r "$unpacked_source" build/staging/app.asar.unpacked
    fi

    bash ${./patch-app-asar.sh} ${../scripts} build/staging ${asar}/bin/asar

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/figma-desktop
    cp build/staging/app.asar $out/share/figma-desktop/app.asar
    if [ -d build/staging/app.asar.unpacked ]; then
      cp -r build/staging/app.asar.unpacked $out/share/figma-desktop/app.asar.unpacked
    fi
    cp ${../scripts/launcher-common.sh} $out/share/figma-desktop/launcher-common.sh

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
