# Package management and custom tools
{ config, lib, pkgs, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;

  manpager = pkgs.writeShellScriptBin "manpager" (if isDarwin then ''
    sh -c 'col -bx | bat -l man -p'
  '' else ''
    cat "$1" | col -bx | bat --language man --style plain
  '');

  kp = pkgs.buildGoModule {
    pname = "kp";
    version = "1.0.0";
    src = ./packages/kp;
    vendorHash = null;
    preBuild = ''
      export HOME="$TMPDIR"
      export XDG_CACHE_HOME="$TMPDIR/.cache"
    '';
  };

  keychainUnlock = pkgs.writeShellScriptBin "keychain-unlock" ''
    /usr/bin/security unlock-keychain "$HOME/Library/Keychains/login.keychain-db"
  '';

in {
  home.packages = [
    pkgs.bat
    pkgs.fd
    pkgs.fzf
    pkgs.htop
    pkgs.jq
    pkgs.ripgrep
    pkgs.screenfetch
    pkgs.tree
    pkgs.watch
    pkgs.tree-sitter
    pkgs.lazygit
    pkgs.zoxide
    pkgs.gh

    pkgs.fswatch

    pkgs.direnv

    pkgs.glow

    pkgs.bun
    pkgs.uv
    pkgs.nodejs_24
    pkgs.python3
    pkgs.rustup
    kp
  ] ++ (lib.optionals isDarwin [
    pkgs.himalaya
    keychainUnlock
  ]) ++ (lib.optionals isLinux [
    pkgs.util-linux
    pkgs.bzip2
    pkgs.gmp
    pkgs.pkg-config
    pkgs.xclip
    pkgs.xsel
  ]);

  home.sessionVariables.MANPAGER = "${manpager}/bin/manpager";
}
