# Main prompt - minimal, stylish, informative
# Layout:
#   user@host ~/projects/repo · (main+) 3s
#   ⟩

set -l last_status $status

# Catppuccin Macchiato colors
set -l ctp_lavender b7bdf8
set -l ctp_blue 8aadf4
set -l ctp_sapphire 7dc4e4
set -l ctp_teal 8bd5ca
set -l ctp_mauve c6a0f6
set -l ctp_red ed8796
set -l ctp_overlay 8087a2

# Blank line before prompt
echo

# Virtual env indicator
if set -q VIRTUAL_ENV
    echo -n (set_color -b $ctp_mauve white)" "(basename $VIRTUAL_ENV)" "(set_color normal)" "
end

# user@host (muted)
echo -n (set_color $ctp_overlay)(whoami)(set_color $ctp_teal)"@"(set_color $ctp_overlay)(prompt_hostname)(set_color normal)" "

# Working directory (Catppuccin sapphire)
echo -n (set_color $ctp_sapphire)(prompt_pwd --full-length-dirs 2)(set_color normal)

# Git info
set -l gi (_git_info)
test -n "$gi"; and echo -n (set_color $ctp_overlay)" · "(set_color normal)$gi

# Command duration
_cmd_duration

# Newline and prompt char
echo

# Prompt char: red on error, lavender on success
if test $last_status -ne 0
    echo -n (set_color $ctp_red)"⟩"(set_color normal)" "
else
    echo -n (set_color $ctp_lavender)"⟩"(set_color normal)" "
end
