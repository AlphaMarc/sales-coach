# Sales Coach

A native macOS application for real-time sales call transcription and AI-powered coaching.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Real-time Transcription** - Local speech-to-text using whisper.cpp on Apple Silicon
- **AI Coaching** - Intelligent analysis with process adherence tracking
- **MEDDIC Framework** - Automatic extraction and tracking of qualification data
- **Privacy-First** - Fully offline operation with local models
- **Export** - Session export in JSON, plain text, or CSV

## Quick Start

```bash
git clone https://github.com/your-org/sales-coach.git
cd sales-coach
make install
```

That's it! The `make install` command will:
1. ✅ Verify system prerequisites (macOS 14+, Xcode CLI, Apple Silicon)
2. 📦 Install Ruby dependencies (Fastlane)
3. 🔧 Build whisper.cpp for local transcription
4. 📥 Download the Whisper model (~140MB)
5. 🏗️ Build the application
6. 🚀 Launch Sales Coach

> **Note**: First-time setup takes 5-10 minutes due to compiling whisper.cpp and downloading the model.

## Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4)
- Xcode 15.2+
- LM Studio (for local LLM)

## Documentation

- [Full Documentation](docs/README.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Setup Guide](docs/SETUP.md)
- [Changelog](docs/CHANGELOG.md)

## License

MIT License - see [LICENSE](LICENSE) for details.

