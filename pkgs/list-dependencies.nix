{ pkgs }:

pkgs.writers.writeDashBin "list-dependencies" ''
  # usage: list-dependecies {--all,--runtime} PATH

  set -efu

  main() {
    case $1 in
      --all)
        shift
        all_dependencies "$@"
        ;;
      --runtime)
        shift
        runtime_dependencies "$@"
        ;;
      *)
        echo "$0: error: bad argument: $1" >&2
        exit 1
    esac
  }

  # all_dependencies [STORE_PATH...]
  # list all build time dependencies
  all_dependencies() {
    ${pkgs.nix}/bin/nix derivation show -r "$@" |
    ${pkgs.jq}/bin/jq -r '
      [
        .. |
        select(type == "string" and test("^/nix/store/[^/ ]+$"))
      ] |
      sort |
      unique[]
    '
  }

  # runtime_dependencies [STORE_PATH...]
  # query of the runtime dependencies
  runtime_dependencies() {
    ${pkgs.nix}/bin/nix-store --query --requisites "$@" |
    ${pkgs.coreutils}/bin/sort -u
  }

  main "$@"
''
