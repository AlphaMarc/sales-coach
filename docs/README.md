# Sales Coach

A native macOS application for real-time sales call transcription and AI-powered coaching. Built with SwiftUI, whisper.cpp for local speech-to-text, and LLM integration for intelligent coaching insights.

## Features

- **Real-time Transcription**: Local speech-to-text using whisper.cpp on Apple Silicon
- **AI Coaching**: Intelligent analysis every X seconds with process adherence tracking
- **MEDDIC Framework**: Automatic extraction and tracking of MEDDIC qualification data
- **Suggested Questions**: Context-aware question suggestions during calls
- **Privacy-First**: Fully offline operation with local models, no audio upload
- **Export**: Session export in JSON, plain text, or CSV formats

## Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4)
- Xcode 15.2+
- LM Studio (for local LLM) or OpenAI-compatible API

## Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/your-org/sales-coach.git
cd sales-coach
make setup
```

This will:
- Install Ruby dependencies (Fastlane)
- Build whisper.cpp for Apple Silicon
- Download the base English whisper model (~140MB)

### 2. Build the App

```bash
make build
make open-app
```

### 3. Configure LM Studio (for local LLM)

1. Download [LM Studio](https://lmstudio.ai/)
2. Load a model (recommended: Llama 3 8B or Mistral 7B)
3. Start the local server (default: http://localhost:1234)
4. In Sales Coach settings, verify "Local (LM Studio)" is selected

## Usage

### Starting a Session

1. Launch Sales Coach
2. Click "Start Recording" or press ⌘R
3. Begin your sales call
4. Watch the transcript appear in real-time
5. Review coaching insights in the right panel

### Coaching Panel

- **Current Stage**: Detected phase of the sales conversation
- **Suggested Questions**: Priority-ranked questions to ask next
- **MEDDIC Table**: Extracted qualification data with evidence

### Exporting

After ending a session:
- Press ⌘E to export
- Choose format: JSON, Plain Text, or CSV
- Files are saved to `~/Library/Application Support/SalesCoach/exports/`

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed system design.

## Development

### Project Structure

```
SalesCoach/
├── Sources/
│   ├── App/         # App entry point and global state
│   ├── Views/       # SwiftUI views
│   ├── Core/        # Business logic and orchestration
│   ├── Audio/       # Audio capture services
│   ├── STT/         # Speech-to-text (whisper.cpp)
│   ├── LLM/         # LLM client implementations
│   ├── Models/      # Data models
│   ├── Persistence/ # Storage services
│   └── Utilities/   # Helper functions
├── Resources/       # Assets and bundled binaries
└── Tests/           # Unit and integration tests
```

### Build Commands

```bash
make build        # Debug build
make build-release # Release build with DMG
make test         # Run unit tests
make clean        # Clean build artifacts
make xcode        # Open in Xcode
```

### CI/CD

GitHub Actions workflow provides:
- Automatic builds on push to main
- Manual trigger for one-click builds
- Artifact download (app bundle and DMG)

Trigger a build:
1. Go to Actions tab
2. Select "Build macOS App"
3. Click "Run workflow"
4. Download artifact when complete

## Configuration

### Settings Location

- App settings: `UserDefaults`
- API keys: macOS Keychain
- Sessions: `~/Library/Application Support/SalesCoach/sessions/`

### LLM Modes

1. **Local (LM Studio)**
   - Default: http://localhost:1234/v1
   - No API key required
   - Fully offline operation

2. **Cloud (OpenAI-compatible)**
   - Supports OpenAI, Azure, Anthropic (via proxy)
   - Requires API key
   - Transcript text sent to cloud (no audio)

## Privacy & Security

- Audio is never uploaded (local transcription only)
- Transcript text only sent to configured LLM endpoint
- API keys stored in macOS Keychain
- All data stored locally in Application Support

## License

MIT License - see LICENSE file for details.

