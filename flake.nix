{
  description = ''
    Set of patches to the standard unsquashfs utility (part of
    squashfs-tools) that attempts to add support for as many hacked-up
    vendor-specific SquashFS implementations as possible
  '';

  inputs.nixpkgs.url = "nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      # Generate a user-friendly version number.
      version = builtins.substring 0 8 self.lastModifiedDate;

      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = builtins.attrValues self.overlays; });
    in
    {
      overlays.default = final: prev: {
        sasquatch-le =
          let
            inherit (final) lib stdenv which zlib xz zstd lz4 lzo;
          in
          stdenv.mkDerivation {
            pname = "sasquatch-le";
            version = "4.5.1";

            patches = lib.optionals final.stdenv.isDarwin
              (final.fetchpatch {
                url = "https://raw.githubusercontent.com/NixOS/nixpkgs/ed81545df5083a95ddcfbff0c029774ecb0326bd/pkgs/tools/filesystems/squashfs/darwin.patch";
                hash = "sha256-bSh9srb5WXD4KNCxALywdNMZcYQLFnrAzkTMRBnhXD8=";
              });

            src = ./.;

            strictDeps = true;
            nativeBuildInputs = [ which ];
            buildInputs = [ zlib xz zstd lz4 lzo ];

            preBuild = ''
              cd squashfs-tools
            '';

            installFlags = [
              "INSTALL_DIR=${placeholder "out"}/bin"
              "INSTALL_MANPAGES_DIR=${placeholder "out"}/share/man/man1"
            ];

            makeFlags = [
              "GZIP_SUPPORT=1"
              "XZ_SUPPORT=1"
              "ZSTD_SUPPORT=1"
              "LZ4_SUPPORT=1"
              "LZMA_SUPPORT=1"
              "LZO_SUPPORT=1"
            ];
          };

        sasquatch-be = final.sasquatch-le.overrideAttrs (super: {
          pname = "sasquatch-be";
          preConfigure = ''
            export CFLAGS="-DFIX_BE"
          '';
          postInstall = ''
            mv $out/bin/sasquatch{,-v4be}
          '';
        });

        sasquatch = final.buildEnv {
          name = "sasquatch";
          paths = with final; [
            sasquatch-be
            sasquatch-le
          ];
        };
      };
      packages = forAllSystems (system: rec {
        inherit (nixpkgsFor.${system}) sasquatch sasquatch-be sasquatch-le;
        default = sasquatch;
      });
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ pkgs.sasquatch-le ];
          };
        });
    };
}
