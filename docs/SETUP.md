# Development Setup Guide

This guide covers setting up the Sales Coach development environment on macOS.

## Prerequisites

### Required

- **macOS 14.0+** (Sonoma or later)
- **Xcode 15.2+** with Command Line Tools
- **Apple Silicon Mac** (M1/M2/M3/M4)
- **Git**

### Optional

- **LM Studio** - For local LLM inference
- **Homebrew** - For additional tools

## Quick Setup (One Command)

```bash
git clone https://github.com/your-org/sales-coach.git
cd sales-coach
make install
```

This single command will:
1. ✅ Verify system prerequisites (macOS 14+, Xcode CLI tools, Apple Silicon)
2. 📦 Install Ruby dependencies (Fastlane)
3. 🔧 Build whisper.cpp for local transcription
4. 📥 Download the Whisper model (~140MB)
5. 🏗️ Build the application
6. 🚀 Launch Sales Coach

> **Note**: First-time setup takes 5-10 minutes due to compiling whisper.cpp and downloading the model.

### Alternative: Step-by-Step

If you prefer more control, you can run the steps separately:

```bash
make check-prereqs  # Verify prerequisites
make setup          # Install dependencies and build whisper.cpp
make build          # Build the app
make open-app       # Launch the app
```

## Detailed Setup

### 1. Install Xcode

1. Install from Mac App Store
2. Open Xcode once to complete installation
3. Install Command Line Tools:
   ```bash
   xcode-select --install
   ```

### 2. Install Ruby Dependencies

The project uses Fastlane for build automation:

```bash
# Install bundler
gem install bundler

# Install gems (Fastlane)
bundle install
```

### 3. Build whisper.cpp

The transcription engine needs to be compiled:

```bash
# Automated build
.github/scripts/build-whisper.sh

# This will:
# 1. Clone whisper.cpp v1.5.4
# 2. Compile for Apple Silicon
# 3. Download base English model (~140MB)
```

After building, you'll have:
- `whisper.cpp/main` - The CLI binary
- `whisper.cpp/models/ggml-base.en.bin` - The model file

### 4. Configure LM Studio (Local LLM)

For fully offline operation:

1. Download [LM Studio](https://lmstudio.ai/)
2. Open LM Studio
3. Download a model:
   - Recommended: Llama 3 8B Instruct
   - Alternative: Mistral 7B Instruct
4. Load the model
5. Start the local server:
   - Click "Local Server" tab
   - Click "Start Server"
   - Default URL: http://localhost:1234

### 5. Build the App

```bash
# Debug build
make build

# Or open in Xcode
make xcode
```

## Project Structure

```
sales-coach/
├── SalesCoach/
│   ├── SalesCoach.xcodeproj    # Xcode project
│   ├── Sources/                 # Swift source files
│   ├── Resources/               # Assets, bundled binaries
│   └── Tests/                   # Unit tests
├── whisper.cpp/                 # whisper.cpp (built during setup)
├── fastlane/                    # Fastlane configuration
├── docs/                        # Documentation
├── .github/                     # CI/CD workflows
├── Makefile                     # Build commands
└── Gemfile                      # Ruby dependencies
```

## Common Tasks

### Quick Start

```bash
make install        # One-command: setup + build + launch (recommended first-time)
make check-prereqs  # Verify system prerequisites only
```

### Building

```bash
make build          # Debug build
make build-release  # Release build with DMG
make run            # Build and run in one command
make test           # Run unit tests
make clean          # Clean all build artifacts
```

### Running

```bash
make run            # Build and run (recommended)
make open-app       # Open already-built app
# Or run from Xcode (⌘R)
```

### Testing

```bash
# Run all tests
make test

# Run from Xcode
# ⌘U or Product → Test
```

## Troubleshooting

### Prerequisite Check Fails

If `make install` or `make check-prereqs` fails:

**"Xcode Command Line Tools required"**
```bash
xcode-select --install
```

**"macOS 14.0+ required"**
- Update to macOS Sonoma or later via System Settings → General → Software Update

**"Apple Silicon recommended" (warning)**
- Intel Macs can run the app but with reduced transcription performance
- Consider using a cloud-based Whisper API instead

### whisper.cpp Build Fails

```bash
# Clean and rebuild
rm -rf whisper.cpp
.github/scripts/build-whisper.sh
```

### Microphone Permission Denied

1. Open System Settings
2. Privacy & Security → Microphone
3. Enable for Sales Coach (or Xcode during development)

### LM Studio Connection Failed

1. Verify LM Studio is running
2. Check server is started (Local Server tab)
3. Verify URL in Settings (default: http://localhost:1234/v1)
4. Test with curl:
   ```bash
   curl http://localhost:1234/v1/models
   ```

### Build Errors in Xcode

1. Clean build folder: ⌘⇧K
2. Clean DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
3. Close and reopen Xcode

### Missing whisper-cli in App Bundle

Ensure the binary is copied to Resources:
```bash
cp whisper.cpp/main SalesCoach/Resources/whisper-cli
cp whisper.cpp/models/ggml-base.en.bin SalesCoach/Resources/
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `XCODE_VERSION` | Xcode version for CI | 15.2 |

## IDE Configuration

### Xcode Settings

Recommended settings for development:

1. **Text Editing**
   - Indent: 4 spaces
   - Line wrapping: at page guide

2. **Build Settings**
   - Enable strict concurrency checking
   - Enable upcoming Swift features

### SwiftLint (Optional)

If you want to add SwiftLint:

```bash
brew install swiftlint
```

Add to Xcode build phases or run manually:
```bash
swiftlint
```

## Updating Dependencies

### whisper.cpp

```bash
cd whisper.cpp
git fetch origin
git checkout v1.x.x  # New version
make clean
make main
```

### Fastlane

```bash
bundle update fastlane
```

## Creating Releases

1. Update version in Xcode project
2. Update CHANGELOG.md
3. Tag the release:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
4. CI will create build artifacts

