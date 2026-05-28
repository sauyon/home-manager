{ config, ... }:
{
  time = "2026-05-28T22:36:50+00:00";
  condition = config.targets.genericLinux.enable;
  message = ''
    A new `config.lib.nssSystemd.wrap` helper wraps a derivation so its
    binaries can `dlopen` the host's `libnss_systemd.so.2` plugin.
    Required on non-NixOS hosts whose users are served by `systemd-homed`
    or `systemd`'s userdb, since nix's glibc only searches the nix store
    for NSS plugins. Apply per-package, for example:

        services.emacs.package = config.lib.nssSystemd.wrap pkgs.emacs;

    The library path defaults to `/usr/lib/libnss_systemd.so.2` and can
    be overridden via
    [](#opt-targets.genericLinux.nssSystemd.libraryPath).
  '';
}
