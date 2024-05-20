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
        nixosModules.systemdVaultd
        nixosModules.vaultAgent
      ];

      # Vault is using Business Source License 1.1
      nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
        "vault"
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

      # Vault Agent configuration.
      services.vault.agents.default.settings.vault.address = "http://localhost:8200";
      services.vault.agents.default.settings.auto_auth.method = [
        {
          type = "approle";
          config = {
            role_id_file_path = "/tmp/role_id";
            secret_id_file_path = "/tmp/secret_id";
            remove_secret_id_file_after_reading = false;
          };
        }
      ];

      # Vault Server configuration.
      services.vault.enable = true;
      services.vault.dev = true;
      services.vault.devRootTokenID = "testsecret";
      systemd.services.vault-setup = {
        wantedBy = [ "multi-user.target" ];
        after = [ "vault.service" ];
        environment = {
          VAULT_TOKEN = config.services.vault.devRootTokenID;
          VAULT_ADDR = config.services.vault.agents.default.settings.vault.address;
        };
        serviceConfig = {
          Type = "oneshot";
          SyslogIdentifier = "vault-setup";
          ExecStart = pkgs.writers.writeDash "vault-setup" ''
            set -efu

            until ${pkgs.vault}/bin/vault status; do
              ${pkgs.coreutils}/bin/sleep 1
            done

            ${pkgs.vault}/bin/vault policy write test_policy ${pkgs.writeText "vault-test-policy.hcl" ''
              path "secret/data/*" {
                capabilities = ["read"]
              }
            ''}

            ${pkgs.vault}/bin/vault auth enable approle
            ${pkgs.vault}/bin/vault write auth/approle/role/role1 bind_secret_id=true token_policies=test_policy

            ${pkgs.vault}/bin/vault read -format json auth/approle/role/role1/role-id |
            ${pkgs.jq}/bin/jq -r .data.role_id > /tmp/role_id
            ${pkgs.vault}/bin/vault write -force -format json auth/approle/role/role1/secret-id |
            ${pkgs.jq}/bin/jq -r .data.secret_id > /tmp/secret_id

            ${pkgs.polkadot}/bin/polkadot key generate-node-key |
            ${pkgs.vault}/bin/vault kv put secret/polkadot-validator node_key=-
          '';
        };
      };

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
    });

  testScript = ''
    start_all()

    alice.wait_for_unit("polkadot-validator.service")
    alice.wait_until_succeeds("rpc system_peers | jq -e '.result|length == 1'")
  '';
}
