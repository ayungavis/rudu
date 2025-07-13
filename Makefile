# Makefile for rudu

# Variables
BINARY_NAME := rudu
INSTALL_PATH := /usr/local/bin
CARGO := cargo
TARGET_DIR := target
RELEASE_DIR := $(TARGET_DIR)/release

# Default target
.PHONY: all
all: build

# Build the project
.PHONY: build
build:
	$(CARGO) build --release

# Run tests
.PHONY: test
test:
	$(CARGO) test

# Run all checks (format, clippy, test)
.PHONY: check
check:
	$(CARGO) fmt --all -- --check
	$(CARGO) clippy --all-targets --all-features -- -D warnings
	$(CARGO) test --all-features --workspace

# Format code
.PHONY: fmt
fmt:
	$(CARGO) fmt --all

# Install locally
.PHONY: install
install: build
	@echo "Installing $(BINARY_NAME) to $(INSTALL_PATH)"
	@if [ -w $(INSTALL_PATH) ]; then \
		cp $(RELEASE_DIR)/$(BINARY_NAME) $(INSTALL_PATH)/$(BINARY_NAME); \
		chmod +x $(INSTALL_PATH)/$(BINARY_NAME); \
	else \
		echo "Need sudo privileges to install to $(INSTALL_PATH)"; \
		sudo cp $(RELEASE_DIR)/$(BINARY_NAME) $(INSTALL_PATH)/$(BINARY_NAME); \
		sudo chmod +x $(INSTALL_PATH)/$(BINARY_NAME); \
	fi
	@echo "Installation complete!"

# Install to user's local bin
.PHONY: install-user
install-user: build
	@mkdir -p ~/.local/bin
	@cp $(RELEASE_DIR)/$(BINARY_NAME) ~/.local/bin/$(BINARY_NAME)
	@chmod +x ~/.local/bin/$(BINARY_NAME)
	@echo "Installed $(BINARY_NAME) to ~/.local/bin"
	@echo "Make sure ~/.local/bin is in your PATH"

# Uninstall
.PHONY: uninstall
uninstall:
	@if [ -f $(INSTALL_PATH)/$(BINARY_NAME) ]; then \
		if [ -w $(INSTALL_PATH) ]; then \
			rm $(INSTALL_PATH)/$(BINARY_NAME); \
		else \
			sudo rm $(INSTALL_PATH)/$(BINARY_NAME); \
		fi; \
		echo "Uninstalled $(BINARY_NAME) from $(INSTALL_PATH)"; \
	else \
		echo "$(BINARY_NAME) not found in $(INSTALL_PATH)"; \
	fi

# Clean build artifacts
.PHONY: clean
clean:
	$(CARGO) clean

# Build for all supported targets
.PHONY: build-all
build-all:
	$(CARGO) build --release --target x86_64-unknown-linux-gnu
	$(CARGO) build --release --target x86_64-unknown-linux-musl
	$(CARGO) build --release --target x86_64-apple-darwin
	$(CARGO) build --release --target aarch64-apple-darwin

# Create release archives
.PHONY: release
release: build-all
	@mkdir -p dist
	@# Linux x86_64
	@tar -czf dist/$(BINARY_NAME)-linux-x86_64.tar.gz -C target/x86_64-unknown-linux-gnu/release $(BINARY_NAME)
	@# Linux x86_64 musl
	@tar -czf dist/$(BINARY_NAME)-linux-x86_64-musl.tar.gz -C target/x86_64-unknown-linux-musl/release $(BINARY_NAME)
	@# macOS x86_64
	@tar -czf dist/$(BINARY_NAME)-macos-x86_64.tar.gz -C target/x86_64-apple-darwin/release $(BINARY_NAME)
	@# macOS ARM64
	@tar -czf dist/$(BINARY_NAME)-macos-aarch64.tar.gz -C target/aarch64-apple-darwin/release $(BINARY_NAME)
	@echo "Release archives created in dist/"

# Show help
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  build       - Build the project in release mode"
	@echo "  test        - Run tests"
	@echo "  check       - Run format, clippy, and tests"
	@echo "  fmt         - Format code"
	@echo "  install     - Install to $(INSTALL_PATH) (may require sudo)"
	@echo "  install-user- Install to ~/.local/bin"
	@echo "  uninstall   - Remove from $(INSTALL_PATH)"
	@echo "  clean       - Clean build artifacts"
	@echo "  build-all   - Build for all supported targets"
	@echo "  release     - Create release archives"
	@echo "  help        - Show this help message" 