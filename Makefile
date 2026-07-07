# SwiftEchada Makefile
# Build and install the echada CLI with full Metal shader support

SCHEME = echada
TEST_SCHEME = SwiftEchada-Package
BINARY = echada
BIN_DIR = ./bin
DESTINATION = platform=macOS,arch=arm64
DERIVED_DATA = $(HOME)/Library/Developer/Xcode/DerivedData

# mlx-swift ships a CudaBuild build-tool plugin and the dependency graph pulls in
# swift-syntax macros; skip their interactive trust prompts so headless/CI builds
# don't stall waiting on a "Validate plug-in" / "trust macro" dialog.
XCODE_FLAGS = -skipPackagePluginValidation -skipMacroValidation

export GIT_LFS_SKIP_SMUDGE = 1

.PHONY: all build release install clean test resolve help integration-test lint codesign-cli

all: install

# Resolve all SPM package dependencies via xcodebuild
resolve:
	xcodebuild -resolvePackageDependencies -scheme $(SCHEME) -destination '$(DESTINATION)'
	@echo "Package dependencies resolved."

# Development build with xcodebuild (Debug)
build: resolve
	xcodebuild -scheme $(SCHEME) -destination '$(DESTINATION)' $(XCODE_FLAGS) build

# Release build with xcodebuild + copy to bin
release: resolve
	xcodebuild -scheme $(SCHEME) -destination '$(DESTINATION)' -configuration Release $(XCODE_FLAGS) build
	@mkdir -p $(BIN_DIR)
	@PRODUCT_DIR=$$(find $(DERIVED_DATA)/SwiftEchada-*/Build/Products/Release -name $(BINARY) -type f -not -path '*.dSYM*' 2>/dev/null | head -1 | xargs dirname); \
	if [ -n "$$PRODUCT_DIR" ]; then \
		cp "$$PRODUCT_DIR/$(BINARY)" $(BIN_DIR)/; \
		chmod +x $(BIN_DIR)/$(BINARY); \
		if [ -d "$$PRODUCT_DIR/mlx-swift_Cmlx.bundle" ]; then \
			rm -rf $(BIN_DIR)/mlx-swift_Cmlx.bundle; \
			cp -R "$$PRODUCT_DIR/mlx-swift_Cmlx.bundle" $(BIN_DIR)/; \
			echo "Installed $(BINARY) + Metal bundle to $(BIN_DIR)/ (Release)"; \
		else \
			echo "Warning: Metal bundle not found, binary may not work"; \
			echo "Installed $(BINARY) to $(BIN_DIR)/ (Release, no Metal bundle)"; \
		fi; \
	else \
		echo "Error: Could not find $(BINARY) in DerivedData"; \
		exit 1; \
	fi

# Debug build with xcodebuild + copy to bin (default)
install: resolve
	xcodebuild -scheme $(SCHEME) -destination '$(DESTINATION)' $(XCODE_FLAGS) build
	@mkdir -p $(BIN_DIR)
	@PRODUCT_DIR=$$(find $(DERIVED_DATA)/SwiftEchada-*/Build/Products/Debug -name $(BINARY) -type f -not -path '*.dSYM*' 2>/dev/null | head -1 | xargs dirname); \
	if [ -n "$$PRODUCT_DIR" ]; then \
		cp "$$PRODUCT_DIR/$(BINARY)" $(BIN_DIR)/; \
		if [ -d "$$PRODUCT_DIR/mlx-swift_Cmlx.bundle" ]; then \
			rm -rf $(BIN_DIR)/mlx-swift_Cmlx.bundle; \
			cp -R "$$PRODUCT_DIR/mlx-swift_Cmlx.bundle" $(BIN_DIR)/; \
			echo "Installed $(BINARY) + Metal bundle to $(BIN_DIR)/ (Debug)"; \
		else \
			echo "Warning: Metal bundle not found, binary may not work"; \
			echo "Installed $(BINARY) to $(BIN_DIR)/ (Debug, no Metal bundle)"; \
		fi; \
	else \
		echo "Error: Could not find $(BINARY) in DerivedData"; \
		exit 1; \
	fi

# Run tests via xcodebuild
test: resolve
	xcodebuild test -scheme $(TEST_SCHEME) -destination '$(DESTINATION)' $(XCODE_FLAGS) -only-testing:SwiftEchadaTests

# Format Swift source files with swift-format
lint:
	swift format -i -r .
	@echo "Swift source files formatted."

# Clean build artifacts
clean:
	xcodebuild clean -scheme $(SCHEME) -destination '$(DESTINATION)' 2>/dev/null || true
	rm -rf $(BIN_DIR)
	rm -rf $(DERIVED_DATA)/SwiftEchada-*

VOX_CLI = ../../../vox-format/bin/vox
DIGA_CLI = ../SwiftVoxAlta/bin/diga

# Integration test: multi-model voice creation → .vox validation → diga synthesis
integration-test: install
	@echo "=== Integration Test: Multi-Model Voice + Synthesis ==="
	@mkdir -p /tmp/echada-integration-test
	@# Build vox validator if needed
	@test -x $(VOX_CLI) || make -C ../../../vox-format install
	@# Step 1: Generate .vox with 0.6b embeddings
	$(BIN_DIR)/echada test-voice --output /tmp/echada-integration-test/narrator.vox --tts-model 0.6b
	@# Step 2: Append 1.7b embeddings to the same .vox
	$(BIN_DIR)/echada test-voice --output /tmp/echada-integration-test/narrator.vox --tts-model 1.7b
	@# Step 3: Validate .vox structure
	$(VOX_CLI) validate --strict /tmp/echada-integration-test/narrator.vox
	@# Step 4: Synthesize and play with both models
	@test -x $(DIGA_CLI) || make -C ../SwiftVoxAlta install
	@echo "--- Synthesizing with 0.6b model ---"
	$(DIGA_CLI) -v /tmp/echada-integration-test/narrator.vox --model 0.6b "The voice of the narrator rings through the empty hall."
	@echo "--- Synthesizing with 1.7b model ---"
	$(DIGA_CLI) -v /tmp/echada-integration-test/narrator.vox --model 1.7b "The voice of the narrator rings through the empty hall."
	@# Clean up
	@rm -rf /tmp/echada-integration-test
	@echo "=== Integration Test PASSED ==="

# ── App Group code-signing ────────────────────────────────────────────────
# Sign the echada CLI with the com.apple.security.application-groups entitlement
# so the group ID is embedded in the binary and SwiftAcervo (reached at runtime
# via SwiftVoxAlta / mlx-audio) resolves the shared models container
# (~/Library/Group Containers/group.intrusive-memory.models/) WITHOUT requiring
# ACERVO_APP_GROUP_ID in the environment. Container access is plain POSIX
# (same-user, mode 700); the entitlement only supplies the group identifier at
# runtime via SecTaskCopyValueForEntitlement.
#
# Default identity is ad-hoc (-). For a distributable build, override with a
# Developer ID by certificate SHA-1 (names collide in the keychain):
#   make install codesign-cli CODESIGN_IDENTITY=<sha1>
APP_GROUP_ID ?= group.intrusive-memory.models
CODESIGN_IDENTITY ?= -
CODESIGN_FLAGS ?=
CODESIGN_ENTITLEMENTS ?= cli.entitlements

codesign-cli:
	@test -f "$(BIN_DIR)/$(BINARY)" || { echo "Error: $(BIN_DIR)/$(BINARY) not found — run 'make install' or 'make release' first."; exit 1; }
	@codesign --force --sign "$(CODESIGN_IDENTITY)" --entitlements "$(CODESIGN_ENTITLEMENTS)" $(CODESIGN_FLAGS) "$(BIN_DIR)/$(BINARY)"
	@echo "Signed $(BIN_DIR)/$(BINARY) (identity: $(CODESIGN_IDENTITY), group: $(APP_GROUP_ID))"
	@codesign -d --entitlements - "$(BIN_DIR)/$(BINARY)" 2>/dev/null | grep -A1 "application-groups" || true

help:
	@echo "SwiftEchada Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  resolve          - Resolve all SPM package dependencies"
	@echo "  build            - Debug build with xcodebuild"
	@echo "  install          - Debug build + copy to ./bin (default)"
	@echo "  release          - Release build + copy to ./bin"
	@echo "  test             - Run unit tests with xcodebuild"
	@echo "  integration-test - Voice creation pipeline integration test"
	@echo "  lint             - Format Swift source files with swift-format"
	@echo "  codesign-cli     - Sign the echada CLI with the App Group entitlement (run after install/release)"
	@echo "  clean            - Clean build artifacts"
	@echo "  help             - Show this help"
	@echo ""
	@echo "All builds use: -destination '$(DESTINATION)'"
