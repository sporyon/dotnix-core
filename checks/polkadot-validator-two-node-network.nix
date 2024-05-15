# polkadot-validator-two-node-network
#
# This test spawns two machines each running a validator.
# The test succeeds once both validators connect to each other.
#

{ inputs, nixosModules, system }:

inputs.nixpkgs.lib.nixos.runTest {
  name = "polkadot-validator-two-node-network";

  hostPkgs = inputs.nixpkgs.legacyPackages.${system};

  nodes =
    inputs.nixpkgs.lib.genAttrs ["alice" "bob"] (name: { config, lib, pkgs, ... }: {
      imports = [
        nixosModules.polkadot-validator
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
        pkgs.jq
        pkgs.rpc
      ];

      nixpkgs.overlays = [
        (self: super: {
          rpc = super.writers.writeDashBin "rpc" ''
            # usage: rpc METHOD
            set -efu

            payload=$(${super.jq}/bin/jq -n --arg method "$1" '
              {
                jsonrpc: "2.0",
                id: 1,
                method: $method,
                params: []
              }
            ')

            ${super.curl}/bin/curl \
                -fSs \
                -H 'Content-Type: application/json' \
                -d "$payload" \
                http://localhost:9944
          '';
        })
      ];

      # Generate node keys to allow starting with the authority role.
      systemd.services.polkadot-validator.serviceConfig.ExecStartPre = let
        cfg = config.dotnix.polkadot-validator;
      in
        "${cfg.package}/bin/polkadot key generate-node-key ${lib.escapeShellArgs (lib.flatten [
          (lib.optional (cfg.chain != null) "--chain=${cfg.chain}")
          "--base-path=%S/polkadot-validator"
        ])}";
    });

  testScript = ''
    start_all()

    alice.wait_for_unit("polkadot-validator.service")
    alice.wait_until_succeeds("rpc system_peers | jq -e '.result|length == 1'")
  '';
}
