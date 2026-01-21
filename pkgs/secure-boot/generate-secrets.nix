{ pkgs }:

pkgs.writers.writeDashBin "generate-secrets" ''
  # NAME
  #     generate-secrets - generate secrets lo|
  #
  # SYNOPSIS
  #     generate-secrets [--autocommit] RECIPIENTS_FILE OUTPUT
  #
  # DESCRIPTION
  #     Generates Secure Boot secrets, and outputs an age-encrypted tarball.
  #
  #     Encrypt to the recipients listed in the file at RECIPIENTS_FILE, one
  #     recipient per line.  See age(1) for details.
  #
  #     OUTPUT specifies the path for the generated, encrypted tarball.
  #
  # EXAMPLE
  #     generate-secrets ~/.ssh/id_ed25519.pub tmp/sbctl-keys.tar.gz.age
  #

  set -efu

  RECIPIENTS_FILE=$(${pkgs.coreutils}/bin/realpath "$1")
  OUTPUT_PATH=$(${pkgs.coreutils}/bin/realpath "$2")

  # Check conditions
  # RRR
  # TODO check all preconditions
  # 1. assert that RECIPIENTS_FILE exists (bonus level: korrect format)
  # 2.1 does OUTPUT_PATH already exist? if yes, bail out unless --force is specified
  # 2.2 maybe validate that OUTPUT_PATH looks right, i.e. *.tar.gz.age
  case $OUTPUT_PATH in
    *.tar.gz.age)
      : # ok
      ;;
    *)
      echo "error: output path ($OUTPUT_PATH) looks bad; doesn't end in .tar.gz.age" >&2
      exit 1
      ;;
  esac
  # 3.1 if --autocommit is specified, validate that OUTPUT_PATH is within a git directory
  if ! OUTPUT_GIT_TOPLEVEL=$(${pkgs.git}/bin/git -C "$(${pkgs.coreutils}/bin/dirname "$OUTPUT_PATH")" rev-parse --show-toplevel >/dev/null); then
    echo "error: output ($OUTPUT_PATH) not within a git repository" >&2
    exit 1
  fi
  # 3.2 verify that there isn't anything staged!!

  # Generate output
  (
    workdir=$(mktemp --tmpdir --directory generate-secrets.XXXX)
    trap 'cd / && ${pkgs.coreutils}/bin/rm -R "$workdir"' EXIT
    cd "$workdir"

    ${pkgs.sbctl}/bin/sbctl create-keys --disable-landlock --export keys
    ${pkgs.gnutar}/bin/tar -czf keys.tar.gz keys
    ${pkgs.age}/bin/age -e -a -R "$RECIPIENTS_FILE" -o keys.tar.gz.age keys.tar.gz

    ${pkgs.coreutils}/bin/mv keys.tar.gz.age "$OUTPUT_PATH"
  )

  # Commit result
  # RRR
  # TODO commit only when --autocommit was specified
  echo TODO ${pkgs.git}/bin/git -C "$OUTPUT_GIT_TOPLEVEL" add "$OUTPUT_PATH"
  echo TODO ${pkgs.git}/bin/git -C "$OUTPUT_GIT_TOPLEVEL" commit -m "$commit_message"
''
