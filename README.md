# 🚀 Elite NixOS Configuration

Welcome to my battle-tested NixOS configuration - a meticulously crafted system that bridges the gap between power and elegance. This isn't just another dotfiles repo; it's a complete ecosystem designed for developers who demand excellence.

## ⚡ Features

- **🍎 macOS Integration**: Seamless nix-darwin setup with native macOS feel
- **🐧 Linux Support**: Full Home Manager configuration for x86_64 and aarch64
- **🔧 Development Ready**: Pre-configured with modern tools and language servers
- **🎨 Beautiful UI**: Catppuccin theme across all applications
- **⚙️ Reproducible**: Flake-based configuration ensures consistency across machines
- **🚀 Performance Optimized**: Carefully selected packages from stable and unstable channels

## 🛠 Tech Stack

### Core Tools

- **Editor**: Helix (primary) + Neovim (fallback) with LSP support
- **Shell**: Fish with intelligent completions and plugins
- **Terminal**: Ghostty with optimized settings
- **Multiplexer**: tmux with pain-control and catppuccin theme
- **Version Control**: Git with sensible aliases and configuration

### Development Environment

- **Languages**: TypeScript, Python, Go
- **Monitoring**: htop, lazygit, ripgrep, fd, fzf

## 🚀 Quick Start

### macOS Setup

1. **Install Nix** using the Determinate Systems installer:

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

2. **Clone and Deploy**:

   ```bash
   git clone <your-repo-url> ~/.config/nixos
   cd ~/.config/nixos
   make switch
   ```

3. **Profit** 🎉

### Linux Setup

For Linux systems, use Home Manager directly:

```bash
# For x86_64 systems
nix run nixpkgs#home-manager -- switch --flake .#snowbear-x86_64

# For ARM64 systems
nix run nixpkgs#home-manager -- switch --flake .#snowbear-aarch64
```

## 🔧 Configuration Structure

```
├── flake.nix              # Main flake configuration
├── darwin/                # macOS-specific settings
│   ├── system.nix         # System-level configuration
│   └── account.nix        # User account setup
├── home/                  # Home Manager configuration
│   ├── default.nix        # Main home configuration
│   ├── editor.nix         # Neovim configuration
│   └── configs/           # Application configs
└── Makefile              # Build automation
```

## 🎯 Philosophy

This configuration follows several key principles:

1. **Minimalism**: Only include what you actually use
2. **Performance**: Prefer fast, native tools over bloated alternatives
3. **Consistency**: Unified theme and keybindings across all applications
4. **Reliability**: Stable base with carefully selected unstable packages
5. **Productivity**: Optimized for rapid development workflows

## 🔍 Advanced Usage

### Custom Builds

```bash
# Test configuration without switching
make test

# Build specific configuration
NIXNAME=mac make switch
```

### Development Workflow

The configuration includes direnv integration for per-project environments:

```bash
# In any project directory
echo "use flake" > .envrc
direnv allow
```

## 🤝 Contributing

Found a bug or have an improvement? Feel free to open an issue or submit a PR. This configuration is constantly evolving based on real-world usage.

## ⚠️ Disclaimer

This is a personal configuration optimized for my workflow. While you're welcome to use it as inspiration, I recommend understanding each component before blindly copying. Your mileage may vary.

## 📜 License

MIT License - Use at your own risk and have fun! 🎉
