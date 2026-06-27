# Multipass VM targets.
#
# The default workflow is persistent: create a VM once, then apply Home Manager
# changes inside it. Use multipass-reset only when a clean VM is desired.

MULTIPASS_USER ?= $(shell id -un)
MULTIPASS_HOST_UID ?= $(shell id -u)
MULTIPASS_HOST_GID ?= $(shell id -g)
MULTIPASS_UID ?= $(MULTIPASS_HOST_UID)
MULTIPASS_GID ?= $(MULTIPASS_UID)
NAME ?= main
MULTIPASS_NAME ?= $(NAME)
MULTIPASS_IMAGE ?= 24.04
MULTIPASS_CPUS ?= 4
MULTIPASS_MEMORY ?= 8G
MULTIPASS_DISK ?= 80G
MULTIPASS_BRIDGED ?= 1
MULTIPASS_BRIDGE ?=
MULTIPASS_MOUNT_HOME ?= 0
MULTIPASS_MOUNT_TYPE ?= classic
MULTIPASS_HOST_HOME ?= /Users/$(MULTIPASS_USER)
MULTIPASS_REPO ?= $(CURDIR)
MULTIPASS_VM_REPO ?= /home/$(MULTIPASS_USER)/src/nixos-config
MULTIPASS_VM_SCRIPT_DIR ?= $(MULTIPASS_VM_REPO)/multipass/scripts
MULTIPASS_HM_PROFILE ?= $(MULTIPASS_USER)-aarch64
MULTIPASS_HM_FULL_PROFILE ?= $(MULTIPASS_USER)-full-aarch64
MULTIPASS_HM_EXPIRE ?= 7d
MULTIPASS_SCRIPT_DIR ?= $(MULTIPASS_REPO)/multipass/scripts
MULTIPASS_AUTHORIZED_KEYS ?= $(MULTIPASS_REPO)/multipass/.generated/authorized_keys.$(MULTIPASS_NAME)
MULTIPASS_TAR_EXCLUDES ?= --exclude .git --exclude result --exclude 'result-*' --exclude .direnv --exclude .devenv --exclude .DS_Store --exclude multipass/.generated
MULTIPASS_LAUNCH_TIMEOUT ?= 1800
MULTIPASS_BOOTSTRAP_HM ?= new
MULTIPASS_SET_PRIMARY ?= 1
MULTIPASS_NIX_SUBSTITUTERS ?= https://cache.nixos.org/
MULTIPASS_NIX_TRUSTED_PUBLIC_KEYS ?= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
MULTIPASS_NIX_REQUIRE_SIGS ?= false
MULTIPASS_TAILSCALE_AUTH_KEY ?=
MULTIPASS_TAILSCALE_EXTRA_ARGS ?= --accept-dns=true
MULTIPASS_USER_ENV = PATH=/nix/var/nix/profiles/default/bin:/home/$(MULTIPASS_USER)/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin HOME=/home/$(MULTIPASS_USER) USER=$(MULTIPASS_USER) LOGNAME=$(MULTIPASS_USER) SNOWBEAR_MULTIPASS=1
MULTIPASS_DEFAULT_BRIDGE = $$(route get default 2>/dev/null | awk '/interface:/ { print $$2; exit }')

.PHONY: multipass-create multipass-bootstrap multipass-up multipass-reset multipass-rebuild
.PHONY: multipass-wait multipass-mount multipass-sync-repo multipass-authorized-keys multipass-provision multipass-nix-cache
.PHONY: multipass-shell multipass-host-shell multipass-root-shell
.PHONY: multipass-hm-switch multipass-hm-full multipass-gc multipass-check
.PHONY: multipass-tailscale-up multipass-disable-tailscale multipass-disk-grow
.PHONY: multipass-info multipass-list multipass-bridge

multipass-create:
ifeq ($(UNAME), Darwin)
	@if multipass info "$(MULTIPASS_NAME)" >/dev/null 2>&1; then \
		echo "Multipass instance $(MULTIPASS_NAME) already exists; leaving persistent state untouched."; \
		multipass start "$(MULTIPASS_NAME)" >/dev/null 2>&1 || true; \
	else \
		bridge="$(MULTIPASS_BRIDGE)"; \
		if [ "$(MULTIPASS_BRIDGED)" = "1" ] && [ -z "$$bridge" ]; then \
			bridge=$(MULTIPASS_DEFAULT_BRIDGE); \
		fi; \
		if [ "$(MULTIPASS_BRIDGED)" = "1" ] && [ -z "$$bridge" ]; then \
			bridge=$$(multipass networks | awk 'NR == 2 { print $$1 }'); \
		fi; \
		network_args=""; \
		if [ "$(MULTIPASS_BRIDGED)" = "1" ]; then \
			if [ -z "$$bridge" ]; then \
				echo "No Multipass bridge network found. Set MULTIPASS_BRIDGE=en0, or use MULTIPASS_BRIDGED=0." >&2; \
				exit 1; \
			fi; \
			echo "Launching $(MULTIPASS_NAME) with bridged network $$bridge..."; \
			current_bridge=$$(multipass get local.bridged-network 2>/dev/null || true); \
			if [ "$$current_bridge" != "$$bridge" ]; then \
				multipass set "local.bridged-network=$$bridge"; \
				for attempt in 1 2 3 4 5 6 7 8 9 10; do \
					if multipass get local.bridged-network >/dev/null 2>&1; then \
						break; \
					fi; \
					sleep 1; \
				done; \
			fi; \
			network_args="--network bridged"; \
		else \
			echo "Launching $(MULTIPASS_NAME) without an extra bridged network..."; \
		fi; \
		multipass launch "$(MULTIPASS_IMAGE)" \
			--name "$(MULTIPASS_NAME)" \
			--cpus "$(MULTIPASS_CPUS)" \
			--memory "$(MULTIPASS_MEMORY)" \
			--disk "$(MULTIPASS_DISK)" \
			--timeout "$(MULTIPASS_LAUNCH_TIMEOUT)" \
			$$network_args; \
	fi; \
	if [ "$(MULTIPASS_SET_PRIMARY)" = "1" ]; then \
		multipass set client.primary-name="$(MULTIPASS_NAME)" >/dev/null; \
	fi
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-bootstrap:
ifeq ($(UNAME), Darwin)
	@set -e; \
	created=0; \
	needs_hm=0; \
	if multipass info "$(MULTIPASS_NAME)" >/dev/null 2>&1; then \
		echo "Multipass instance $(MULTIPASS_NAME) already exists; using persistent state."; \
		multipass start "$(MULTIPASS_NAME)" >/dev/null 2>&1 || true; \
		if ! multipass exec "$(MULTIPASS_NAME)" -- sudo test -x "/home/$(MULTIPASS_USER)/.cache/snowbear-home-manager/result/activate" >/dev/null 2>&1; then \
			needs_hm=1; \
		fi; \
	else \
		created=1; \
		needs_hm=1; \
		$(MAKE) multipass-create; \
	fi; \
	$(MAKE) multipass-wait; \
	if [ "$(MULTIPASS_SET_PRIMARY)" = "1" ]; then \
		multipass set client.primary-name="$(MULTIPASS_NAME)" >/dev/null; \
	fi; \
	$(MAKE) multipass-mount; \
	$(MAKE) multipass-provision; \
	if [ "$(MULTIPASS_BOOTSTRAP_HM)" = "always" ] || { [ "$(MULTIPASS_BOOTSTRAP_HM)" = "new" ] && [ "$$needs_hm" = "1" ]; }; then \
		$(MAKE) multipass-hm-full; \
	else \
		echo "Home Manager switch skipped for existing $(MULTIPASS_NAME); run make multipass-hm-full to update it."; \
	fi
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-up: multipass-bootstrap

multipass-reset:
ifeq ($(UNAME), Darwin)
	@echo "Destructively recreating Multipass instance $(MULTIPASS_NAME)..."
	-multipass stop "$(MULTIPASS_NAME)"
	-multipass delete --purge "$(MULTIPASS_NAME)"
	$(MAKE) MULTIPASS_BOOTSTRAP_HM=always multipass-bootstrap
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-rebuild: multipass-reset

multipass-wait:
ifeq ($(UNAME), Darwin)
	@for attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do \
		if multipass exec "$(MULTIPASS_NAME)" -- /bin/true >/dev/null 2>&1; then \
			exit 0; \
		fi; \
		sleep 2; \
	done; \
	echo "Multipass instance $(MULTIPASS_NAME) is not ready." >&2; \
	exit 1
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-mount: multipass-wait
ifeq ($(UNAME), Darwin)
	@set -e; \
	if [ "$(MULTIPASS_MOUNT_HOME)" != "1" ]; then \
		if multipass info "$(MULTIPASS_NAME)" | grep -F "$(MULTIPASS_HOST_HOME) => $(MULTIPASS_HOST_HOME)" >/dev/null 2>&1; then \
			echo "Unmounting $(MULTIPASS_HOST_HOME) from $(MULTIPASS_NAME)..."; \
			multipass umount "$(MULTIPASS_NAME):$(MULTIPASS_HOST_HOME)"; \
		else \
			echo "Host home mount disabled for $(MULTIPASS_NAME)."; \
		fi; \
	else \
		if multipass info "$(MULTIPASS_NAME)" | grep -F "$(MULTIPASS_HOST_HOME) => $(MULTIPASS_HOST_HOME)" >/dev/null 2>&1; then \
			echo "$(MULTIPASS_HOST_HOME) is already mounted in $(MULTIPASS_NAME)."; \
		else \
			multipass set local.privileged-mounts=true >/dev/null 2>&1 || true; \
			multipass exec "$(MULTIPASS_NAME)" -- sudo mkdir -p "$(MULTIPASS_HOST_HOME)"; \
			if [ "$(MULTIPASS_MOUNT_TYPE)" = "native" ]; then \
				multipass stop "$(MULTIPASS_NAME)"; \
			fi; \
			multipass mount \
				--type="$(MULTIPASS_MOUNT_TYPE)" \
				--uid-map "$(MULTIPASS_HOST_UID):$(MULTIPASS_UID)" \
				--gid-map "$(MULTIPASS_HOST_GID):$(MULTIPASS_GID)" \
				"$(MULTIPASS_HOST_HOME)" \
				"$(MULTIPASS_NAME):$(MULTIPASS_HOST_HOME)"; \
			if [ "$(MULTIPASS_MOUNT_TYPE)" = "native" ]; then \
				multipass start "$(MULTIPASS_NAME)"; \
				$(MAKE) multipass-wait; \
			fi; \
		fi; \
	fi
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-sync-repo: multipass-wait
ifeq ($(UNAME), Darwin)
	@set -e; \
	repo_parent=$$(dirname "$(MULTIPASS_REPO)"); \
	repo_name=$$(basename "$(MULTIPASS_REPO)"); \
	echo "Syncing $(MULTIPASS_REPO) to $(MULTIPASS_NAME):$(MULTIPASS_VM_REPO)..."; \
	COPYFILE_DISABLE=1 tar --no-xattrs -C "$$repo_parent" $(MULTIPASS_TAR_EXCLUDES) -cf - "$$repo_name" | \
		multipass exec "$(MULTIPASS_NAME)" -- sudo -H -u "$(MULTIPASS_USER)" env HOME="/home/$(MULTIPASS_USER)" /bin/sh -c 'set -e; vm_repo="$(MULTIPASS_VM_REPO)"; tmp="$${vm_repo}.tmp"; rm -rf "$$tmp"; mkdir -p "$$(dirname "$$tmp")"; mkdir -p "$$tmp"; tar -xf - -C "$$tmp" --strip-components=1; rm -rf "$$vm_repo"; mv "$$tmp" "$$vm_repo"'
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-authorized-keys: multipass-wait
ifeq ($(UNAME), Darwin)
	@set -e; \
	mkdir -p "$(dir $(MULTIPASS_AUTHORIZED_KEYS))"; \
	tmp="$(MULTIPASS_AUTHORIZED_KEYS).tmp"; \
	: > "$$tmp"; \
	if [ -s "$(MULTIPASS_HOST_HOME)/.ssh/authorized_keys" ]; then \
		cat "$(MULTIPASS_HOST_HOME)/.ssh/authorized_keys" >> "$$tmp"; \
	fi; \
	for public_key in "$(MULTIPASS_HOST_HOME)"/.ssh/id_*.pub; do \
		if [ -s "$$public_key" ]; then \
			cat "$$public_key" >> "$$tmp"; \
		fi; \
	done; \
	if [ -s "$$tmp" ]; then \
		awk '!seen[$$0]++' "$$tmp" > "$(MULTIPASS_AUTHORIZED_KEYS)"; \
	else \
		: > "$(MULTIPASS_AUTHORIZED_KEYS)"; \
	fi; \
	rm -f "$$tmp"; \
	multipass transfer "$(MULTIPASS_AUTHORIZED_KEYS)" "$(MULTIPASS_NAME):/tmp/snowbear-authorized-keys"
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-provision: multipass-wait multipass-authorized-keys
ifeq ($(UNAME), Darwin)
	multipass transfer "$(MULTIPASS_SCRIPT_DIR)/provision.sh" "$(MULTIPASS_NAME):/tmp/snowbear-multipass-provision.sh"
	multipass exec "$(MULTIPASS_NAME)" -- sudo env \
		MULTIPASS_NAME="$(MULTIPASS_NAME)" \
		MULTIPASS_USER="$(MULTIPASS_USER)" \
		MULTIPASS_UID="$(MULTIPASS_UID)" \
		MULTIPASS_GID="$(MULTIPASS_GID)" \
		MULTIPASS_HOST_HOME="$(MULTIPASS_HOST_HOME)" \
		MULTIPASS_REPO="$(MULTIPASS_VM_REPO)" \
		MULTIPASS_AUTHORIZED_KEYS_FILE="/tmp/snowbear-authorized-keys" \
		MULTIPASS_TAILSCALE_AUTH_KEY="$(MULTIPASS_TAILSCALE_AUTH_KEY)" \
		MULTIPASS_TAILSCALE_EXTRA_ARGS="$(MULTIPASS_TAILSCALE_EXTRA_ARGS)" \
		MULTIPASS_NIX_SUBSTITUTERS="$(MULTIPASS_NIX_SUBSTITUTERS)" \
		MULTIPASS_NIX_TRUSTED_PUBLIC_KEYS="$(MULTIPASS_NIX_TRUSTED_PUBLIC_KEYS)" \
		MULTIPASS_NIX_REQUIRE_SIGS="$(MULTIPASS_NIX_REQUIRE_SIGS)" \
		/bin/sh /tmp/snowbear-multipass-provision.sh
	$(MAKE) multipass-nix-cache
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-nix-cache: multipass-wait
ifeq ($(UNAME), Darwin)
	multipass transfer "$(MULTIPASS_SCRIPT_DIR)/nix-cache-repair.sh" "$(MULTIPASS_NAME):/tmp/snowbear-nix-cache-repair.sh"
	@if multipass exec "$(MULTIPASS_NAME)" -- sudo env \
		MULTIPASS_USER="$(MULTIPASS_USER)" \
		MULTIPASS_NIX_SUBSTITUTERS="$(MULTIPASS_NIX_SUBSTITUTERS)" \
		MULTIPASS_NIX_TRUSTED_PUBLIC_KEYS="$(MULTIPASS_NIX_TRUSTED_PUBLIC_KEYS)" \
		MULTIPASS_NIX_REQUIRE_SIGS="$(MULTIPASS_NIX_REQUIRE_SIGS)" \
		/bin/sh /tmp/snowbear-nix-cache-repair.sh; then \
		echo "Nix cache config is current in $(MULTIPASS_NAME)."; \
	else \
		status=$$?; \
		if [ "$$status" -eq 10 ]; then \
			echo "Updated Nix cache config in $(MULTIPASS_NAME); restarting nix-daemon..."; \
			multipass exec "$(MULTIPASS_NAME)" -- sudo systemctl restart nix-daemon.service; \
		else \
			exit "$$status"; \
		fi; \
	fi
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-shell: multipass-wait
ifeq ($(UNAME), Darwin)
	multipass exec -d "/home/$(MULTIPASS_USER)" "$(MULTIPASS_NAME)" -- sudo -H -u "$(MULTIPASS_USER)" env $(MULTIPASS_USER_ENV) fish -l
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-host-shell: multipass-sync-repo
ifeq ($(UNAME), Darwin)
	multipass exec -d "$(MULTIPASS_VM_REPO)" "$(MULTIPASS_NAME)" -- sudo -H -u "$(MULTIPASS_USER)" env $(MULTIPASS_USER_ENV) fish -l
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-root-shell: multipass-wait
ifeq ($(UNAME), Darwin)
	multipass exec "$(MULTIPASS_NAME)" -- sudo -Hiu root /bin/bash
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-hm-switch: multipass-nix-cache multipass-sync-repo
ifeq ($(UNAME), Darwin)
	multipass exec -d "$(MULTIPASS_VM_REPO)" "$(MULTIPASS_NAME)" -- sudo -H -u "$(MULTIPASS_USER)" env \
		$(MULTIPASS_USER_ENV) \
		NIXPKGS_ALLOW_UNFREE=1 \
		SNOWBEAR_HOME_MULTIPASS=1 \
		MULTIPASS_REPO="$(MULTIPASS_VM_REPO)" \
		MULTIPASS_NIX_SUBSTITUTERS="$(MULTIPASS_NIX_SUBSTITUTERS)" \
		MULTIPASS_NIX_TRUSTED_PUBLIC_KEYS="$(MULTIPASS_NIX_TRUSTED_PUBLIC_KEYS)" \
		MULTIPASS_NIX_REQUIRE_SIGS="$(MULTIPASS_NIX_REQUIRE_SIGS)" \
		/bin/sh "$(MULTIPASS_VM_SCRIPT_DIR)/hm-switch.sh" "$(MULTIPASS_HM_PROFILE)"
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-hm-full: multipass-nix-cache multipass-sync-repo
ifeq ($(UNAME), Darwin)
	multipass exec -d "$(MULTIPASS_VM_REPO)" "$(MULTIPASS_NAME)" -- sudo -H -u "$(MULTIPASS_USER)" env \
		$(MULTIPASS_USER_ENV) \
		NIXPKGS_ALLOW_UNFREE=1 \
		SNOWBEAR_HOME_MULTIPASS=1 \
		MULTIPASS_REPO="$(MULTIPASS_VM_REPO)" \
		MULTIPASS_NIX_SUBSTITUTERS="$(MULTIPASS_NIX_SUBSTITUTERS)" \
		MULTIPASS_NIX_TRUSTED_PUBLIC_KEYS="$(MULTIPASS_NIX_TRUSTED_PUBLIC_KEYS)" \
		MULTIPASS_NIX_REQUIRE_SIGS="$(MULTIPASS_NIX_REQUIRE_SIGS)" \
		/bin/sh "$(MULTIPASS_VM_SCRIPT_DIR)/hm-switch.sh" "$(MULTIPASS_HM_FULL_PROFILE)"
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-gc: multipass-sync-repo
ifeq ($(UNAME), Darwin)
	-multipass exec -d "$(MULTIPASS_VM_REPO)" "$(MULTIPASS_NAME)" -- sudo -H -u "$(MULTIPASS_USER)" env \
		$(MULTIPASS_USER_ENV) \
		MULTIPASS_HM_EXPIRE="$(MULTIPASS_HM_EXPIRE)" \
		/bin/sh "$(MULTIPASS_VM_SCRIPT_DIR)/hm-gc-user.sh"
	multipass exec "$(MULTIPASS_NAME)" -- sudo nix-collect-garbage -d
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-check: multipass-sync-repo
ifeq ($(UNAME), Darwin)
	multipass exec -d "$(MULTIPASS_VM_REPO)" "$(MULTIPASS_NAME)" -- sudo -H -u "$(MULTIPASS_USER)" env \
		$(MULTIPASS_USER_ENV) \
		MULTIPASS_USER="$(MULTIPASS_USER)" \
		MULTIPASS_HOST_HOME="$(MULTIPASS_HOST_HOME)" \
		MULTIPASS_VM_REPO="$(MULTIPASS_VM_REPO)" \
		MULTIPASS_MOUNT_HOME="$(MULTIPASS_MOUNT_HOME)" \
		/bin/sh "$(MULTIPASS_VM_SCRIPT_DIR)/check.sh"
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-tailscale-up: multipass-wait
ifeq ($(UNAME), Darwin)
	@set -e; \
	auth_arg=""; \
	if [ -n "$(MULTIPASS_TAILSCALE_AUTH_KEY)" ]; then \
		auth_arg="--auth-key=$(MULTIPASS_TAILSCALE_AUTH_KEY)"; \
	fi; \
	multipass exec "$(MULTIPASS_NAME)" -- sudo tailscale up --hostname="$(MULTIPASS_NAME)" $$auth_arg $(MULTIPASS_TAILSCALE_EXTRA_ARGS)
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-disable-tailscale: multipass-wait
ifeq ($(UNAME), Darwin)
	multipass transfer "$(MULTIPASS_SCRIPT_DIR)/disable-tailscale.sh" "$(MULTIPASS_NAME):/tmp/snowbear-disable-tailscale.sh"
	multipass exec "$(MULTIPASS_NAME)" -- sudo /bin/sh /tmp/snowbear-disable-tailscale.sh
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-disk-grow:
ifeq ($(UNAME), Darwin)
	@echo "Increasing $(MULTIPASS_NAME) disk to $(MULTIPASS_DISK). Multipass supports increases only."
	multipass stop "$(MULTIPASS_NAME)"
	multipass set "local.$(MULTIPASS_NAME).disk=$(MULTIPASS_DISK)"
	multipass start "$(MULTIPASS_NAME)"
	$(MAKE) multipass-wait
	-multipass exec "$(MULTIPASS_NAME)" -- sudo growpart /dev/sda 1
	-multipass exec "$(MULTIPASS_NAME)" -- sudo resize2fs /dev/sda1
	multipass info "$(MULTIPASS_NAME)"
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-bridge:
ifeq ($(UNAME), Darwin)
	@set -e; \
	bridge="$(MULTIPASS_BRIDGE)"; \
	if [ -z "$$bridge" ]; then \
		bridge=$(MULTIPASS_DEFAULT_BRIDGE); \
	fi; \
	if [ -z "$$bridge" ]; then \
		bridge=$$(multipass networks | awk 'NR == 2 { print $$1 }'); \
	fi; \
	if [ -z "$$bridge" ]; then \
		echo "No Multipass bridge network found. Set MULTIPASS_BRIDGE=en0." >&2; \
		exit 1; \
	fi; \
	echo "Adding preferred bridge $$bridge to $(MULTIPASS_NAME)..."; \
	multipass stop "$(MULTIPASS_NAME)"; \
	current_bridge=$$(multipass get local.bridged-network 2>/dev/null || true); \
	if [ "$$current_bridge" != "$$bridge" ]; then \
		multipass set "local.bridged-network=$$bridge"; \
		for attempt in 1 2 3 4 5 6 7 8 9 10; do \
			if multipass get local.bridged-network >/dev/null 2>&1; then \
				break; \
			fi; \
			sleep 1; \
		done; \
	fi; \
	multipass set "local.$(MULTIPASS_NAME).bridged=true"; \
	multipass start "$(MULTIPASS_NAME)"
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-info:
ifeq ($(UNAME), Darwin)
	multipass info "$(MULTIPASS_NAME)"
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

multipass-list:
ifeq ($(UNAME), Darwin)
	multipass list
else
	@echo "Multipass VM targets are intended for macOS hosts."
endif

# Compatibility aliases. These do not call the old VM CLI.
.PHONY: container-bootstrap container-up container-reset container-rebuild container-machine-reset
.PHONY: container-shell container-host-shell container-root-shell container-nix-cache
.PHONY: container-hm-switch container-hm-full container-gc container-check
.PHONY: container-create container-machine container-image container-direct-check

container-bootstrap: multipass-bootstrap
container-up: multipass-up
container-reset: multipass-reset
container-rebuild: multipass-rebuild
container-machine-reset: multipass-reset
container-shell: multipass-shell
container-host-shell: multipass-host-shell
container-root-shell: multipass-root-shell
container-nix-cache: multipass-nix-cache
container-hm-switch: multipass-hm-switch
container-hm-full: multipass-hm-full
container-gc: multipass-gc
container-check: multipass-check
container-create: multipass-create
container-machine: multipass-create

container-image:
	@echo "No custom image is built. Multipass uses Ubuntu $(MULTIPASS_IMAGE) and in-VM provisioning."

container-direct-check:
	@echo "No direct image check exists. Use make multipass-check after make multipass-bootstrap."
