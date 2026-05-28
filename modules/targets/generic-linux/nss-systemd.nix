{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.targets.genericLinux.nssSystemd;

  hostNssDir = pkgs.runCommand "host-libnss-systemd" { } ''
    mkdir -p $out/lib
    ln -s ${cfg.libraryPath} $out/lib/libnss_systemd.so.2
  '';

  wrap =
    drv:
    pkgs.symlinkJoin {
      name = "${drv.name}-host-nss";
      paths = [ drv ];
      nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
      postBuild = ''
        shopt -s nullglob

        # Wrap top-level executables in bin/ and libexec/ so glibc's NSS
        # search finds the host libnss_systemd.so.2 via LD_LIBRARY_PATH.
        for d in bin libexec; do
          [ -d "$out/$d" ] || continue
          for f in "$out/$d"/*; do
            [ -L "$f" ] || continue
            tgt=$(readlink -f "$f")
            [ -f "$tgt" ] && [ -x "$tgt" ] || continue
            rm "$f"
            makeWrapper "$tgt" "$f" \
              --prefix LD_LIBRARY_PATH : ${hostNssDir}/lib
          done
        done

        # systemd and dbus service files embed the unwrapped store path in
        # ExecStart=/Exec=; rewrite them so activation hits the wrappers above
        # instead of the unwrapped binary. Only files that actually reference
        # the unwrapped path are rewritten.
        for dir in share/systemd/user share/dbus-1/services share/dbus-1/system-services; do
          [ -d "$out/$dir" ] || continue
          for f in "$out/$dir"/*; do
            [ -L "$f" ] || continue
            src=$(readlink -f "$f")
            grep -q "${drv.out}" "$src" || continue
            rm "$f"
            sed "s|${drv.out}|$out|g" "$src" > "$f"
          done
        done

        shopt -u nullglob
      '';
    }
    // {
      # When the wrapped package is passed to a HM module that then calls
      # `.override` on it, forward the call to the underlying package so the
      # wrapping survives. Mirrors `targets.genericLinux.nixGL`.
      override = args: wrap (drv.override args);
    };

in
{
  options.targets.genericLinux.nssSystemd = {
    libraryPath = lib.mkOption {
      type = lib.types.str;
      default = "/usr/lib/libnss_systemd.so.2";
      example = "/usr/lib64/libnss_systemd.so.2";
      description = ''
        Path to the host's `libnss_systemd.so.2` NSS plugin, used by
        `config.lib.nssSystemd.wrap` to let nix-built binaries resolve
        users served by `systemd-homed` or `systemd`'s userdb on a
        non-NixOS host.

        The default is the standard FHS location. The wrapper is inert
        on hosts that don't have the library at the configured path —
        the dangling symlink fails to `dlopen` and NSS skips the module.
      '';
    };
  };

  config = {
    lib.nssSystemd.wrap = wrap;
  };
}
