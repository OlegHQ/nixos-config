# NixOS Configuration Management
# Simple, elegant build system for multi-platform Nix configurations

NIXNAME ?= mac
UNAME := $(shell uname)
ARCH := $(shell arch)
CONTAINER_USER ?= $(shell id -un)
CONTAINER_UID ?= $(shell id -u)
CONTAINER_GID ?= $(shell id -g)
CONTAINER_NAME ?= snowbear-dev
CONTAINER_IMAGE ?= local/snowbear-dev:latest
CONTAINER_HOME_MOUNT ?= rw
CONTAINER_HOST_HOME ?= /Users/$(CONTAINER_USER)
CONTAINER_ARCH ?= arm64
CONTAINER_SYSTEM ?= aarch64-linux
CONTAINER_BUILDER_IMAGE ?= nixos/nix:2.24.10
CONTAINER_IMAGE_WORDS := $(subst :, ,$(CONTAINER_IMAGE))
CONTAINER_IMAGE_NAME ?= $(word 1,$(CONTAINER_IMAGE_WORDS))
CONTAINER_IMAGE_TAG ?= $(or $(word 2,$(CONTAINER_IMAGE_WORDS)),latest)
CONTAINER_IMAGE_ARCHIVE ?= container/$(CONTAINER_NAME).oci.tar
CONTAINER_BUILD_CPUS ?= 4
CONTAINER_BUILD_MEMORY ?= 8G
CONTAINER_BUILD_MAX_JOBS ?= 2
CONTAINER_BUILD_CORES ?= 0
CONTAINER_NIX_SUBSTITUTERS ?= https://cache.nixos.org/
CONTAINER_NIX_TRUSTED_PUBLIC_KEYS ?= cache.nixos.org-1:6NCHdD59X431o0gWkM8wLaM/CDG7M0mVjZ5VkgS8rGs=
SMOKE_CONTAINER_NAME ?= hm-smoke
SMOKE_CONTAINER_IMAGE ?= local/hm-smoke:latest
SMOKE_CONTAINER_HOME_MOUNT ?= rw
SMOKE_CONTAINER_HOST_USER ?= $(CONTAINER_USER)
SMOKE_CONTAINER_HOST_HOME ?= /Users/$(SMOKE_CONTAINER_HOST_USER)
SMOKE_CONTAINER_IMAGE_WORDS := $(subst :, ,$(SMOKE_CONTAINER_IMAGE))
SMOKE_CONTAINER_IMAGE_NAME ?= $(word 1,$(SMOKE_CONTAINER_IMAGE_WORDS))
SMOKE_CONTAINER_IMAGE_TAG ?= $(or $(word 2,$(SMOKE_CONTAINER_IMAGE_WORDS)),latest)
SMOKE_CONTAINER_ARCHIVE ?= container/smoke/$(SMOKE_CONTAINER_NAME).oci.tar

.PHONY: switch full test build check clean prune container-image container-machine container-machine-reset container-up container-shell container-host-shell container-check container-direct-check container-smoke-image container-smoke-machine container-smoke-machine-reset container-smoke-up container-smoke-shell container-smoke-host-shell container-smoke-check container-smoke-direct-check help

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

container-smoke-image:
ifeq ($(UNAME), Darwin)
	@echo "📦 Building minimal ARM Linux Home Manager smoke image $(SMOKE_CONTAINER_IMAGE) ($(CONTAINER_SYSTEM))..."
	rm -f $(SMOKE_CONTAINER_ARCHIVE)
	container run --rm \
		--arch $(CONTAINER_ARCH) \
		--cpus $(CONTAINER_BUILD_CPUS) \
		--memory $(CONTAINER_BUILD_MEMORY) \
		--uid 0 \
		--gid 0 \
		--env SMOKE_CONTAINER_IMAGE_NAME=$(SMOKE_CONTAINER_IMAGE_NAME) \
		--env SMOKE_CONTAINER_IMAGE_TAG=$(SMOKE_CONTAINER_IMAGE_TAG) \
		--volume "$$(pwd)":/src \
		--workdir /src/container/smoke \
		--entrypoint /bin/sh \
		$(CONTAINER_BUILDER_IMAGE) \
		-lc 'set -eu; unset NIX_REMOTE; rm -rf /homeless-shelter; mkdir -p /var/tmp; chmod 1777 /var/tmp; export NIX_CONFIG="experimental-features = nix-command flakes"; archive="/src/$(SMOKE_CONTAINER_ARCHIVE)"; nix build ".#packages.$(CONTAINER_SYSTEM).containerImage" --impure --option max-jobs $(CONTAINER_BUILD_MAX_JOBS) --option cores $(CONTAINER_BUILD_CORES) --option build-users-group "" --option substituters "$(CONTAINER_NIX_SUBSTITUTERS)" --option trusted-public-keys "$(CONTAINER_NIX_TRUSTED_PUBLIC_KEYS)" --option require-sigs false --out-link /tmp/hm-smoke-container-image; mkdir -p "$$(dirname "$$archive")"; rm -f "$$archive"; install -m 0644 /tmp/hm-smoke-container-image "$$archive"'
	container image load --input $(SMOKE_CONTAINER_ARCHIVE)
else
	@echo "Apple container CLI targets are intended for macOS hosts."
endif

container-smoke-machine:
ifeq ($(UNAME), Darwin)
	@echo "🐧 Creating minimal Apple container machine $(SMOKE_CONTAINER_NAME)..."
	container machine create \
		--name $(SMOKE_CONTAINER_NAME) \
		--home-mount $(SMOKE_CONTAINER_HOME_MOUNT) \
		$(SMOKE_CONTAINER_IMAGE)
else
	@echo "Apple container CLI targets are intended for macOS hosts."
endif

container-smoke-machine-reset:
ifeq ($(UNAME), Darwin)
	@echo "♻️ Recreating minimal Apple container machine $(SMOKE_CONTAINER_NAME)..."
	-container machine stop $(SMOKE_CONTAINER_NAME)
	-container machine rm $(SMOKE_CONTAINER_NAME)
	container machine create \
		--name $(SMOKE_CONTAINER_NAME) \
		--home-mount $(SMOKE_CONTAINER_HOME_MOUNT) \
		$(SMOKE_CONTAINER_IMAGE)
else
	@echo "Apple container CLI targets are intended for macOS hosts."
endif

container-smoke-up: container-smoke-image container-smoke-machine-reset

container-smoke-shell:
ifeq ($(UNAME), Darwin)
	@for attempt in 1 2 3 4 5; do \
		if container machine run -n $(SMOKE_CONTAINER_NAME) --root -- /bin/sh -lc 'true' >/dev/null 2>&1; then \
			break; \
		fi; \
		if [ "$$attempt" = 5 ]; then exit 1; fi; \
		sleep 1; \
	done
	container machine run -n $(SMOKE_CONTAINER_NAME) --user hm --workdir /home/hm -- fish
else
	@echo "Apple container CLI targets are intended for macOS hosts."
endif

container-smoke-host-shell:
ifeq ($(UNAME), Darwin)
	@for attempt in 1 2 3 4 5; do \
		if container machine run -n $(SMOKE_CONTAINER_NAME) --root -- /bin/sh -lc 'true' >/dev/null 2>&1; then \
			break; \
		fi; \
		if [ "$$attempt" = 5 ]; then exit 1; fi; \
		sleep 1; \
	done
	container machine run -n $(SMOKE_CONTAINER_NAME) --env HOME=$(SMOKE_CONTAINER_HOST_HOME) --workdir $(SMOKE_CONTAINER_HOST_HOME) -- /bin/sh
else
	@echo "Apple container CLI targets are intended for macOS hosts."
endif

container-smoke-check:
ifeq ($(UNAME), Darwin)
	@for attempt in 1 2 3 4 5; do \
		if container machine run -n $(SMOKE_CONTAINER_NAME) --root -- /bin/sh -lc 'true' >/dev/null 2>&1; then \
			break; \
		fi; \
		if [ "$$attempt" = 5 ]; then exit 1; fi; \
		sleep 1; \
	done
	container machine run -n $(SMOKE_CONTAINER_NAME) --user hm --workdir /home/hm -- fish -lc 'echo; printf "arch=%s user=%s home=%s\n" (uname -m) "$$USER" "$$HOME"; cat ~/.hm-smoke; command -v fish; command -v hello; hello | head -1'
else
	@echo "Apple container CLI targets are intended for macOS hosts."
endif

container-smoke-direct-check:
ifeq ($(UNAME), Darwin)
	container run --rm --arch $(CONTAINER_ARCH) --uid 1000 --gid 1000 --entrypoint /bin/sh $(SMOKE_CONTAINER_IMAGE) -lc 'set -eu; echo "arch=$$(uname -m) user=$$(id -un) home=$$HOME"; cat ~/.hm-smoke; command -v fish; command -v hello; hello | head -1'
else
	@echo "Apple container CLI targets are intended for macOS hosts."
endif

container-image:
ifeq ($(UNAME), Darwin)
	@echo "📦 Building ARM Linux Home Manager image $(CONTAINER_IMAGE) ($(CONTAINER_SYSTEM))..."
	rm -f $(CONTAINER_IMAGE_ARCHIVE)
	container run --rm \
		--arch $(CONTAINER_ARCH) \
		--cpus $(CONTAINER_BUILD_CPUS) \
		--memory $(CONTAINER_BUILD_MEMORY) \
		--uid 0 \
		--gid 0 \
		--env NIXPKGS_ALLOW_UNFREE=1 \
		--env CONTAINER_IMAGE_NAME=$(CONTAINER_IMAGE_NAME) \
		--env CONTAINER_IMAGE_TAG=$(CONTAINER_IMAGE_TAG) \
		--env CONTAINER_UID=$(CONTAINER_UID) \
		--env CONTAINER_GID=$(CONTAINER_GID) \
		--volume "$$(pwd)":/src \
		--workdir /src \
		--entrypoint /bin/sh \
		$(CONTAINER_BUILDER_IMAGE) \
		-lc 'set -eu; unset NIX_REMOTE; rm -rf /homeless-shelter; mkdir -p /var/tmp; chmod 1777 /var/tmp; export NIX_CONFIG="experimental-features = nix-command flakes"; archive="/src/$(CONTAINER_IMAGE_ARCHIVE)"; nix build ".#packages.$(CONTAINER_SYSTEM).containerImage" --impure --option max-jobs $(CONTAINER_BUILD_MAX_JOBS) --option cores $(CONTAINER_BUILD_CORES) --option build-users-group "" --option substituters "$(CONTAINER_NIX_SUBSTITUTERS)" --option trusted-public-keys "$(CONTAINER_NIX_TRUSTED_PUBLIC_KEYS)" --option require-sigs false --out-link /tmp/snowbear-container-image; mkdir -p "$$(dirname "$$archive")"; rm -f "$$archive"; install -m 0644 /tmp/snowbear-container-image "$$archive"'
	container image load --input $(CONTAINER_IMAGE_ARCHIVE)
else
	@echo "Apple container CLI targets are intended for macOS hosts."
endif

container-machine:
ifeq ($(UNAME), Darwin)
	@echo "🐧 Creating Apple container machine $(CONTAINER_NAME)..."
	container machine create \
		--name $(CONTAINER_NAME) \
		--home-mount $(CONTAINER_HOME_MOUNT) \
		$(CONTAINER_IMAGE)
else
	@echo "Apple container CLI targets are intended for macOS hosts."
endif

container-machine-reset:
ifeq ($(UNAME), Darwin)
	@echo "♻️ Recreating Apple container machine $(CONTAINER_NAME)..."
	-container machine stop $(CONTAINER_NAME)
	-container machine rm $(CONTAINER_NAME)
	container machine create \
		--name $(CONTAINER_NAME) \
		--home-mount $(CONTAINER_HOME_MOUNT) \
		$(CONTAINER_IMAGE)
else
	@echo "Apple container CLI targets are intended for macOS hosts."
endif

container-up: container-image container-machine-reset

container-shell:
ifeq ($(UNAME), Darwin)
	@for attempt in 1 2 3 4 5; do \
		if container machine run -n $(CONTAINER_NAME) --root -- /bin/sh -lc 'true' >/dev/null 2>&1; then \
			break; \
		fi; \
		if [ "$$attempt" = 5 ]; then exit 1; fi; \
		sleep 1; \
	done
	container machine run -n $(CONTAINER_NAME) --user $(CONTAINER_USER) --workdir /home/$(CONTAINER_USER) -- fish
else
	@echo "Apple container CLI targets are intended for macOS hosts."
endif

container-host-shell:
ifeq ($(UNAME), Darwin)
	@for attempt in 1 2 3 4 5; do \
		if container machine run -n $(CONTAINER_NAME) --root -- /bin/sh -lc 'true' >/dev/null 2>&1; then \
			break; \
		fi; \
		if [ "$$attempt" = 5 ]; then exit 1; fi; \
		sleep 1; \
	done
	container machine run -n $(CONTAINER_NAME) --user $(CONTAINER_USER) --workdir $(CONTAINER_HOST_HOME) -- fish
else
	@echo "Apple container CLI targets are intended for macOS hosts."
endif

container-check:
ifeq ($(UNAME), Darwin)
	@for attempt in 1 2 3 4 5; do \
		if container machine run -n $(CONTAINER_NAME) --root -- /bin/sh -lc 'true' >/dev/null 2>&1; then \
			break; \
		fi; \
		if [ "$$attempt" = 5 ]; then exit 1; fi; \
		sleep 1; \
	done
	container machine run -n $(CONTAINER_NAME) --user $(CONTAINER_USER) --workdir /home/$(CONTAINER_USER) -- fish -lc 'echo; printf "arch=%s user=%s home=%s\n" (uname -m) "$$USER" "$$HOME"; command -v fish; command -v nix; nix --version; command -v home-manager; command -v nvim; command -v tmux; command -v lazygit; test -d /Users/$(CONTAINER_USER) && echo users-mounted'
else
	@echo "Apple container CLI targets are intended for macOS hosts."
endif

container-direct-check:
ifeq ($(UNAME), Darwin)
	container run --rm --arch $(CONTAINER_ARCH) --uid $(CONTAINER_UID) --gid $(CONTAINER_GID) --entrypoint /bin/sh $(CONTAINER_IMAGE) -lc 'set -eu; echo "arch=$$(uname -m) user=$$(id -un) home=$$HOME"; command -v fish; command -v nix; nix --version; command -v nvim; command -v tmux; command -v lazygit'
else
	@echo "Apple container CLI targets are intended for macOS hosts."
endif

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
	@echo "  container-image               - Build full Home Manager OCI image"
	@echo "  container-machine             - Create full Home Manager machine"
	@echo "  container-machine-reset       - Recreate full Home Manager machine"
	@echo "  container-up                  - Build image and recreate full machine"
	@echo "  container-shell               - Open fish in baked Home Manager home"
	@echo "  container-host-shell          - Open fish in mounted /Users home"
	@echo "  container-check               - Smoke-test full Home Manager machine"
	@echo "  container-direct-check        - Smoke-test full image with container run"
	@echo "  container-smoke-image         - Build minimal Home Manager OCI image"
	@echo "  container-smoke-machine       - Create minimal test machine from loaded image"
	@echo "  container-smoke-machine-reset - Recreate the minimal test machine"
	@echo "  container-smoke-up            - Build image and recreate minimal test machine"
	@echo "  container-smoke-shell         - Open fish in the minimal test machine"
	@echo "  container-smoke-host-shell    - Open a host-user shell with /Users mounted"
	@echo "  container-smoke-check         - Smoke-test minimal Home Manager machine"
	@echo "  container-smoke-direct-check  - Smoke-test minimal image with container run"
	@echo "  help          - Show this help message"
