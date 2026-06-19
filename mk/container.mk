# Apple container machine targets.
#
# The default workflow is persistent: create a machine once, then apply Home
# Manager changes inside it. Use container-reset only when base image boot
# plumbing must be replaced.

CONTAINER_USER ?= $(shell id -un)
CONTAINER_UID ?= $(shell id -u)
CONTAINER_GID ?= $(shell id -g)
CONTAINER_NAME ?= snowbear-dev
CONTAINER_IMAGE ?= local/snowbear-dev:latest
CONTAINER_HOME_MOUNT ?= rw
CONTAINER_HOST_HOME ?= /Users/$(CONTAINER_USER)
CONTAINER_REPO ?= $(CURDIR)
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
CONTAINER_NIX_REQUIRE_SIGS ?= false
CONTAINER_HM_PROFILE ?= $(CONTAINER_USER)-aarch64
CONTAINER_HM_FULL_PROFILE ?= $(CONTAINER_USER)-full-aarch64
CONTAINER_HM_EXPIRE ?= -7 days
CONTAINER_SCRIPT_DIR ?= $(CONTAINER_REPO)/container/scripts

.PHONY: container-image container-create container-machine container-bootstrap container-up
.PHONY: container-reset container-machine-reset container-wait container-nix-cache
.PHONY: container-shell container-host-shell container-root-shell
.PHONY: container-hm-switch container-hm-full container-gc
.PHONY: container-check container-direct-check

container-image:
ifeq ($(UNAME), Darwin)
	@echo "Building ARM Linux Home Manager image $(CONTAINER_IMAGE) ($(CONTAINER_SYSTEM))..."
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
	@echo "Apple container targets are intended for macOS hosts."
endif

container-create:
ifeq ($(UNAME), Darwin)
	@if container machine inspect $(CONTAINER_NAME) >/dev/null 2>&1; then \
		echo "Container machine $(CONTAINER_NAME) already exists; leaving persistent state untouched."; \
	else \
		echo "Creating Apple container machine $(CONTAINER_NAME)..."; \
		container machine create \
			--name $(CONTAINER_NAME) \
			--home-mount $(CONTAINER_HOME_MOUNT) \
			$(CONTAINER_IMAGE); \
	fi
else
	@echo "Apple container targets are intended for macOS hosts."
endif

container-machine: container-create

container-bootstrap: container-image container-create

container-up: container-bootstrap

container-reset: container-image
ifeq ($(UNAME), Darwin)
	@echo "Destructively recreating Apple container machine $(CONTAINER_NAME)..."
	-container machine stop $(CONTAINER_NAME)
	-container machine rm $(CONTAINER_NAME)
	container machine create \
		--name $(CONTAINER_NAME) \
		--home-mount $(CONTAINER_HOME_MOUNT) \
		$(CONTAINER_IMAGE)
else
	@echo "Apple container targets are intended for macOS hosts."
endif

container-machine-reset: container-reset

container-wait:
ifeq ($(UNAME), Darwin)
	@for attempt in 1 2 3 4 5; do \
			if container machine run -n $(CONTAINER_NAME) --root -- /bin/true >/dev/null 2>&1; then \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "Container machine $(CONTAINER_NAME) is not ready." >&2; \
	exit 1
else
	@echo "Apple container targets are intended for macOS hosts."
endif

container-shell: container-wait
ifeq ($(UNAME), Darwin)
	container machine run -n $(CONTAINER_NAME) --user $(CONTAINER_USER) --workdir /home/$(CONTAINER_USER) -- fish
else
	@echo "Apple container targets are intended for macOS hosts."
endif

container-host-shell: container-wait
ifeq ($(UNAME), Darwin)
	container machine run -n $(CONTAINER_NAME) --user $(CONTAINER_USER) --workdir $(CONTAINER_HOST_HOME) -- fish
else
	@echo "Apple container targets are intended for macOS hosts."
endif

container-root-shell: container-wait
ifeq ($(UNAME), Darwin)
	container machine run -n $(CONTAINER_NAME) --root -- /bin/sh
else
	@echo "Apple container targets are intended for macOS hosts."
endif

container-nix-cache: container-wait
ifeq ($(UNAME), Darwin)
	@if container machine run -n $(CONTAINER_NAME) \
		--root \
		--env CONTAINER_USER=$(CONTAINER_USER) \
		--env CONTAINER_NIX_SUBSTITUTERS=$(CONTAINER_NIX_SUBSTITUTERS) \
		--env CONTAINER_NIX_TRUSTED_PUBLIC_KEYS=$(CONTAINER_NIX_TRUSTED_PUBLIC_KEYS) \
		--env CONTAINER_NIX_REQUIRE_SIGS=$(CONTAINER_NIX_REQUIRE_SIGS) \
		-- /bin/sh $(CONTAINER_SCRIPT_DIR)/nix-cache-repair.sh; then \
		echo "Nix cache config is current in $(CONTAINER_NAME)."; \
	else \
		status=$$?; \
		if [ "$$status" -eq 10 ]; then \
			echo "Updated Nix cache config in $(CONTAINER_NAME); restarting machine..."; \
			container machine stop $(CONTAINER_NAME); \
			container machine run -n $(CONTAINER_NAME) --root -- /bin/true; \
		else \
			exit "$$status"; \
		fi; \
	fi
else
	@echo "Apple container targets are intended for macOS hosts."
endif

container-hm-switch: container-nix-cache
ifeq ($(UNAME), Darwin)
	container machine run -n $(CONTAINER_NAME) \
		--user $(CONTAINER_USER) \
		--workdir $(CONTAINER_REPO) \
		--env NIXPKGS_ALLOW_UNFREE=1 \
		--env CONTAINER_REPO=$(CONTAINER_REPO) \
		--env CONTAINER_NIX_SUBSTITUTERS=$(CONTAINER_NIX_SUBSTITUTERS) \
		--env CONTAINER_NIX_TRUSTED_PUBLIC_KEYS=$(CONTAINER_NIX_TRUSTED_PUBLIC_KEYS) \
		--env CONTAINER_NIX_REQUIRE_SIGS=$(CONTAINER_NIX_REQUIRE_SIGS) \
		-- /bin/sh $(CONTAINER_SCRIPT_DIR)/hm-switch.sh $(CONTAINER_HM_PROFILE)
else
	@echo "Apple container targets are intended for macOS hosts."
endif

container-hm-full: container-nix-cache
ifeq ($(UNAME), Darwin)
	container machine run -n $(CONTAINER_NAME) \
		--user $(CONTAINER_USER) \
		--workdir $(CONTAINER_REPO) \
		--env NIXPKGS_ALLOW_UNFREE=1 \
		--env CONTAINER_REPO=$(CONTAINER_REPO) \
		--env CONTAINER_NIX_SUBSTITUTERS=$(CONTAINER_NIX_SUBSTITUTERS) \
		--env CONTAINER_NIX_TRUSTED_PUBLIC_KEYS=$(CONTAINER_NIX_TRUSTED_PUBLIC_KEYS) \
		--env CONTAINER_NIX_REQUIRE_SIGS=$(CONTAINER_NIX_REQUIRE_SIGS) \
		-- /bin/sh $(CONTAINER_SCRIPT_DIR)/hm-switch.sh $(CONTAINER_HM_FULL_PROFILE)
else
	@echo "Apple container targets are intended for macOS hosts."
endif

container-gc: container-wait
ifeq ($(UNAME), Darwin)
	-container machine run -n $(CONTAINER_NAME) \
		--user $(CONTAINER_USER) \
		--workdir $(CONTAINER_REPO) \
		--env CONTAINER_HM_EXPIRE="$(CONTAINER_HM_EXPIRE)" \
		-- /bin/sh $(CONTAINER_SCRIPT_DIR)/hm-gc-user.sh
	container machine run -n $(CONTAINER_NAME) --root -- nix-collect-garbage -d
else
	@echo "Apple container targets are intended for macOS hosts."
endif

container-check: container-wait
ifeq ($(UNAME), Darwin)
	container machine run -n $(CONTAINER_NAME) \
		--user $(CONTAINER_USER) \
		--workdir $(CONTAINER_REPO) \
		--env CONTAINER_USER=$(CONTAINER_USER) \
		-- /bin/sh $(CONTAINER_SCRIPT_DIR)/check.sh
	@for attempt in 1 2 3 4 5; do \
		container machine run -n $(CONTAINER_NAME) --user $(CONTAINER_UID):$(CONTAINER_GID) --workdir /home/$(CONTAINER_USER) -- /usr/local/bin/docker ps >/dev/null 2>&1 && exit 0; \
		sleep 1; \
	done; \
	container machine run -n $(CONTAINER_NAME) --user $(CONTAINER_UID):$(CONTAINER_GID) --workdir /home/$(CONTAINER_USER) -- /usr/local/bin/docker ps >/dev/null
	@echo docker-numeric-user
else
	@echo "Apple container targets are intended for macOS hosts."
endif

container-direct-check:
ifeq ($(UNAME), Darwin)
	container run --rm --arch $(CONTAINER_ARCH) --uid $(CONTAINER_UID) --gid $(CONTAINER_GID) --entrypoint /bin/sh $(CONTAINER_IMAGE) -lc 'set -eu; echo "arch=$$(uname -m) user=$$(id -un) home=$$HOME"; command -v fish; command -v nix; nix --version; command -v home-manager; home-manager --version; command -v nvim; command -v tmux; command -v lazygit; command -v docker; command -v screenfetch; command -v tailscale'
else
	@echo "Apple container targets are intended for macOS hosts."
endif
