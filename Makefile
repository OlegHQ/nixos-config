# Nix, nix-darwin, Home Manager, and Apple container helpers.

NIXNAME ?= mac
UNAME := $(shell uname)
ARCH := $(shell arch)
NIX_FALLBACK ?= 0
NIX_EXTRA_FLAGS ?=
NIX_FALLBACK_FLAGS := $(if $(filter 1 true yes,$(NIX_FALLBACK)),--fallback,)
NIX_COMMON_FLAGS := $(NIX_FALLBACK_FLAGS) $(NIX_EXTRA_FLAGS)
IS_ROOT := $(shell [ "$$(id -u)" -eq 0 ] && echo 1 || echo 0)

.PHONY: all switch full test build check clean prune help

define ensure-not-root
	@if [ "$(IS_ROOT)" = 1 ]; then \
		echo "Do not run this target with sudo; it invokes sudo only for the darwin-rebuild step." >&2; \
		exit 1; \
	fi
endef

all: switch

switch:
	$(ensure-not-root)
ifeq ($(UNAME), Darwin)
	@echo "Switching Darwin configuration $(NIXNAME)..."
	NIXPKGS_ALLOW_UNFREE=1 nix build ".#darwinConfigurations.$(NIXNAME).system" --impure $(NIX_COMMON_FLAGS)
	sudo NIXPKGS_ALLOW_UNFREE=1 ./result/sw/bin/darwin-rebuild switch --flake ".#$(NIXNAME)" --impure
	$(MAKE) prune
else
	@echo "Switching Home Manager configuration..."
	NIXPKGS_ALLOW_UNFREE=1 nix run $(NIX_COMMON_FLAGS) nixpkgs#home-manager -- switch --flake ".#$(USER)-$(ARCH)" --impure
	$(MAKE) prune
endif

full:
	$(ensure-not-root)
ifeq ($(UNAME), Darwin)
	@echo "Switching Darwin full configuration $(NIXNAME)-full..."
	NIXPKGS_ALLOW_UNFREE=1 nix build ".#darwinConfigurations.$(NIXNAME)-full.system" --impure $(NIX_COMMON_FLAGS)
	sudo NIXPKGS_ALLOW_UNFREE=1 ./result/sw/bin/darwin-rebuild switch --flake ".#$(NIXNAME)-full" --impure
	$(MAKE) prune
else
	@echo "Switching Home Manager full configuration..."
	NIXPKGS_ALLOW_UNFREE=1 nix run $(NIX_COMMON_FLAGS) nixpkgs#home-manager -- switch --flake ".#$(USER)-full-$(ARCH)" --impure
	$(MAKE) prune
endif

test:
	$(ensure-not-root)
ifeq ($(UNAME), Darwin)
	@echo "Testing Darwin configuration..."
	NIXPKGS_ALLOW_UNFREE=1 nix build ".#darwinConfigurations.$(NIXNAME).system" --dry-run --impure $(NIX_COMMON_FLAGS)
else
	@echo "Testing Home Manager configuration..."
	NIXPKGS_ALLOW_UNFREE=1 nix run $(NIX_COMMON_FLAGS) nixpkgs#home-manager -- build --flake ".#$(USER)-$(ARCH)" --dry-run --impure
endif

build:
	$(ensure-not-root)
ifeq ($(UNAME), Darwin)
	NIXPKGS_ALLOW_UNFREE=1 nix build ".#darwinConfigurations.$(NIXNAME).system" --impure $(NIX_COMMON_FLAGS)
else
	NIXPKGS_ALLOW_UNFREE=1 nix build ".#homeConfigurations.$(USER)-$(ARCH).activationPackage" --impure $(NIX_COMMON_FLAGS)
endif

check:
	$(ensure-not-root)
	@echo "Checking flake configuration..."
	NIXPKGS_ALLOW_UNFREE=1 nix flake check --impure $(NIX_COMMON_FLAGS)

clean:
	@echo "Cleaning build artifacts..."
	rm -rf result

prune:
	@echo "Pruning old Nix generations and garbage..."
	rm -f result "$(HOME)/.config/nvim/nixos-config/result"
	-nix profile wipe-history --profile "$(HOME)/.local/state/nix/profiles/home-manager" --older-than 7d
	-nix profile wipe-history --profile "$(HOME)/.local/state/nix/profiles/profile" --older-than 7d
ifeq ($(UNAME), Darwin)
	-sudo HOME=/var/root nix-env --profile /nix/var/nix/profiles/system --delete-generations old
	-sudo HOME=/var/root nix-env --profile /nix/var/nix/profiles/per-user/root/profile --delete-generations old
endif
	nix store gc

help:
	@echo "Common targets:"
	@echo "  switch                 Apply normal host configuration"
	@echo "  full                   Apply full host configuration"
	@echo "  test                   Dry-run host configuration"
	@echo "  build                  Build host configuration"
	@echo "  check                  Validate flake"
	@echo "  clean                  Remove local result symlink"
	@echo "  prune                  Remove old Nix generations and garbage"
	@echo "  NIX_FALLBACK=1         Build from source if substitutes fail"
	@echo "  NIX_EXTRA_FLAGS=...    Pass extra flags to nix commands"
	@echo
	@echo "Apple container targets:"
	@echo "  container-image        Build and load base OCI image"
	@echo "  container-bootstrap    Build image and create machine if missing"
	@echo "  container-up           Alias for non-destructive bootstrap"
	@echo "  container-reset        Destructively recreate machine from image"
	@echo "  container-rebuild      Destructive rebuild; set NAME=name for custom machine"
	@echo "  container-shell        Open fish in /home/$(CONTAINER_USER)"
	@echo "  container-host-shell   Open fish in mounted host home"
	@echo "  container-root-shell   Open root shell for apk/system work"
	@echo "  container-nix-cache    Repair Nix cache config inside machine"
	@echo "  container-hm-switch    Switch non-full Home Manager in existing machine"
	@echo "  container-hm-full      Switch full Home Manager in existing machine"
	@echo "  container-gc           Prune Nix store/generations inside machine"
	@echo "  container-check        Smoke-test persistent machine"
	@echo "  container-direct-check Smoke-test image without a machine"

include mk/container.mk
