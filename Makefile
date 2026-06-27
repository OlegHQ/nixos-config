# Nix, nix-darwin, Home Manager, and Multipass VM helpers.

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
	@echo "Multipass VM targets:"
	@echo "  multipass-bootstrap    Create $(NAME) if missing, provision it, and load Home Manager on first boot"
	@echo "  multipass-up           Alias for non-destructive bootstrap"
	@echo "  multipass-reset        Destructively recreate the VM"
	@echo "  multipass-shell        Open fish in /home/$(MULTIPASS_USER)"
	@echo "  multipass-host-shell   Open fish in synced repo inside the VM"
	@echo "  multipass-root-shell   Open root shell for apt/systemd work"
	@echo "  multipass-nix-cache    Repair Nix cache config inside the VM"
	@echo "  multipass-hm-switch    Switch non-full Home Manager in existing VM"
	@echo "  multipass-hm-full      Switch full Home Manager in existing VM"
	@echo "  multipass-gc           Prune Nix store/generations inside VM"
	@echo "  multipass-check        Smoke-test persistent VM"
	@echo "  multipass-tailscale-up Authenticate or update Tailscale in the VM"
	@echo "  multipass-disk-grow    Increase VM disk to MULTIPASS_DISK"
	@echo "  NAME=work              Use a separate persistent VM"
	@echo "  MULTIPASS_BRIDGE=en1   Override bridged network"
	@echo "  MULTIPASS_MOUNT_HOME=1 Opt into mounting $(MULTIPASS_HOST_HOME)"
	@echo "  MULTIPASS_BOOTSTRAP_HM=always  Re-run HM during bootstrap"

include mk/multipass.mk
