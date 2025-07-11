# NixOS and nix-darwin configuration management
# Usage: make <target>

# Variables
DARWIN_HOST := macbook
LINUX_HOST := ubuntu
FLAKE_PATH := .

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Default target
.PHONY: help
help:
	@echo "$(BLUE)NixOS and nix-darwin Configuration Management$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@echo "  $(YELLOW)darwin-switch$(NC)     - Switch to darwin configuration"
	@echo "  $(YELLOW)linux-switch$(NC)      - Switch to linux configuration"
	@echo "  $(YELLOW)darwin-test$(NC)       - Test darwin configuration (dry-run)"
	@echo "  $(YELLOW)linux-test$(NC)        - Test linux configuration (dry-run)"
	@echo "  $(YELLOW)darwin-build$(NC)      - Build darwin configuration"
	@echo "  $(YELLOW)linux-build$(NC)       - Build linux configuration"
	@echo "  $(YELLOW)darwin-activate$(NC)   - Activate darwin configuration"
	@echo "  $(YELLOW)linux-activate$(NC)    - Activate linux configuration"
	@echo "  $(YELLOW)update$(NC)            - Update all flake inputs"
	@echo "  $(YELLOW)update-darwin$(NC)     - Update darwin-specific inputs"
	@echo "  $(YELLOW)update-linux$(NC)      - Update linux-specific inputs"
	@echo "  $(YELLOW)gc$(NC)                - Garbage collect old generations"
	@echo "  $(YELLOW)clean$(NC)             - Clean build artifacts"
	@echo "  $(YELLOW)format$(NC)            - Format all Nix files"
	@echo "  $(YELLOW)check$(NC)             - Check Nix syntax and formatting"
	@echo "  $(YELLOW)shell$(NC)             - Enter development shell"
	@echo ""

# Darwin (M1 Mac) targets
.PHONY: darwin-switch
darwin-switch:
	@echo "$(BLUE)Switching to darwin configuration...$(NC)"
	@nix build $(FLAKE_PATH)#darwinConfigurations.$(DARWIN_HOST).system
	@./result/sw/bin/darwin-rebuild switch --flake $(FLAKE_PATH)#$(DARWIN_HOST)
	@echo "$(GREEN)Darwin configuration activated successfully!$(NC)"

.PHONY: darwin-test
darwin-test:
	@echo "$(BLUE)Testing darwin configuration (dry-run)...$(NC)"
	@nix build $(FLAKE_PATH)#darwinConfigurations.$(DARWIN_HOST).system
	@./result/sw/bin/darwin-rebuild build --flake $(FLAKE_PATH)#$(DARWIN_HOST)
	@echo "$(GREEN)Darwin configuration test completed successfully!$(NC)"

.PHONY: darwin-build
darwin-build:
	@echo "$(BLUE)Building darwin configuration...$(NC)"
	@nix build $(FLAKE_PATH)#darwinConfigurations.$(DARWIN_HOST).system
	@echo "$(GREEN)Darwin configuration built successfully!$(NC)"

.PHONY: darwin-activate
darwin-activate:
	@echo "$(BLUE)Activating darwin configuration...$(NC)"
	@nix build $(FLAKE_PATH)#darwinConfigurations.$(DARWIN_HOST).system
	@./result/sw/bin/darwin-rebuild activate --flake $(FLAKE_PATH)#$(DARWIN_HOST)
	@echo "$(GREEN)Darwin configuration activated!$(NC)"

# Linux (NixOS) targets
.PHONY: linux-switch
linux-switch:
	@echo "$(BLUE)Switching to linux configuration...$(NC)"
	@sudo nixos-rebuild switch --flake $(FLAKE_PATH)#$(LINUX_HOST)
	@echo "$(GREEN)Linux configuration activated successfully!$(NC)"

.PHONY: linux-test
linux-test:
	@echo "$(BLUE)Testing linux configuration (dry-run)...$(NC)"
	@sudo nixos-rebuild build --flake $(FLAKE_PATH)#$(LINUX_HOST)
	@echo "$(GREEN)Linux configuration test completed successfully!$(NC)"

.PHONY: linux-build
linux-build:
	@echo "$(BLUE)Building linux configuration...$(NC)"
	@nix build $(FLAKE_PATH)#nixosConfigurations.$(LINUX_HOST).config.system.build.toplevel
	@echo "$(GREEN)Linux configuration built successfully!$(NC)"

.PHONY: linux-activate
linux-activate:
	@echo "$(BLUE)Activating linux configuration...$(NC)"
	@sudo nixos-rebuild boot --flake $(FLAKE_PATH)#$(LINUX_HOST)
	@echo "$(GREEN)Linux configuration will be activated on next boot!$(NC)"

# Update targets
.PHONY: update
update:
	@echo "$(BLUE)Updating all flake inputs...$(NC)"
	@nix flake update
	@echo "$(GREEN)All flake inputs updated!$(NC)"

.PHONY: update-darwin
update-darwin:
	@echo "$(BLUE)Updating darwin-specific inputs...$(NC)"
	@nix flake lock --update-input nix-darwin
	@nix flake lock --update-input home-manager
	@echo "$(GREEN)Darwin inputs updated!$(NC)"

.PHONY: update-linux
update-linux:
	@echo "$(BLUE)Updating linux-specific inputs...$(NC)"
	@nix flake lock --update-input nixpkgs
	@nix flake lock --update-input home-manager
	@echo "$(GREEN)Linux inputs updated!$(NC)"

# Utility targets
.PHONY: gc
gc:
	@echo "$(BLUE)Running garbage collection...$(NC)"
	@nix-collect-garbage -d
	@echo "$(GREEN)Garbage collection completed!$(NC)"

.PHONY: clean
clean:
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	@rm -rf result
	@rm -rf .nix
	@echo "$(GREEN)Build artifacts cleaned!$(NC)"

.PHONY: format
format:
	@echo "$(BLUE)Formatting Nix files...$(NC)"
	@nix fmt
	@echo "$(GREEN)Nix files formatted!$(NC)"

.PHONY: check
check:
	@echo "$(BLUE)Checking Nix syntax and formatting...$(NC)"
	@nix flake check
	@echo "$(GREEN)Nix syntax and formatting check passed!$(NC)"

.PHONY: shell
shell:
	@echo "$(BLUE)Entering development shell...$(NC)"
	@nix develop

# Convenience targets for current system detection
.PHONY: switch
switch:
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "$(BLUE)Detected Darwin system, switching to darwin configuration...$(NC)"; \
		$(MAKE) darwin-switch; \
	else \
		echo "$(BLUE)Detected Linux system, switching to linux configuration...$(NC)"; \
		$(MAKE) linux-switch; \
	fi

.PHONY: test
test:
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "$(BLUE)Detected Darwin system, testing darwin configuration...$(NC)"; \
		$(MAKE) darwin-test; \
	else \
		echo "$(BLUE)Detected Linux system, testing linux configuration...$(NC)"; \
		$(MAKE) linux-test; \
	fi

# Show current system info
.PHONY: info
info:
	@echo "$(BLUE)System Information:$(NC)"
	@echo "  OS: $$(uname -s)"
	@echo "  Architecture: $$(uname -m)"
	@echo "  Hostname: $$(hostname)"
	@echo "  Nix Version: $$(nix --version | head -n1)"
	@echo "  Flake Path: $(FLAKE_PATH)"
	@echo "  Darwin Host: $(DARWIN_HOST)"
	@echo "  Linux Host: $(LINUX_HOST)" 
