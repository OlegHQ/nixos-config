# Fish Shell Configuration

Ultra-fast, async prompt with Catppuccin Latte theme and power features.

## Keybindings

| Key | Action |
|-----|--------|
| `Ctrl+R` | Fuzzy history search (fzf) |
| `Ctrl+T` | Fuzzy file search (fzf + fd) |
| `Alt+C` | Fuzzy directory jump (fzf + fd) |
| `Ctrl+Z` | Toggle background/foreground job |
| `Alt+.` | Insert last argument from history |
| `Tab` | Autocomplete with suggestions |

## Abbreviations

Abbreviations expand inline when you press space - faster than aliases and visible in history.

| Abbr | Expands to |
|------|------------|
| `ga` | `git add` |
| `gc` | `git commit` |
| `gco` | `git checkout` |
| `gcp` | `git cherry-pick` |
| `gdiff` | `git diff` |
| `gl` | `git prettylog` |
| `gp` | `git push` |
| `gs` | `git status` |
| `gt` | `git tag` |
| `k` | `kubectl` |
| `kns` | `kubectl config set-context --current --namespace` |
| `lg` | `lazygit` |
| `zj` | `zellij` |
| `l` | `ls -la` |
| `ll` | `ls -l` |
| `..` | `cd ..` |
| `...` | `cd ../..` |
| `....` | `cd ../../..` |

## Directory Navigation (Zoxide)

Smart directory jumping that learns from your usage:

```fish
cd foo          # Jump to most frequent directory matching "foo"
cd foo bar      # Jump to directory matching both "foo" and "bar"
cdi             # Interactive directory picker with fzf
cdi foo         # Interactive picker filtered by "foo"
```

Zoxide tracks your most visited directories and ranks them by frequency and recency.

## Prompt

```
~/projects/myrepo (main+) 3s
>
```

| Component | Description |
|-----------|-------------|
| `~/projects/myrepo` | Current directory (yellow) |
| `(main+)` | Git branch (blue), `+` indicates uncommitted changes |
| `3s` | Command duration (shown for commands >1s) |
| `>` | Prompt char (blue on success, red on error) |
| `[127]` | Exit code in right prompt (only shown on error) |

The git status is **async** - the prompt appears instantly, never blocking even in large repos.

## Performance Features

- **Async git status**: Uses `fish-async-prompt` - prompt never blocks waiting for git
- **Guarded homebrew init**: Only runs once per session, not every prompt
- **Lazy-loaded opam**: OCaml environment only loads when first used
- **Fast git detection**: Reads `.git/HEAD` directly instead of running git commands
- **Skip slow mounts**: Git and direnv skip `/Volumes/`, `/mnt/`, `/net/` paths

## Theme: Catppuccin Latte

Consistent light theme across all tools:

| Element | Color |
|---------|-------|
| Commands | Blue `#1e66f5` |
| Parameters | Pink `#dd7878` |
| Strings | Green `#40a02b` |
| Errors | Red `#d20f39` |
| Comments | Gray `#8c8fa1` |
| Autosuggestions | Muted `#9ca0b0` |

## Customization

### Add your own abbreviations

In `home/default.nix`:

```nix
programs.fish.shellAbbrs = {
  myabbr = "my full command";
};
```

### Change prompt colors

In `home/configs/config.fish`, modify the Catppuccin color variables:

```fish
set -l ctp_blue 1e66f5    # Change to your preferred color
set -l ctp_yellow df8e1d
set -l ctp_red d20f39
```

### Add keybindings

In `home/configs/config.fish`, add to `fish_user_key_bindings`:

```fish
function fish_user_key_bindings
    bind \ck 'clear; commandline -f repaint'  # Ctrl+K to clear
end
```

## Files

| File | Purpose |
|------|---------|
| `home/configs/config.fish` | Main fish configuration |
| `home/default.nix` | Home Manager fish settings, abbreviations, plugins |
| `flake.nix` | Fish plugin sources |
