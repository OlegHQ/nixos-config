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

  dumptty = pkgs.writeShellScriptBin "dumptty" ''
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    TMPFILE="/tmp/terminal_dump_$TIMESTAMP.txt"

    if [ -n "$TMUX" ]; then
        echo "Dumping tmux pane history to $TMPFILE"
        tmux capture-pane -pS - > "$TMPFILE"
    else
        echo "dumptty only works inside tmux!"
        echo "Regular terminals don't expose their scrollback buffer to programs."
        echo ""
        echo "Suggestions:"
        echo "  - Use tmux for terminal session management"
        echo "  - Or manually copy/paste the content you need"
        exit 1
    fi

    echo "Saved terminal dump to: $TMPFILE"
    nvim '+normal G' "$TMPFILE"
  '';

  kp = pkgs.buildGoModule {
    pname = "kp";
    version = "1.0.0";
    src = ./packages/kp;
    vendorHash = null;
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
    pkgs.tree
    pkgs.watch
    pkgs.tree-sitter
    pkgs.lazygit
    pkgs.zoxide
    pkgs.gh
    pkgs.glab
    pkgs.bun
    pkgs.mongosh

    pkgs.go
    pkgs.air
    pkgs.templ

    pkgs.uv

    pkgs.fswatch

    pkgs.direnv

    pkgs.glow

    pkgs.python3
    pkgs.nodejs_24

    dumptty
    kp
  ] ++ (lib.optionals isDarwin [
    pkgs.himalaya
    keychainUnlock
  ]) ++ (lib.optionals isLinux [
    pkgs.rustup
    pkgs.util-linux
    pkgs.bzip2
    pkgs.gmp
    pkgs.pkg-config
    pkgs.xclip
    pkgs.xsel
  ]);

  home.sessionVariables.MANPAGER = "${manpager}/bin/manpager";
}
