{ lib, pkgs }:

name:
{ base ? null
, packages
, mode ? "permissive"
, store ? "targeted"
, policyVersion ? 33
}:

pkgs.runCommand name {
  passwd = ''
    root:x:0:0::/root:/bin/sh
  '';
  selinuxConfig = ''
    SELINUX=${mode}
    SELINUXTYPE=${store}
  '';
  semanageConf = ''
    compiler-directory = ${pkgs.policycoreutils}/libexec/selinux/hll
    policy-version = ${toString policyVersion}

    [load_policy]
    path = ${pkgs.policycoreutils}/bin/load_policy
    [end]

    [sefcontext_compile]
    path = ${pkgs.libselinux}/bin/sefcontext_compile
    args = $@
    [end]

    [setfiles]
    path = ${pkgs.policycoreutils}/bin/setfiles
    args = -q -c $@ $<
    [end]
  '';
  passAsFile = [
    "passwd"
    "selinuxConfig"
    "semanageConf"
  ];
  meta = {
    inherit mode;
    inherit store;
    inherit policyVersion;
  };
} ''
  mkdir -p etc/selinux lib/selinux

  ${lib.optionalString (base != null) ''
    cp -r ${base}/etc/selinux/${base.meta.store} etc/selinux/${store}
    cp -r ${base}/lib/selinux/${base.meta.store} lib/selinux/${store}
    find . -type d -exec chmod 0755 {} +
    find . -type f -exec chmod 0644 {} +
  ''}

  cp "$selinuxConfigPath" etc/selinux/config
  cp "$semanageConfPath" etc/selinux/semanage.conf

  ${lib.concatMapStringsSep "\n" (package: /* TODO all in one xargs */ ''
    echo Installing package ${package} >&2
    find ${package}/share/selinux -name \*.cil -o -name \*.pp |
    xargs --no-run-if-empty \
        ${pkgs.proot}/bin/proot \
            -0 \
            -b etc:/etc \
            -b lib:/lib \
            -b "$passwdPath":/etc/passwd \
            ${pkgs.policycoreutils}/bin/semodule \
                --verbose \
                --noreload \
                --store-path lib/selinux \
                --install
    if test -d ${package}/etc/selinux; then
      ${pkgs.rsync}/bin/rsync -r ${package}/etc/selinux/ etc/selinux
    fi
  '') packages}

  rm .attr-*
  cp -r . $out
''
