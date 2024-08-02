# List dependencies
#
# This test spawns a machine running the list-dependencies tests on glibc-2.35.
# The tests succeed if the result matches the sha256 of list dependencies stdout

{ inputs, system }:

inputs.nixpkgs.lib.nixos.runTest {
  name = "list-dependencies";

  hostPkgs = inputs.nixpkgs.legacyPackages.${system};

  nodes = {
    alice = { config, pkgs, ... }: {
      # Files used in testScript.
      environment.etc."mockdep".source = ./.;
      environment.etc."mockdep.all.sha256sums".source = builtins.toFile "mockdep.all.sha256sums" ''
        3bc8af3aadc8ef233a108d56ef36a0c973b14527116f49b33c06443de92d18d2  -
      '';
      environment.etc."mockdep.runtime.sha256sums".source = builtins.toFile "mockdep.runtime.sha256sums" ''
        026374dc4f48f74804898e445111a64b40cd003d3aebeec9e7133b608aeabb9a  -
      '';

      # Helper utilities to be used in testScript.
      environment.systemPackages = [
        pkgs.coreutils
        pkgs.list-dependencies
        pkgs.nix
      ];

      nix.settings.experimental-features = [
        "flakes"
        "nix-command"
      ];

      nixpkgs.overlays = [
        inputs.self.overlays.default
      ];

      system.stateVersion = "24.11";
    };
  };

  testScript = ''
    alice.succeed("nix-build /etc/mockdep/mockdep.nix")
    alice.succeed("list-dependencies --runtime ./result | sha256sum -c /etc/mockdep.runtime.sha256sums")
    alice.succeed("list-dependencies --runtime ./result | sha256sum -c /etc/mockdep.runtime.sha256sums")
  '';
}
