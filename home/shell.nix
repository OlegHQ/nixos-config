# Fish, Bash, and Zoxide shell configuration
{ inputs }:
{ config, lib, pkgs, ... }:

let
  theme = import ./theme.nix;
  p = theme.palette;

  fishSources = {
    "fish-fzf" = inputs."fish-fzf";
    "fish-foreign-env" = inputs."fish-foreign-env";
  };

  gitAliases = {
    ga = "git add";
    gc = "git commit";
    gco = "git checkout";
    gcp = "git cherry-pick";
    gdiff = "git diff";
    gl = "git prettylog";
    gp = "git push";
    gs = "git status";
    gt = "git tag";
  };

  fishTheme = ''
    # Fish theme (generated from ${theme.themeFamily}/${theme.themeMode})
    set -g fish_color_normal ${p.text}
    set -g fish_color_command ${p.blue}
    set -g fish_color_param ${p.flamingo}
    set -g fish_color_keyword ${p.red}
    set -g fish_color_quote ${p.green}
    set -g fish_color_redirection ${p.pink}
    set -g fish_color_end ${p.peach}
    set -g fish_color_comment ${p.overlay2}
    set -g fish_color_error ${p.red}
    set -g fish_color_selection --background=${p.surface0}
    set -g fish_color_search_match --background=${p.surface0}
    set -g fish_color_operator ${p.pink}
    set -g fish_color_escape ${p.red}
    set -g fish_color_autosuggestion ${p.overlay1}
    set -g fish_color_cancel ${p.red}
    set -g fish_color_cwd ${p.yellow}
    set -g fish_color_user ${p.teal}
    set -g fish_color_host ${p.blue}
    set -g fish_color_status ${p.red}
    set -g fish_color_valid_path --underline

    set -g fish_pager_color_progress ${p.overlay1}
    set -g fish_pager_color_prefix ${p.pink}
    set -g fish_pager_color_completion ${p.text}
    set -g fish_pager_color_description ${p.overlay2}

    # FZF colors
    set -gx FZF_DEFAULT_OPTS "\\
    --height 40% --layout=reverse --border \\
    --color=bg+:#${p.surface0},bg:#${p.base},spinner:#${p.blue},hl:#${p.red} \\
    --color=fg:#${p.text},header:#${p.red},info:#${p.mauve},pointer:#${p.blue} \\
    --color=marker:#${p.blue},fg+:#${p.text},prompt:#${p.mauve},hl+:#${p.red}"
  '';

  fishPrompt = ''
    set -l last_status $status
    set -l ctp_lavender ${p.lavender}
    set -l ctp_blue ${p.blue}
    set -l ctp_sapphire ${p.sapphire}
    set -l ctp_teal ${p.teal}
    set -l ctp_mauve ${p.mauve}
    set -l ctp_red ${p.red}
    set -l ctp_overlay ${p.overlay1}

    echo

    if set -q VIRTUAL_ENV
        echo -n (set_color -b $ctp_mauve white)" "(basename $VIRTUAL_ENV)" "(set_color normal)" "
    end

    echo -n (set_color $ctp_overlay)(whoami)(set_color $ctp_teal)"@"(set_color $ctp_overlay)(prompt_hostname)(set_color normal)" "
    echo -n (set_color $ctp_sapphire)(prompt_pwd --full-length-dirs 2)(set_color normal)

    set -l gi (_git_info)
    test -n "$gi"; and echo -n (set_color $ctp_overlay)" · "(set_color normal)$gi

    _cmd_duration

    echo

    if test $last_status -ne 0
        echo -n (set_color $ctp_red)"⟩"(set_color normal)" "
    else
        echo -n (set_color $ctp_lavender)"⟩"(set_color normal)" "
    end
  '';

in {
  programs.bash = {
    enable = true;
    shellOptions = [ ];
    historyControl = [ "ignoredups" "ignorespace" ];
    shellAliases = gitAliases // {
      ccc = "claude --dangerously-skip-permissions";
    };
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    options = [ "--cmd" "cd" ];
  };

  programs.fish = {
    enable = true;

    loginShellInit = ''
      mkdir -p $HOME/.vim/{backup,swap,undo}
    '';

    interactiveShellInit = lib.strings.concatStrings
      (lib.strings.intersperse "\n" ([
        "set -gx PATH /nix/var/nix/profiles/default/bin $HOME/.nix-profile/bin $PATH"
        (builtins.readFile ./configs/config.fish)
        fishTheme
        "set -g SHELL ${pkgs.fish}/bin/fish"
        "fish_add_path $HOME/.local/bin"
        "command -sq npm; and npm set prefix ~/.npm-global 2>/dev/null; and fish_add_path -g $HOME/.npm-global/bin"
        "fish_add_path $HOME/.dotnet/tools"
      ]));

    shellAliases = gitAliases // {
      lg = "lazygit";
      l = "ls -la";
      ll = "ls -l";
      k = "kubectl";
      kns = "kubectl config set-context --current --namespace";
      ccc = "claude --dangerously-skip-permissions";
    };

    shellAbbrs = {
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
    };

    functions = {
      _is_slow_fs = ''
        set -l real_path (pwd -P)
        string match -q '/Volumes/*' -- $real_path
        or string match -q '/mnt/*' -- $real_path
        or string match -q '/net/*' -- $real_path
      '';

      # Branch reads .git/HEAD (microseconds). Dirty marker is served from
      # cache when present; on cache miss we sync-compute once so the marker
      # is always correct on the very first paint after cd.
      _git_info = ''
        _is_slow_fs; and return

        set -l git_dir (command git rev-parse --git-dir 2>/dev/null)
        test -z "$git_dir"; and return

        set -l branch
        if test -f "$git_dir/HEAD"
            read -l head < "$git_dir/HEAD"
            set branch (string replace 'ref: refs/heads/' ''' -- "$head")
            string match -q 'ref:*' -- "$branch"
            and set branch (command git rev-parse --short HEAD 2>/dev/null)
        end
        test -z "$branch"; and return

        set -l dirty
        if test "$_git_dirty_key" = "$PWD"
            test "$_git_dirty_value" = 1; and set dirty '+'
        else
            set -g _git_dirty_key "$PWD"
            if not command git diff --quiet HEAD 2>/dev/null
                set dirty '+'
                set -g _git_dirty_value 1
            else
                set -g _git_dirty_value 0
            end
        end

        echo -n (set_color ${p.blue})"($branch$dirty)"(set_color normal)
      '';

      # On every prompt, drain any completed background result into the cache,
      # then kick a fresh background `git diff --quiet HEAD`. This keeps the
      # cached dirty value fresh as files change within the same directory.
      _git_dirty_async = {
        body = ''
          if not set -q _git_dirty_tmpdir
              set -g _git_dirty_tmpdir (command mktemp -d)
          end
          set -l rf "$_git_dirty_tmpdir/r"

          if test -f "$rf"
              set -l raw (command cat "$rf" 2>/dev/null | string trim)
              command rm -f "$rf"
              test -n "$raw"; and set -g _git_dirty_value "$raw"
          end

          _is_slow_fs; and return

          # Skip the fork in non-git directories.
          command git rev-parse --git-dir >/dev/null 2>/dev/null; or return

          set -l target "$PWD"
          fish --no-config -c "
              cd '$target' 2>/dev/null; or exit
              if command git diff --quiet HEAD 2>/dev/null
                  command printf 0 >'$rf.tmp'
              else
                  command printf 1 >'$rf.tmp'
              end
              command mv '$rf.tmp' '$rf'
          " &
          disown 2>/dev/null
        '';
        onEvent = "fish_prompt";
      };

      _git_dirty_cleanup = {
        body = ''
          if set -q _git_dirty_tmpdir
              command rm -rf "$_git_dirty_tmpdir"
          end
        '';
        onEvent = "fish_exit";
      };

      _cmd_duration = ''
        test $CMD_DURATION -lt 1000; and return
        set -l s (math "floor($CMD_DURATION / 1000)")
        set -l m (math "floor($s / 60)")
        if test $m -gt 0
            set -l rem (math "$s % 60")
            echo -n (set_color ${p.overlay1})" "$m"m"$rem"s"(set_color normal)
        else
            echo -n (set_color ${p.overlay1})" "$s"s"(set_color normal)
        end
      '';

      fish_prompt = fishPrompt;
      fish_right_prompt = ''
        set -l last_status $status
        test $last_status -ne 0
        and echo -n (set_color ${p.red})"["$last_status"]"(set_color normal)
      '';
      fish_greeting = "";
    };

    plugins = map (n: {
      name = n;
      src = fishSources.${n};
    }) [ "fish-fzf" "fish-foreign-env" ];
  };
}
