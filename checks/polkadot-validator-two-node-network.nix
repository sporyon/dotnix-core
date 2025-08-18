# polkadot-validator-two-node-network
#
# This test spawns two machines each running a validator.
# The test succeeds once both validators connect to each other.
#

{ inputs, system }:

inputs.nixpkgs.lib.nixos.runTest {
  name = "polkadot-validator-two-node-network";

  hostPkgs = inputs.nixpkgs.legacyPackages.${system};

  nodes =
    inputs.nixpkgs.lib.genAttrs ["alice" "bob"] (name: { config, pkgs, ... }: {
      imports = [
        inputs.self.nixosModules.polkadot-validator
        inputs.self.nixosModules.selinux
      ];

      # Validator configuration.
      dotnix.polkadot-validator.enable = true;
      dotnix.polkadot-validator.name = name;
      dotnix.polkadot-validator.chain = "dev";
      dotnix.polkadot-validator.extraArgs = [
        "--db-storage-threshold=0"
      ];

      # Allow the validators to find and connect to each other.
      networking.firewall.allowedTCPPorts = [ 30333 ];
      networking.firewall.allowedUDPPorts = [ 5353 ];

      # Helper utilities to be used in testScript.
      environment.systemPackages = [
        config.dotnix.polkadot-validator.package
        pkgs.jq
        pkgs.polkadot-rpc
      ];

      nixpkgs.overlays = [
        inputs.self.overlays.default
      ];

      system.stateVersion = "24.11";
    });

  testScript = ''
    start_all()

    # Set some generated node keys to start the validator.
    alice.succeed("polkadot key generate-node-key | polkadot-validator --set-node-key")
    bob.succeed("polkadot key generate-node-key | polkadot-validator --set-node-key")

    alice.wait_for_unit("polkadot-validator.service")

    alice.wait_until_succeeds("rpc system_peers | jq -e '.result|length == 1'")
  '';
}
