{
  description = "Figma Desktop for Linux packaging";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.permittedInsecurePackages = [
          "nodejs-20.20.2"
          "nodejs-slim-20.20.2"
          "electron-39.8.10"
        ];
        config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
          "figma-desktop"
        ];
      };
      figmaSource = import ./nix/figma-source.nix;
      electron =
        let
          defaultElectronMajor = pkgs.lib.toInt (builtins.head (pkgs.lib.splitString "." pkgs.electron.version));
          expectedElectronMajor = figmaSource.expectedElectronMajor;
          expectedElectronAttr = "electron_${toString expectedElectronMajor}";
        in
        if defaultElectronMajor == expectedElectronMajor then
          pkgs.electron
        else if builtins.hasAttr expectedElectronAttr pkgs then
          builtins.getAttr expectedElectronAttr pkgs
        else
          pkgs.electron;
      figmaDesktop = pkgs.callPackage ./nix/package.nix {
        inherit figmaSource electron;
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nodejs_20
          p7zip
          imagemagick
          curl
          wget
          desktop-file-utils
          jq
          git
        ];

        shellHook = ''
          echo "figma-linux dev shell"
          echo "Try: ./build.sh --build appimage --clean no"
        '';
      };

      formatter.${system} = pkgs.nixpkgs-fmt;

      packages.${system} = {
        figma-desktop = figmaDesktop;
        default = figmaDesktop;
      };

      apps.${system}.default = {
        type = "app";
        program = "${figmaDesktop}/bin/figma-desktop";
      };

      checks.${system} = {
        dev-shell = pkgs.runCommand "figma-linux-dev-shell-check" { } ''
          test -x ${pkgs.nodejs_20}/bin/node
          test -x ${pkgs.p7zip}/bin/7z
          test -x ${pkgs.imagemagick}/bin/convert
          touch $out
        '';

        figma-source = pkgs.runCommand "figma-source-check" {
          src = pkgs.fetchurl {
            inherit (figmaSource) url hash;
          };
        } ''
          test -s $src
          touch $out
        '';
      };
    };
}
