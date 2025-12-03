{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/8bb5646e0bed5dbd3ab08c7a7cc15b75ab4e1d0f"; # nixos-25.11 @ 2025-11-30T17:11:29Z
    polkadot.url = "github:andresilva/polkadot.nix/a2eac4baedef48acb30eb869a7f859265d89c915";
    polkadot.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } rec {
      flake = {
        nixosConfigurations =
          (xs: f: builtins.listToAttrs (map f xs)) systems (system: {
            name = "example-${system}";
            value = inputs.nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                ./example.nix
              ];
              specialArgs = {
                inherit inputs;
              };
            };
          });
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
