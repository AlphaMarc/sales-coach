.PHONY: build build-release run test clean setup open-app whisper app-icon install check-prereqs

# ====================
# ONE-COMMAND INSTALL
# ====================

# Complete setup, build, and launch in one command
install: check-prereqs setup build open-app
	@echo ""
	@echo "=== SalesCoach installed and running! ==="
	@echo ""

# ====================
# PREREQUISITE CHECKS
# ====================

check-prereqs:
	@echo "=== Checking prerequisites ==="
	@command -v git >/dev/null 2>&1 || { echo "❌ Error: git is required but not installed."; exit 1; }
	@command -v xcodebuild >/dev/null 2>&1 || { echo "❌ Error: Xcode Command Line Tools required. Run: xcode-select --install"; exit 1; }
	@command -v make >/dev/null 2>&1 || { echo "❌ Error: make is required but not installed."; exit 1; }
	@if [ "$$(uname -m)" != "arm64" ]; then \
		echo "⚠️  Warning: Apple Silicon (M1/M2/M3/M4) recommended for optimal performance"; \
	fi
	@SW_VERS=$$(sw_vers -productVersion | cut -d. -f1); \
	if [ "$$SW_VERS" -lt 14 ]; then \
		echo "❌ Error: macOS 14.0+ (Sonoma) required. Current: $$(sw_vers -productVersion)"; \
		exit 1; \
	fi
	@echo "✅ All prerequisites satisfied"

# ====================
# BUILD COMMANDS
# ====================

# One-click local build
build: whisper
	bundle exec fastlane build_debug

build-release: whisper
	bundle exec fastlane build_release

# Build and run the app in one command
run: whisper
	bundle exec fastlane launch

test:
	bundle exec fastlane test

# Build whisper.cpp if needed
whisper:
	@if [ ! -f "whisper.cpp/main" ]; then \
		echo "Building whisper.cpp..."; \
		.github/scripts/build-whisper.sh; \
	fi

# ====================
# SETUP
# ====================

# Initial setup (installs dependencies, builds whisper.cpp)
setup: check-prereqs
	@echo "=== Setting up SalesCoach development environment ==="
	@echo "Installing Ruby dependencies..."
	gem install bundler --no-document
	bundle install
	@echo "Building whisper.cpp (this may take a few minutes)..."
	chmod +x .github/scripts/build-whisper.sh
	.github/scripts/build-whisper.sh
	@echo ""
	@echo "=== Setup complete! ==="

# ====================
# UTILITIES
# ====================

# Clean build artifacts
clean:
	rm -rf build/
	rm -rf SalesCoach/build/
	xcodebuild clean -project SalesCoach/SalesCoach.xcodeproj -scheme SalesCoach 2>/dev/null || true

# Generate app icons from source image
# Usage: make app-icon SOURCE=path/to/logo.png
app-icon:
	@if [ -z "$(SOURCE)" ]; then \
		echo "Usage: make app-icon SOURCE=path/to/logo.png"; \
		exit 1; \
	fi
	./scripts/generate-app-icons.sh "$(SOURCE)"

# Open built app
open-app:
	open build/SalesCoach.app

# Open project in Xcode
xcode:
	open SalesCoach/SalesCoach.xcodeproj

# Development helpers
dev-setup: setup
	@echo "Opening Xcode project..."
	open SalesCoach/SalesCoach.xcodeproj

# ====================
# HELP
# ====================

help:
	@echo ""
	@echo "SalesCoach Build Commands:"
	@echo ""
	@echo "  Quick Start:"
	@echo "    make install     - One-command setup, build, and launch (recommended for first-time)"
	@echo ""
	@echo "  Build:"
	@echo "    make setup       - First-time setup (install dependencies, build whisper)"
	@echo "    make build       - Build debug version"
	@echo "    make build-release - Build release version with DMG"
	@echo "    make run         - Build and run the app"
	@echo ""
	@echo "  Development:"
	@echo "    make test        - Run unit tests"
	@echo "    make clean       - Clean build artifacts"
	@echo "    make xcode       - Open project in Xcode"
	@echo "    make open-app    - Open the built app"
	@echo ""
	@echo "  Utilities:"
	@echo "    make app-icon SOURCE=<image> - Generate app icons from source image"
	@echo "    make check-prereqs - Verify system prerequisites"
	@echo ""
