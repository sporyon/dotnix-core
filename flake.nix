{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    polkadot.url = "github:andresilva/polkadot.nix";
    polkadot.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs: {
    checks.x86_64-linux.polkadot-validator-two-node-network =
      import ./checks/polkadot-validator-two-node-network.nix {
        inherit inputs;
        system = "x86_64-linux";
      };
    checks.x86_64-linux.polkadot-validator-secrets =
      import ./checks/polkadot-validator-secrets.nix {
        inherit inputs;
        system = "x86_64-linux";
      };

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
