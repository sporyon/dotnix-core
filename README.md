# dotnix &middot; [![GitHub license](https://img.shields.io/badge/license-GPL3%2FApache2-blue)](#LICENSE) [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](docs/CONTRIBUTING.adoc)

# dotnix-core
Dotnix is a collection of Nix packages and NixOS modules designed for creating and managing Polkadot/Kusama Validator Nodes, emphasizing both security and ease of use.

### Overview

Dotnix is a collection of Nix packages, NixOS modules, and a command line tool designed for compiling Polkadot validators, managing their deployments while emphasizing both security and ease of use.

#### Security / Auditability

Dotnix aims to minimize the attack surface of a Polkadot node by only enabling services explicitly declared in Nix configuration files. This approach not only enhances its security but also ensures a minimalistic machine setup where components run solely when they are declared, further bolstering the node's defense against potential threats.

Auditability is facilitated by the way the Nix package manager builds packages using only predetermined build inputs, and by producing packages that never change once they have been built. During the build process, there is no arbitrary network access nor access to any file that hasn't been specified explicitly.
Each package is stored in its own directory, like e.g. `/nix/store/nawl092prjblbhvv16kxxbk6j9gkgcqm-git-2.14.1`.

The directory name consists of a unique identifier, the package name, and its version. The name and version are included only for convenience. The identifier captures all of the package's dependencies, i.e. it's a cryptographic hash of its build dependency graph, including all source files, all other packages used directly or indirectly by the build process, and any other detail like e.g. compiler flags.

With Nix, the entire configuration of the Polkadot validator node can be observed at a glance for both the executing system and the validator configurations. This clarity is invaluable for those responsible maintaining these systems.

#### Ease of Use

To simplify testing and operation of the Polkadot validator, Dotnix provides easy access to an array of tools built on top of Nix's tooling such as [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) and [nixos-generators](https://github.com/nix-community/nixos-generators) which will enable users of Dotnix to iterate quickly over their staking infrastructure. This allows the deployment of Polkadot validators to a variety of cloud providers as well as self-hosted virtual machines. It can even spawn local virtual machine instances directly for any given NixOS configuration, providing a convenient way to for testing. A command line tool will be developed to add even more management capabilities of validators that have been deployed using the initial set of tools.

## Usage

### Secrets Management

On a freshly deployed system, the Polkadot validator will be inactive until the node key gets configured.
For configuration of the node key, the `polkadot-validator` command line utility can be used.

To set the node key, it can be pasted or piped to

    polkadot-validator --set-node-key

Setting the node key will cause the validator to be started.  If the validator
is already running with a different key, it will be restarted to use the newly
supplied one instead.  The key is stored persistently, i.e. it will survive
reboots, causing the validator to start automatically.

To remove the node key again, call

    polkadot-validator --unset-node-key

Removing the node key will cause the validator to be stopped.

_NB a new node key can be obtained by running `polkadot key generate-node-key`._

### Session Key Management

To generate a new session keys and print the corresponding public keys to standard output, call

    polkadot-validator --rotate-keys

### Keystore Management

To create a local backup of the keystore data, call

    polkadot-validator --backup-keystore

After executing successfully, the location of the backup file will be printed to standard output.

### Service Management

Administrative tasks regarding the Polkadot validator service can be performed
using the `polkadot-validator` command line utility.

To purge logs older than two days, call

    polkadot-validator --clean-logs

To stop or restart the Polkadot validator service, call, respectively

    polkadot-validator --stop
    polkadot-validator --restart

### Database Snapshot Management

The `polkadot-validator` command line utility can be used to create and restore
[database snapshots](https://wiki.polkadot.network/docs/maintain-guides-how-to-validate-polkadot#database-snapshot-services).

To create a local snapshot, call

    polkadot-validator --snapshot

After executing successfully, the location of the snapshot file will be printed to standard output.

To restore a previously create snapshot, call

    polkadot-validator --restore SNAPSHOT_URL

The `SNAPSHOT_URL` can either point to a local file (using a `file://` URI as produced by `polkadot-validator --snapshot`)
or it can point to a remote snapshot (using an `https://` URI).

_NB there is currently no tooling for uploading snapshots.  Please use the appropriate procedure to upload the snapshot to your
remote storage._

### Audit Trail

The `list-dependencies` command line utility can be used to obtain the dependencies of your validator.
The result is a list of nix store paths that can be used for further auditing.
A nix store path looks like this: /nix/store/b6gvzjyb2pg0kjfwrjmg1vfhh54ad73z-firefox-33.1/
where b6gvzjyb2pg0… is a cryptographic hash capturing the package's build dependency graph.
This result is reproducible across machines and the same input should always produce the same output.

To obtain the runtime Dependencies, call

    list-dependencies --runtime PATH

After a successful execution the result will be printed to standard output.

To obtain the buildtime dependencies, call

    list-dependencies --all PATH

After a successful execution the result will be printed to standard output.

_NB an auditable path can be obtained by e.g. `nix-build --no-out-link -A nano '<nixpkgs>'`._

### Testing

Tests are implemented using [`nix flake check`](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake-check)
To run all tests call

    nix flake check --print-build-logs

Test results are cached.  This means that subsequent calls of `nix flake check`
will only test modified code.  To force running a test without modifying code,
its test result can be deleted.
E.g. to allow rerunning `checks.x86_64-linux.polkadot-validator-two-node-network`:

    nix store delete $(nix build --no-link --print-out-paths .#checks.x86_64-linux.polkadot-validator-two-node-network)

### Docker

Building the NixOS tarball to be used in docker

    nix build .#docker

To test in docker download the [tarball](https://sporyon.io/wp-content/releases/nixos-system-x86_64-linux.tar.xz)

sha1sum: 0361767ed060a628728acfdcfd8bdf7e6a34faeb

Importing the NixOS tarball into Docker, creating an image named dotnix-docker

    docker import result/tarball/nixos-system-x86_64-linux.tar.xz dotnix-docker

Running the dotnix-docker image with systemd, starting an interactive session

    docker run --privileged -it dotnix-docker /init

Provide a node key to start the validator

    polkadot key generate-node-key | polkadot-validator --set-node-key

If everything succeeded, the validator should now show up at
[Polkadot telemtery for westend](https://telemetry.polkadot.io/#list/0xe143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e).
Search for _dotnix-docker_ there.

Additional commands to check the running validator

    systemctl status polkadot-validator.service
    journalctl -n 1000 -f -u polkadot-validator.service
