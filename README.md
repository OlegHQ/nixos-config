# NixOS, nix-darwin, and Home Manager Configuration

This repository contains a unified Nix configuration that supports:
- **nix-darwin** (macOS, M1/M2)
- **Home Manager standalone** (Linux, e.g., Ubuntu)

> **Note:** On Ubuntu (or any non-NixOS Linux), only Home Manager standalone is supported. System-level configuration (like nixos/configuration.nix) is not possible.

## 🚀 Features
- **Unified Configuration**: Single flake for both macOS and Linux
- **Home Manager Integration**: User-level configuration management
- **Fish Shell**: Modern shell with extensive customization
- **Development Tools**: Comprehensive development environment
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

### For Ubuntu (Home Manager only)
```bash
# Install Nix with flakes enabled
sh <(curl -L https://nixos.org/nix/install)

# Install Home Manager as a standalone program
nix run github:nix-community/home-manager -- switch --flake ".#snowbear"
```

## 🏗️ Project Structure

```
.
├── flake.nix                 # Main flake configuration
├── Makefile                  # Build and management commands
├── darwin/
│   └── configuration.nix     # nix-darwin system configuration
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

3. **Switch to your configuration**:
   ```bash
   # For macOS
   make darwin-switch
   
   # For Ubuntu (Home Manager only)
   make home-switch
   ```

### Available Make Commands

#### System Management
- `make darwin-switch` - Switch to darwin configuration (macOS)
- `make home-switch`   - Switch to home-manager configuration (Linux/Ubuntu)
- `make darwin-test`   - Test darwin configuration (dry-run)
- `make darwin-build`  - Build darwin configuration

#### Updates
- `make update` - Update all flake inputs
- `make update-darwin` - Update darwin-specific inputs
- `make update-home`   - Update home-manager-specific inputs

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
```

#### For Ubuntu (Home Manager only)
```bash
# Switch user configuration
nix run github:nix-community/home-manager -- switch --flake .#snowbear
```

## ⚙️ Configuration

### System Configuration
- **macOS**: `darwin/configuration.nix`
- **Linux/Ubuntu**: Only user-level configuration via `home-manager/home.nix`

### User Configuration
User-level configuration is managed by home-manager in `home-manager/home.nix` and includes:
- **Shell**: Fish with extensive customization
- **Terminal**: Alacritty with Catppuccin theme
- **Editor**: Neovim with basic configuration
- **Development Tools**: Git, tmux, direnv, and more
- **Utilities**: fzf, bat, exa, zoxide, and starship

### Customization
1. **Modify system settings**: Edit `darwin/configuration.nix` (macOS only)
2. **Modify user settings**: Edit `home-manager/home.nix`
3. **Add packages**: Add to `home.packages`
4. **Add services**: Configure in the `services` section

## 🔧 Development

### Enter Development Shell
```bash
make shell
# or
nix develop
```

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
See `home-manager/home.nix` for the list of user packages and programs.

## 🔒 Security
- SSH key management
- GPG agent configuration
- Secure defaults

## 🎨 Theming
- **Terminal**: Alacritty with Catppuccin theme
- **Shell**: Fish with custom colors
- **Fonts**: FiraCode Nerd Font
- **Icons**: Font Awesome

## 🐛 Troubleshooting

### Common Issues
1. **Flake not found**: Ensure you're in the correct directory and flakes are enabled
2. **Permission denied**: Use `sudo` only for system-level commands (not needed for Home Manager)
3. **Build failures**: Check the configuration syntax with `make check`

### Rollback
```bash
# macOS
darwin-rebuild --rollback

# Ubuntu (Home Manager only)
home-manager switch --rollback
```

### Clean Build
```bash
make clean
make gc
# Then rebuild
```

## 📚 Resources
- [nix-darwin Documentation](https://daiderd.com/nix-darwin/manual/index.html)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)

## 🤝 Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `make check`
5. Submit a pull request

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.

---

**Note**: This configuration is designed for personal use. Please review and customize the settings, especially user names, email addresses, and system-specific configurations before deploying.
