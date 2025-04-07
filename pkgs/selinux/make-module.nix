{ lib, pkgs }:

# This is the `makeModule` function for building SELinux policy modules.
#
# The first argument to `makeModule` is the module's name.  It is either a
# plain file name like e.g. "mymodule", or the file name might be prefixed with
# some directory names like e.g. "mypolicy/mymodule".  In both cases the file
# name must correspond with the module name used in the Type Enforcement file.
#
# The second argument to `makeModule` is the module specification.  It is an
# attribute set that expects following attributes:
# - `typeEnforcement`, a string representing the Type Enforcement file
# - `fileContexts`, an optional string representing the File Contexts file
#
# For convenience, the second argument may also be string, in which case it will
# be interpreted as File Enforcement file representation.
#
name: inputSpec:

let
  pname = "selinux-policy-${lib.replaceStrings ["/"] ["-"] name}";

  spec =
    if lib.typeOf inputSpec == "string" then
      {
        typeEnforcement = inputSpec;
      }
    else
      inputSpec;
in

pkgs.runCommand pname {
  nativeBuildInputs = [
    pkgs.checkpolicy
    pkgs.semodule-utils
  ];
  passAsFile = lib.attrNames spec;

  # passAsFile-related attributes:
  fileContexts = spec.fileContexts or null;
  typeEnforcement = spec.typeEnforcement;
} ''
  name=${lib.escapeShellArg name}
  modname=$(basename "$name")

  checkmodule -m -o "$modname".mod "$typeEnforcementPath"

  semodule_package \
      -o "$modname".pp \
      -m "$modname".mod \
      ''${fileContextsPath+-f "$fileContextsPath"}

  install -D "$modname".pp $out/share/selinux/modules/"$name".pp
''
