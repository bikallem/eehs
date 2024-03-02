{
  description = "OCaml lib and bin projects to get started with nix flakes.";

  inputs.nix-filter.url = "github:numtide/nix-filter";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.inputs.flake-utils.follows = "flake-utils";
  # inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.nixpkgs.url = "github:nix-ocaml/nix-overlays";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nix-filter,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages."${system}".extend (final: prev: rec {
        ocamlPackages =
          prev.ocaml-ng.ocamlPackages_5_1.overrideScope
          (ofinal: oprev: rec {
            ocaml =
              (oprev.ocaml.override {
                flambdaSupport = true;
                framePointerSupport = true;
              })
              .overrideAttrs (_:ocaml_prev: {
                #   pname = ocaml_prev.pname + "+bikal";
                #   src = prev.fetchFromGitHub {
                #     owner = "bikallem";
                #     repo = "ocaml";
                #     rev = "e02d0eb777b3a9432ef204ea25cfe7a132f1903e";
                #     hash = "sha256-211q6ZmfEdMgM1zMUDBF8sLHyPpoxZ3gPmiN5CZCH8g=";
                #   };
              });
          });
      });

      opkgs = pkgs.ocamlPackages;
      # opkgs = pkgs.ocaml-ng.ocamlPackages_dev;
    in {
      devShells.default = pkgs.mkShell {
        dontDetectOcamlConflicts = true;
        nativeBuildInputs = with opkgs; [
          dune
          utop
          ocaml
          ocamlformat
          findlib
        ];

        packages = with opkgs; [
          base_bigstring
          dune-configurator
          fmt
          logs
          pkgs.nushell
          pkgs.liburing
          pkgs.hyperfine
          pkgs.netcat
          pkgs.rlwrap
          pkgs.clang-tools
          pkgs.moreutils
          pkgs.cling
          pkgs.gcc
          pkgs.gdb
          pkgs.llvmPackages_17.libcxxClang
          pkgs.llvmPackages_17.lldb
        ];
      };
    });
}
