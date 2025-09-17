{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/092c565d333be1e17b4779ac22104338941d913f";
    polkadot.url = "github:andresilva/polkadot.nix/a2eac4baedef48acb30eb869a7f859265d89c915";
    polkadot.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      flake = {
        nixosConfigurations = {
          example-aarch64-linux =
            inputs.nixpkgs.lib.nixosSystem {
              system = "aarch64-linux";
              modules = [
                ./example.nix
              ];
              specialArgs = {
                inherit inputs;
              };
            };
          example-x86_64-linux =
            inputs.nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              modules = [
                ./example.nix
              ];
              specialArgs = {
                inherit inputs;
              };
            };
        };
        nixosModules = {
          polkadot-validator = import ./nixosModules/polkadot-validator.nix;
          selinux = import ./nixosModules/selinux.nix;
        };
        overlays.default = final: prev: {
          list-dependencies = final.callPackage ./pkgs/list-dependencies.nix {};
          polkadot = inputs.polkadot.packages.${final.system}.polkadot;
          polkadot-rpc = final.callPackage ./pkgs/polkadot-rpc.nix {};
          selinux.coreutils =
            (final.callPackage "${inputs.nixpkgs}/pkgs/tools/misc/coreutils" { selinuxSupport = true; })
              .overrideAttrs (old: {
                postPatch = old.postPatch or "" + ''
                  ${final.lib.optionalString (final.system == "aarch64-linux") ''
                     # fails on aarch64-linux
                     echo "int main() { return 77; }" > gnulib-tests/test-free.c
                  ''}
                '';
              });
          selinux.linux-pam =
            final.linux-pam.overrideAttrs (old: {
              buildInputs = old.buildInputs or [] ++ [
                final.libselinux
              ];
            });
          selinux.makeModule = final.callPackage ./pkgs/selinux/make-module.nix {};
          selinux.makePolicy = final.callPackage ./pkgs/selinux/make-policy.nix {};
          selinux.refpolicy = final.callPackage ./pkgs/selinux/refpolicy {};
          selinux.secilc = final.callPackage ./pkgs/selinux/secilc.nix {};
          selinux.selinux-python = final.callPackage ./pkgs/selinux/selinux-python.nix {};
          selinux.systemd =
            (final.systemd.override { withSelinux = true; }).overrideAttrs (old: {
              patches = old.patches or [] ++ [
                ./pkgs/selinux/systemd/selinux-label.patch
              ];
            });
        };
      };
      perSystem = { system, ... }: {
        checks =
          inputs.nixpkgs.lib.mapAttrs'
            (name: _: {
              name = inputs.nixpkgs.lib.removeSuffix ".nix" name;
              value = import (./checks + "/${name}") {
                inherit inputs system;
              };
            })
            (builtins.readDir ./checks);
        legacyPackages =
          inputs.self.overlays.default
            inputs.nixpkgs.legacyPackages.${system}
            inputs.nixpkgs.legacyPackages.${system};
      };
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
    };
}
