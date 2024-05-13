# dotnix &middot; [![GitHub license](https://img.shields.io/badge/license-GPL3%2FApache2-blue)](#LICENSE) [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](docs/CONTRIBUTING.adoc)

# dotnix-core
Dotnix is a collection of Nix packages and NixOS modules designed for creating and managing Polkadot/Kusama Validator Nodes, emphasizing both security and ease of use.

### Overview

Dotnix is a collection of Nix packages, NixOS modules, and a commandline tool designed for compiling Polkadot validators, managing their deployments while emphasizing both security and ease of use.

#### Security / Auditability

Dotnix aims to minimize the attack surface of a Polkadot node by only enabling services explicitly declared in Nix configuration files. This approach not only enhances its security but also ensures a minimalistic machine setup where components run solely when they are declared, further bolstering the node's defense against potential threats.

Auditability is facilitated by the way the Nix package manager builds packages using only predetermined build inputs, and by producing packages that never change once they have been built. During the build process, there is no arbitrary network access nor access to any file that hasn't been specified explicitly.
Each package is stored in its own directory, like e.g. `/nix/store/nawl092prjblbhvv16kxxbk6j9gkgcqm-git-2.14.1`.

The directory name consists of a unique identifier, the package name, and its version. The name and version are included only for convenience. The identifier captures all of the package's dependencies, i.e. it's a cryptographic hash of its build dependency graph, including all source files, all other packages used directly or indirectly by the build process, and any other detail like e.g. compiler flags.

With Nix, the entire configuration of the Polkadot validator node can be observed at a glance for both the executing system and the validator configurations. This clarity is invaluable for those responsible maintaining these systems.

#### Ease of Use

To simplify testing and operation of the Polkadot validator, Dotnix provides easy access to an array of tools built on top of Nix's tooling such as [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) and [nixos-generators](https://github.com/nix-community/nixos-generators) which will enable users of the Dotnix to iterate quickly over their staking infrastructure. This allows to deploy Polkadot validators to a variety of cloud providers as well as self-hosted virtual machines. It can even spawn local virtual machine instances directly for any given NixOS configuration, providing a convenient way to for testing. A command line tool will be developed to add even more management capabilities of validators that have been deployed using the initial set of tools.

# 📚 Wiki:
Dotnix Quickstart Guide
TBA
# 
