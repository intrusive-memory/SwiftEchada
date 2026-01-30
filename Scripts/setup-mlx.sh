#!/bin/bash
# Setup MLX metallib for SwiftEchada CLI
set -e

echo "🔧 SwiftEchada MLX Setup"
echo ""

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found. Please install Homebrew first:"
    echo "   https://brew.sh"
    exit 1
fi

# Check if MLX is installed
if ! brew list mlx &> /dev/null; then
    echo "📦 Installing MLX via Homebrew..."
    brew install mlx
    echo "✅ MLX installed"
else
    echo "✅ MLX already installed"
fi

# Find MLX metallib
METALLIB_PATH=$(find /opt/homebrew/Cellar/mlx -name "mlx.metallib" | head -1)
if [ -z "$METALLIB_PATH" ]; then
    echo "❌ Could not find mlx.metallib in Homebrew installation"
    exit 1
fi

echo "📍 Found metallib: $METALLIB_PATH"

# Copy to release build directory
BUILD_DIR=".build/release"
if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p "$BUILD_DIR"
fi

echo "📋 Copying metallib to $BUILD_DIR..."
cp "$METALLIB_PATH" "$BUILD_DIR/mlx.metallib"
chmod 644 "$BUILD_DIR/mlx.metallib"

echo "✅ MLX setup complete!"
echo ""
echo "You can now run:"
echo "  swift build -c release"
echo "  .build/release/echada --help"
