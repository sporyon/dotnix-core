{
  inputs = {
    nixpkgs.url = "git+file:/var/src/nixpkgs-unstable";

    polkadot.url = "github:andresilva/polkadot.nix";
    polkadot.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs: rec {
    checks.x86_64-linux.polkadot-validator-two-node-network =
      import ./checks/polkadot-validator-two-node-network.nix {
        inherit inputs nixosModules;
        system = "x86_64-linux";
      };

    nixosModules.polkadot-validator = import ./nixosModules/polkadot-validator.nix;

    # usage: nix build --no-link --print-out-paths .#polkadot
    # test: $(nix build --no-link --print-out-paths .#polkadot)/bin/polkadot --version | grep -q ^polkadot
    #   https://wiki.polkadot.network/docs/maintain-guides-how-to-validate-polkadot
    #   says that the versions of all three executables[1] must be the same.
    #   [1]: polkadot, polkadot-execute-worker, polkadot-prepare-worker
    packages.x86_64-linux.polkadot = inputs.polkadot.packages.x86_64-linux.polkadot;
    packages.x86_64-linux.subkey = inputs.polkadot.packages.x86_64-linux.subkey;
  };
}
