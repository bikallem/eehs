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
          prev.ocaml-ng.ocamlPackages_5_1.overrideScope'
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

            miou = with oprev;
              buildDunePackage rec {
                version = "0.0.1-beta2";
                pname = "miou";

                src = prev.fetchFromGitHub {
                  owner = "robur-coop";
                  repo = "miou";
                  rev = "master";
                  hash = "sha256-AVpGylxGxG+D5pMSlomzGtxuO88OSUPh5u7upZXw6jk=";
                };

                propagatedBuildInputs = [];
              };

            bechamel = with oprev;
              buildDunePackage {
                pname = "bechamel";
                version = "0.5.0";

                src = builtins.fetchurl {
                  url = https://github.com/mirage/bechamel/releases/download/v0.5.0/bechamel-0.5.0.tbz;
                  sha256 = "0s68bsfa4j8y69pfxlylc9qrfkgrifc849rmcyh2x9jz752ab6ig";
                };
                propagatedBuildInputs = [fmt];
              };

            bechamel-notty = with oprev;
              buildDunePackage rec {
                version = "0.5.0";
                pname = "bechamel-notty";

                src = prev.fetchurl {
                  url = "https://github.com/mirage/bechamel/releases/download/v0.5.0/bechamel-0.5.0.tbz";
                  sha256 = "sha256-L5qlRDlfpi6gZzUngpiL+U2XcWLU0+5uMh5JopxeyGg=";
                };

                propagatedBuildInputs = [notty bechamel fmt];
              };

            thread-table = with oprev;
              buildDunePackage rec {
                version = "1.0.0";
                pname = "thread-table";

                src = prev.fetchurl {
                  url = "https://github.com/ocaml-multicore/thread-table/releases/download/1.0.0/thread-table-1.0.0.tbz";
                  sha256 = "sha256-pIzYhGNZfflELEuqaczAYJHKd7px5DjTYJ+64PO4Hd0=";
                };
              };

            domain-local-await = with oprev;
              buildDunePackage rec {
                version = "1.0.1";
                pname = "domain-local-await";

                src = prev.fetchurl {
                  url = "https://github.com/ocaml-multicore/domain-local-await/releases/download/${version}/domain-local-await-${version}.tbz";
                  sha256 = "sha256-KVIRPFPLB+KwVLLchs5yk5Ex2rggfI8xOa2yPmTN+m8=";
                };

                propagatedBuildInputs = [thread-table];
              };
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
          # pkgs.topiary
        ];

        packages = with opkgs; [
          base_bigstring
          dune-configurator
          cstruct
          miou
          bheap
          fmt
          domain-local-await
          kcas
          kcas_data
          logs
          lwd
          bechamel
          bechamel-notty
          notty
          nottui
          lwt
          pkgs.netcat
          pkgs.rlwrap
          pkgs.clang-tools
        ];
      };
    });
}
