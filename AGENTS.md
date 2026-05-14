# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Primary Development Commands
- `make switch` - Apply configuration changes (main command for deployment)
- `make test` - Test configuration without applying changes
- `make build` - Build configuration without switching
- `make check` - Validate flake configuration
- `make clean` - Clean build artifacts

### Platform-Specific Behavior
Commands automatically detect the platform:
- **macOS (Darwin)**: Uses nix-darwin with `darwin-rebuild`
- **Linux**: Uses Home Manager with architecture detection (`x86_64` or `aarch64`)

### Configuration Variables
- `NIXNAME` - Set Darwin configuration name (default: `mac`)
- `NIXPKGS_ALLOW_UNFREE=1` - Required for unfree packages (automatically set)

### Manual Platform Commands
```bash
# macOS
nix build ".#darwinConfigurations.mac.system" --impure
./result/sw/bin/darwin-rebuild switch --flake ".#mac" --impure

# Linux x86_64
nix run nixpkgs#home-manager -- switch --flake ".#snowbear-x86_64" --impure

# Linux aarch64  
nix run nixpkgs#home-manager -- switch --flake ".#snowbear-aarch64" --impure
```

## Architecture

### Multi-Platform Configuration System
This is a sophisticated Nix flake configuration supporting both macOS (via nix-darwin) and Linux (via Home Manager) with a unified codebase.

### Key Components
- **flake.nix**: Main configuration entry point with multi-platform outputs
- **darwin/**: macOS-specific system configuration using nix-darwin
- **home/**: Cross-platform Home Manager configuration
- **Makefile**: Unified build system with platform detection

### Configuration Structure
```
├── flake.nix              # Multi-platform flake with overlays
├── darwin/
│   ├── system.nix         # macOS system settings
│   └── account.nix        # User account configuration
├── home/
│   ├── default.nix        # Main Home Manager config
│   ├── helix.nix          # Helix editor configuration
│   ├── nvim.nix           # Neovim overlay with pinned plugins
│   └── configs/           # Application configuration files
└── Makefile              # Cross-platform build automation
```

### Package Management Strategy
- **Stable Base**: Uses nixos-25.05 for core system
- **Selective Unstable**: Specific packages from nixpkgs-unstable via overlays
- **Pinned Plugins**: Neovim plugins pinned to specific commits for stability
- **Platform-Specific**: Different package sets for macOS vs Linux

### Key Design Patterns
1. **Overlays**: Used extensively for bleeding-edge packages and custom Neovim setup
2. **Platform Detection**: Automatic macOS/Linux detection with appropriate package selection
3. **Modular Configuration**: Separate modules for different aspects (editor, shell, system)
4. **User Parameterization**: Single `userName` variable controls user across all configurations

### Development Environment Features
- **Primary Editor**: Neovim with extensive plugin setup and LSP support
- **Alternative Editor**: Helix with LSP support and custom language configurations
- **Shell**: Fish with fzf integration and kubectl completions
- **Terminal**: Ghostty with optimized settings
- **Version Control**: Git with sensible aliases and lazygit
- **Development Tools**: Full TypeScript, Python, OCaml, Rust toolchain
- **Cloud Tools**: AWS CLI, kubectl, Helm, k3d for Kubernetes development

### Configuration Management
- direnv integration for per-project environments
- Catppuccin theme across all applications
- Cross-platform clipboard aliases (pbcopy/pbpaste on Linux)
- Automatic kubectl completion installation

This configuration prioritizes reproducibility, performance, and cross-platform consistency while maintaining a curated set of modern development tools.

