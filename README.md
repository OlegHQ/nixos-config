# NixOS and nix-darwin Configuration

This repository contains a unified Nix configuration that supports both **NixOS** (Linux) and **nix-darwin** (macOS) systems using flakes and home-manager.

## 🚀 Features

- **Unified Configuration**: Single flake for both Linux and macOS
- **Home Manager Integration**: User-level configuration management
- **Fish Shell**: Modern shell with extensive customization
- **Development Tools**: Comprehensive development environment
- **System-specific Optimizations**: Tailored for each platform
- **Easy Management**: Makefile with convenient commands

## 📋 Prerequisites

### For macOS (nix-darwin)
```bash
# Install Nix with flakes enabled
sh <(curl -L https://nixos.org/nix/install) --daemon

# Install nix-darwin
nix build nix-darwin#aarch64-darwin.system --extra-experimental-features nix-command --extra-experimental-features flakes
./result/sw/bin/darwin-rebuild switch
```

### For Linux (NixOS)
```bash
# Install NixOS with flakes enabled
# Follow the NixOS installation guide and enable flakes in configuration.nix
```

## 🏗️ Project Structure

```
.
├── flake.nix                 # Main flake configuration
├── Makefile                  # Build and management commands
├── darwin/
│   └── configuration.nix     # nix-darwin system configuration
├── nixos/
│   └── configuration.nix     # NixOS system configuration
└── home-manager/
    └── home.nix             # Home manager user configuration
```

## 🛠️ Usage

### Quick Start

1. **Clone and enter the repository**:
   ```bash
   git clone <your-repo-url>
   cd nixos-config
   ```

2. **View available commands**:
   ```bash
   make help
   ```

3. **Switch to your system configuration**:
   ```bash
   # For macOS
   make darwin-switch
   
   # For Linux
   make linux-switch
   
   # Or use auto-detection
   make switch
   ```

### Available Make Commands

#### System Management
- `make darwin-switch` - Switch to darwin configuration
- `make linux-switch` - Switch to linux configuration
- `make darwin-test` - Test darwin configuration (dry-run)
- `make linux-test` - Test linux configuration (dry-run)
- `make darwin-build` - Build darwin configuration
- `make linux-build` - Build linux configuration

#### Updates
- `make update` - Update all flake inputs
- `make update-darwin` - Update darwin-specific inputs
- `make update-linux` - Update linux-specific inputs

#### Utilities
- `make gc` - Garbage collect old generations
- `make clean` - Clean build artifacts
- `make format` - Format all Nix files
- `make check` - Check Nix syntax and formatting
- `make shell` - Enter development shell
- `make info` - Show system information

### Manual Commands

#### For macOS
```bash
# Switch configuration
darwin-rebuild switch --flake .#macbook

# Test configuration
darwin-rebuild build --flake .#macbook

# Update inputs
nix flake update
```

#### For Linux
```bash
# Switch configuration
sudo nixos-rebuild switch --flake .#ubuntu

# Test configuration
sudo nixos-rebuild build --flake .#ubuntu

# Update inputs
nix flake update
```

## ⚙️ Configuration

### System Configuration

The system configurations are located in:
- **macOS**: `darwin/configuration.nix`
- **Linux**: `nixos/configuration.nix`

### User Configuration

User-level configuration is managed by home-manager in `home-manager/home.nix` and includes:

- **Shell**: Fish with extensive customization
- **Terminal**: Alacritty with Catppuccin theme
- **Editor**: Neovim with basic configuration
- **Development Tools**: Git, tmux, direnv, and more
- **Utilities**: fzf, bat, exa, zoxide, and starship

### Customization

1. **Modify system settings**: Edit the appropriate `configuration.nix` file
2. **Modify user settings**: Edit `home-manager/home.nix`
3. **Add packages**: Add to `environment.systemPackages` or `home.packages`
4. **Add services**: Configure in the `services` section

## 🔧 Development

### Enter Development Shell
```bash
make shell
# or
nix develop
```

This provides a development environment with:
- Nix development tools (nixpkgs-fmt, statix, deadnix)
- Common development utilities
- Git and version control tools

### Format Code
```bash
make format
# or
nix fmt
```

### Check Configuration
```bash
make check
# or
nix flake check
```

## 📦 Included Software

### Core Utilities
- Git, vim, curl, wget, jq
- ripgrep, fd, tree, htop
- bat, exa, fzf, zoxide

### Development Tools
- GCC, Clang, CMake, pkg-config
- Rust, Node.js, Python, Go
- Docker, direnv

### Shell Environment
- Fish shell with extensive customization
- Starship prompt
- Tmux with plugins
- Neovim with basic configuration

### GUI Applications (Linux)
- Firefox, VS Code
- Discord, Slack, Spotify
- Docker Desktop, Postman

### macOS Applications
- Homebrew integration
- Mac App Store apps
- System preferences optimization

## 🔒 Security

- SSH key management
- GPG agent configuration
- Firewall settings
- Secure defaults

## 🎨 Theming

- **Terminal**: Alacritty with Catppuccin theme
- **Shell**: Fish with custom colors
- **Fonts**: FiraCode Nerd Font
- **Icons**: Font Awesome

## 🐛 Troubleshooting

### Common Issues

1. **Flake not found**: Ensure you're in the correct directory and flakes are enabled
2. **Permission denied**: Use `sudo` for NixOS commands
3. **Build failures**: Check the configuration syntax with `make check`

### Rollback

```bash
# macOS
darwin-rebuild --rollback

# Linux
sudo nixos-rebuild --rollback
```

### Clean Build

```bash
make clean
make gc
# Then rebuild
```

## 📚 Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [nix-darwin Documentation](https://daiderd.com/nix-darwin/manual/index.html)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `make check` and `make test`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Note**: This configuration is designed for personal use. Please review and customize the settings, especially user names, email addresses, and system-specific configurations before deploying.
