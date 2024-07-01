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

    packages.x86_64-linux.docker =
      import ./docker.nix {
        inherit inputs;
        system = "x86_64-linux";
      };
    # usage: nix build --no-link --print-out-paths .#polkadot
    # test: $(nix build --no-link --print-out-paths .#polkadot)/bin/polkadot --version | grep -q ^polkadot
    #   https://wiki.polkadot.network/docs/maintain-guides-how-to-validate-polkadot
    #   says that the versions of all three executables[1] must be the same.
    #   [1]: polkadot, polkadot-execute-worker, polkadot-prepare-worker
    packages.x86_64-linux.polkadot = inputs.polkadot.packages.x86_64-linux.polkadot;
    packages.x86_64-linux.subkey = inputs.polkadot.packages.x86_64-linux.subkey;
  };
}
