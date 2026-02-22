# SwiftEchada Makefile
# Build and install the echada CLI with full Metal shader support

SCHEME = echada
TEST_SCHEME = SwiftEchada-Package
BINARY = echada
BIN_DIR = ./bin
DESTINATION = platform=macOS,arch=arm64
DERIVED_DATA = $(HOME)/Library/Developer/Xcode/DerivedData

export GIT_LFS_SKIP_SMUDGE = 1

.PHONY: all build release install clean test resolve help integration-test

all: install

# Resolve all SPM package dependencies via xcodebuild
resolve:
	xcodebuild -resolvePackageDependencies -scheme $(SCHEME) -destination '$(DESTINATION)'
	@echo "Package dependencies resolved."

# Development build with xcodebuild (Debug)
build: resolve
	xcodebuild -scheme $(SCHEME) -destination '$(DESTINATION)' build

# Release build with xcodebuild + copy to bin
release: resolve
	xcodebuild -scheme $(SCHEME) -destination '$(DESTINATION)' -configuration Release build
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
	xcodebuild -scheme $(SCHEME) -destination '$(DESTINATION)' build
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
	xcodebuild test -scheme $(TEST_SCHEME) -destination '$(DESTINATION)' -only-testing:SwiftEchadaTests

# Clean build artifacts
clean:
	xcodebuild clean -scheme $(SCHEME) -destination '$(DESTINATION)' 2>/dev/null || true
	rm -rf $(BIN_DIR)
	rm -rf $(DERIVED_DATA)/SwiftEchada-*

VOX_CLI = ../vox-format/bin/vox

# Integration test: voice creation pipeline → .vox validation
integration-test: install
	@echo "=== Integration Test: Voice Creation ==="
	@mkdir -p /tmp/echada-integration-test
	@# Build vox validator if needed
	@test -x $(VOX_CLI) || make -C ../vox-format install
	@# Run voice creation
	$(BIN_DIR)/echada test-voice --output /tmp/echada-integration-test/narrator.vox
	@# Validate with vox
	$(VOX_CLI) validate --strict /tmp/echada-integration-test/narrator.vox
	@# Clean up
	@rm -rf /tmp/echada-integration-test
	@echo "=== Integration Test PASSED ==="

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
	@echo "  clean            - Clean build artifacts"
	@echo "  help             - Show this help"
	@echo ""
	@echo "All builds use: -destination '$(DESTINATION)'"
