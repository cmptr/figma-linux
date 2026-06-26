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
        ];
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

      checks.${system}.dev-shell = pkgs.runCommand "figma-linux-dev-shell-check" { } ''
        test -x ${pkgs.nodejs_20}/bin/node
        test -x ${pkgs.p7zip}/bin/7z
        test -x ${pkgs.imagemagick}/bin/convert
        touch $out
      '';
    };
}
