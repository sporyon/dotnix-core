{ lib, pkgs }:

name: text:

let
  pname = "selinux-policy-${lib.replaceStrings ["/"] ["-"] name}";
in

pkgs.runCommand pname {
  nativeBuildInputs = [
    pkgs.checkpolicy
    pkgs.semodule-utils
  ];
  passAsFile = ["text"];
  inherit text;
} ''
  name=${lib.escapeShellArg name}
  modname=$(basename "$name")

  checkmodule -m -o "$modname".mod "$textPath"
  semodule_package -o "$modname".pp -m "$modname".mod

  install -D "$modname".pp $out/share/selinux/modules/"$name".pp
''
