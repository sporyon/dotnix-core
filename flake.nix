{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    polkadot.url = "github:andresilva/polkadot.nix";
    polkadot.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs: {
    checks.x86_64-linux =
      inputs.nixpkgs.lib.mapAttrs'
        (name: _: {
          name = inputs.nixpkgs.lib.removeSuffix ".nix" name;
          value = import (./checks + "/${name}") {
            inherit inputs;
            system = "x86_64-linux";
          };
        })
        (builtins.readDir ./checks);

    nixosModules.polkadot-validator = import ./nixosModules/polkadot-validator.nix;
    nixosModules.selinux = import ./nixosModules/selinux.nix;

    overlays.default = final: prev: {
      list-dependencies = final.callPackage ./pkgs/list-dependencies.nix {};
      polkadot = inputs.polkadot.packages.${final.system}.polkadot;
      polkadot-rpc = final.callPackage ./pkgs/polkadot-rpc.nix {};
      selinux.coreutils = final.callPackage "${inputs.nixpkgs}/pkgs/tools/misc/coreutils" { selinuxSupport = true; };
      selinux.makeModule = final.callPackage ./pkgs/selinux/make-module.nix {};
      selinux.makePolicy = final.callPackage ./pkgs/selinux/make-policy.nix {};
      selinux.refpolicy = final.callPackage ./pkgs/selinux/refpolicy.nix {};
      selinux.secilc = final.callPackage ./pkgs/selinux/secilc.nix {};
      selinux.selinux-python = final.callPackage ./pkgs/selinux/selinux-python.nix {};
      selinux.systemd = final.systemd.override { withSelinux = true; };
    };

    packages.x86_64-linux = {
      docker = import ./docker.nix {
        inherit inputs;
        system = "x86_64-linux";
      };
    } //
      inputs.self.overlays.default
        inputs.nixpkgs.legacyPackages.x86_64-linux
        inputs.nixpkgs.legacyPackages.x86_64-linux;


    nixosConfigurations.selinux-vm =
      # test is a hostname for our machine
      inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
        ];
        specialArgs = {
          inherit inputs;
        };
      };

  };
}
