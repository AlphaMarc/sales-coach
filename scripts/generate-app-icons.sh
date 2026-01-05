#!/bin/bash
#
# generate-app-icons.sh
# Generates all required macOS app icon sizes from a source image
#
# Usage: ./scripts/generate-app-icons.sh <source-image>
#
# The script will:
# 1. Create a square canvas with the specified background color
# 2. Center the source image on the canvas
# 3. Generate all required sizes for macOS app icons
#

set -e

# Configuration
BACKGROUND_COLOR="#353642"
OUTPUT_DIR="SalesCoach/Resources/Assets.xcassets/AppIcon.appiconset"

# Required sizes for macOS app icons (actual pixel sizes)
SIZES=(16 32 64 128 256 512 1024)

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <source-image>"
    echo "Example: $0 logo.png"
    exit 1
fi

SOURCE_IMAGE="$1"

if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "Error: Source image '$SOURCE_IMAGE' not found"
    exit 1
fi

# Check for ImageMagick
if ! command -v magick &> /dev/null && ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick is required but not installed."
    echo "Install with: brew install imagemagick"
    exit 1
fi

# Use 'magick' if available (ImageMagick 7), otherwise fall back to 'convert' (ImageMagick 6)
if command -v magick &> /dev/null; then
    CONVERT="magick"
else
    CONVERT="convert"
fi

echo "=== Generating App Icons ==="
echo "Source: $SOURCE_IMAGE"
echo "Background: $BACKGROUND_COLOR"
echo "Output: $OUTPUT_DIR"
echo ""

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Create a temporary directory for intermediate files
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# First, create the 1024x1024 master icon with background
echo "Creating master icon (1024x1024)..."

# Get source image dimensions
SOURCE_WIDTH=$($CONVERT "$SOURCE_IMAGE" -format "%w" info:)
SOURCE_HEIGHT=$($CONVERT "$SOURCE_IMAGE" -format "%h" info:)

# Calculate the size to fit the logo (80% of canvas to leave padding)
LOGO_MAX_SIZE=820

# Create the master icon:
# 1. Create background
# 2. Resize source image maintaining aspect ratio
# 3. Center composite
$CONVERT -size 1024x1024 "xc:$BACKGROUND_COLOR" "$TEMP_DIR/background.png"

$CONVERT "$SOURCE_IMAGE" \
    -resize "${LOGO_MAX_SIZE}x${LOGO_MAX_SIZE}" \
    -background none \
    "$TEMP_DIR/logo_resized.png"

$CONVERT "$TEMP_DIR/background.png" "$TEMP_DIR/logo_resized.png" \
    -gravity center \
    -composite \
    "$TEMP_DIR/master_icon.png"

echo "Master icon created."
echo ""

# Generate all required sizes
echo "Generating icon sizes..."

# Generate each size (filename:pixel_size pairs)
for entry in \
    "icon_16x16.png:16" \
    "icon_16x16@2x.png:32" \
    "icon_32x32.png:32" \
    "icon_32x32@2x.png:64" \
    "icon_128x128.png:128" \
    "icon_128x128@2x.png:256" \
    "icon_256x256.png:256" \
    "icon_256x256@2x.png:512" \
    "icon_512x512.png:512" \
    "icon_512x512@2x.png:1024"
do
    filename="${entry%%:*}"
    size="${entry##*:}"
    echo "  Creating $filename (${size}x${size}px)..."
    $CONVERT "$TEMP_DIR/master_icon.png" \
        -resize "${size}x${size}" \
        -strip \
        "$OUTPUT_DIR/$filename"
done

echo ""
echo "=== Done! ==="
echo "Generated icons in: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "1. Regenerate the Xcode project: bundle exec fastlane regenerate_project"
echo "2. Build the app: make build"

