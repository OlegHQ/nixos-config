# NixOS Configuration Management
# Simple, elegant build system for multi-platform Nix configurations

NIXNAME ?= mac
UNAME := $(shell uname)
ARCH := $(shell arch)

.PHONY: switch full test build check clean help

# Default target
all: switch

# Apply configuration changes
switch:
ifeq ($(UNAME), Darwin)
	@echo "🍎 Switching Darwin configuration..."
	NIXPKGS_ALLOW_UNFREE=1 nix build ".#darwinConfigurations.${NIXNAME}.system" --impure
	NIXPKGS_ALLOW_UNFREE=1 ./result/sw/bin/darwin-rebuild switch --flake ".#${NIXNAME}" --impure
else
	@echo "🐧 Switching Home Manager configuration..."
	NIXPKGS_ALLOW_UNFREE=1 nix run nixpkgs#home-manager -- switch --flake ".#${USER}-${ARCH}" --impure
endif

# Apply full configuration (includes nvimconf)
full:
ifeq ($(UNAME), Darwin)
	@echo "🍎 Switching Darwin FULL configuration..."
	NIXPKGS_ALLOW_UNFREE=1 nix build ".#darwinConfigurations.${NIXNAME}-full.system" --impure
	NIXPKGS_ALLOW_UNFREE=1 ./result/sw/bin/darwin-rebuild switch --flake ".#${NIXNAME}-full" --impure
else
	@echo "🐧 Switching Home Manager FULL configuration..."
	NIXPKGS_ALLOW_UNFREE=1 nix run nixpkgs#home-manager -- switch --flake ".#${USER}-full-${ARCH}" --impure
endif

# Test configuration without applying
test:
ifeq ($(UNAME), Darwin)
	@echo "🧪 Testing Darwin configuration..."
	nix build ".#darwinConfigurations.${NIXNAME}.system" --dry-run
else
	@echo "🧪 Testing Home Manager configuration..."
	nix run nixpkgs#home-manager -- build --flake ".#${USER}-${ARCH}" --dry-run
endif

# Build configuration
build:
ifeq ($(UNAME), Darwin)
	NIXPKGS_ALLOW_UNFREE=1 nix build ".#darwinConfigurations.${NIXNAME}.system" --impure
else
	NIXPKGS_ALLOW_UNFREE=1 nix build ".#homeConfigurations.${USER}-${ARCH}.activationPackage" --impure
endif

# Validate flake
check:
	@echo "✅ Checking flake configuration..."
	nix flake check

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf result

# Show help
help:
	@echo "📚 Available targets:"
	@echo "  switch  - Apply configuration changes"
	@echo "  full    - Apply full configuration (includes nvimconf)"
	@echo "  test    - Test configuration without applying"
	@echo "  build   - Build configuration"
	@echo "  check   - Validate flake configuration"
	@echo "  clean   - Clean build artifacts"
	@echo "  help    - Show this help message"

