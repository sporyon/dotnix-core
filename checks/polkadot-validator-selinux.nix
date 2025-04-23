# polkadot-validator-selinux tests
#
# This test checks whether users can read secrets.
#

{ inputs, system }:

inputs.nixpkgs.lib.nixos.runTest {
  name = "polkadot-validator-selinux-check";

  hostPkgs = inputs.nixpkgs.legacyPackages.${system};

  nodes.alice = { config, pkgs, ... }: {
    imports = [
      inputs.self.nixosModules.polkadot-validator
      inputs.self.nixosModules.selinux.nix
    ];

    # Validator configuration.
    dotnix.polkadot-validator.enable = true;
    dotnix.polkadot-validator.name = "alice";
    dotnix.polkadot-validator.chain = "dev";
    dotnix.polkadot-validator.extraArgs = [
      "--db-storage-threshold=0"
    ];

    # Helper utilities to be used in testScript.
    environment.systemPackages = [
      config.dotnix.polkadot-validator.package
      pkgs.polkadot-rpc
      # T: selinuxpkgs need to be added
    ];

    nixpkgs.overlays = [
      inputs.self.overlays.default
    ];

    system.stateVersion = "24.11";
  };

  testScript = ''
    start_all()

    # Set some generated node keys to start the validator.
    alice.succeed("polkadot key generate-node-key | polkadot-validator --set-node-key")
    alice.wait_until_succeeds("rpc system_name")

    # Test if the polkadot validator service is active and running
    alice.succeed("systemctl is-active polkadot-validator")
    alice.wait_unitl_succeeds("systemctl status polkadot-validator -n 100")

    # Test if validator secrets are protected
    alice.succeed("cat /#Todo add keylocations")
    alice.succeed("setenforce 1")
    alice.failed("cat /#Todo add keylocations")

    # Test if the the polkadot-validator service can read machine secrets
    alice.succeed("! sudo -u polkadot-validator cat /etc/shadow")
    # Todo add keylocation in the new tests as well 
    # Test if root can write the node key but not read it 
    alice.succeed("echo 'test' > /path/to/node_key && ! sudo cat /path/to/node_key")

    # Test if systemd can read the node key but not write it 
    alice.succeed("systemd-ask-password --no-tty --quiet --print-secret < /path/to/validator_key")
    alice.succeed("! sudo -u polkadot-validator bash -c 'echo test > /path/to/node_key'")
  '';
}
