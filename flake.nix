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

    overlays.default = final: prev: {
      polkadot = inputs.polkadot.packages.${final.system}.polkadot;
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
  };
}
