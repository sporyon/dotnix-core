#! /bin/sh
set -efu

# setup the datastructure to use during execution
workdir=$(mktemp --tmpdir --directory audit_validator.XXXX)
readonly workdir
trap cleanup EXIT
cleanup() {
  cd /
  rm -fR "$workdir"
}
cd "$workdir"

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
  if test $# -gt 0; then
    for arg; do
      echo "$arg"
    done
  else
    cat
  fi |
  while read -r path; do
    if path_has_been_seen "$path"; then
      continue
    else
      mark_path_as_seen "$path"
    fi
    case $path in
      *.drv)
        drv=$path
        ;;
      *)
        # repairing broken paths
        echo "$path"
        if ! test -s "$path"; then 
          nix store repair "$path"
        fi 
        # realizing paths
        if ! test -e "$path"; then
          nix-store --realise "$path"
        fi
        # query derivers
        drv=$(nix-store --query --deriver "$path")
        if test "$drv" = unknown-deriver; then
          # path must be part of some nix repository
          continue
        fi
        ;;
    esac
    parse_drv "$drv" | all_dependencies
  done
}

# runtime_dependencies [STORE_PATH...]
# query of the runtime dependencies
runtime_dependencies() {
  nix-store --query --requisites "$1"
}
# comparing paths and marking them as seen if they match
path_has_been_seen() {
  test -e "$workdir/seen/$(urlencode "$1")"
}
mark_path_as_seen() {
  mkdir -p "$workdir/seen"
  touch "$workdir/seen/$(urlencode "$1")"
}

# usage: parse_drv DRV_PATH
# parsing derivers
parse_drv() {
  cat "$1" | tr ', "\\' \\n | sed -nr 's:^(/nix/store/[^/]+).*:\1:p' | sort -u
}

main "$@"


