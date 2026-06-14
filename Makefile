# NixOS Configuration Management
# Simple, elegant build system for multi-platform Nix configurations

NIXNAME ?= mac
UNAME := $(shell uname)
ARCH := $(shell arch)

.PHONY: switch full test build check clean prune help

# Default target
all: switch

# Apply configuration changes
switch:
ifeq ($(UNAME), Darwin)
	@echo "🍎 Switching Darwin configuration..."
	NIXPKGS_ALLOW_UNFREE=1 nix build ".#darwinConfigurations.${NIXNAME}.system" --impure
	sudo NIXPKGS_ALLOW_UNFREE=1 ./result/sw/bin/darwin-rebuild switch --flake ".#${NIXNAME}" --impure
	$(MAKE) prune
else
	@echo "🐧 Switching Home Manager configuration..."
	NIXPKGS_ALLOW_UNFREE=1 nix run nixpkgs#home-manager -- switch --flake ".#${USER}-${ARCH}" --impure
	$(MAKE) prune
endif

# Apply full configuration
full:
ifeq ($(UNAME), Darwin)
	@echo "🍎 Switching Darwin FULL configuration..."
	NIXPKGS_ALLOW_UNFREE=1 nix build ".#darwinConfigurations.${NIXNAME}-full.system" --impure
	sudo NIXPKGS_ALLOW_UNFREE=1 ./result/sw/bin/darwin-rebuild switch --flake ".#${NIXNAME}-full" --impure
	$(MAKE) prune
else
	@echo "🐧 Switching Home Manager FULL configuration..."
	NIXPKGS_ALLOW_UNFREE=1 nix run nixpkgs#home-manager -- switch --flake ".#${USER}-full-${ARCH}" --impure
	$(MAKE) prune
endif

# Test configuration without applying
test:
ifeq ($(UNAME), Darwin)
	@echo "🧪 Testing Darwin configuration..."
	NIXPKGS_ALLOW_UNFREE=1 nix build ".#darwinConfigurations.${NIXNAME}.system" --dry-run --impure
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
	NIXPKGS_ALLOW_UNFREE=1 nix flake check --impure

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf result

prune:
	@echo "🧹 Pruning old Nix generations and garbage..."
	rm -f result "$(HOME)/.config/nvim/nixos-config/result"
	-nix profile wipe-history --profile "$(HOME)/.local/state/nix/profiles/home-manager" --older-than 7d
	-nix profile wipe-history --profile "$(HOME)/.local/state/nix/profiles/profile" --older-than 7d
ifeq ($(UNAME), Darwin)
	-sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations old
	-sudo nix-env --profile /nix/var/nix/profiles/per-user/root/profile --delete-generations old
endif
	nix store gc

help:
	@echo "📚 Available targets:"
	@echo "  switch      - Apply configuration changes"
	@echo "  full        - Apply full configuration"
	@echo "  test        - Test configuration without applying"
	@echo "  build       - Build configuration"
	@echo "  check       - Validate flake configuration"
	@echo "  clean       - Clean build artifacts"
	@echo "  help          - Show this help message"
