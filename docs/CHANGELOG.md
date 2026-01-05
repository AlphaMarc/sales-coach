# Changelog

All notable changes to Sales Coach will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **One-command installation** - New `make install` target for complete setup, build, and launch
  - Prerequisite checks (macOS version, Xcode CLI tools, Apple Silicon)
  - Clear error messages for missing requirements
  - Single command from clone to running app
- **Enhanced Langfuse session tracking** - Full session lifecycle with statistics
  - Session start trace with comprehensive configuration metadata
  - Session end trace with duration, token usage, and final state
  - Real-time session statistics tracking (LLM calls, ticks, tokens)
  - Session ID propagated to all traces for easy grouping in Langfuse UI
- **Langfuse integration for LLM observability** - Track and analyze LLM calls with Langfuse
  - Execution traces for every LLM call (input, output, latency, tokens)
  - Session tracking to group traces by coaching session
  - Remote prompt management with Langfuse prompts
  - Automatic fallback to local prompts when Langfuse unavailable
  - New "Observability" tab in Settings for configuration
  - Secure storage of Langfuse API keys in Keychain
- **Multilingual transcription support** - Now supports English and French with automatic language detection
  - Uses `ggml-base.bin` multilingual model instead of English-only model
  - Language auto-detection enabled by default (`"auto"`)
  - Can be set to specific language via `TranscriberConfig.language` (e.g., `"en"`, `"fr"`)
- Initial implementation of Sales Coach macOS app
- Real-time audio capture using AVAudioEngine
- Local speech-to-text using whisper.cpp CLI
- LLM integration for coaching analysis
  - Local mode via LM Studio (OpenAI-compatible API)
  - Cloud mode via OpenAI-compatible APIs
- MEDDIC framework tracking with evidence extraction
- Process adherence monitoring with alerts
- Suggested question generation (priority-ranked)
- SwiftUI interface with split-view layout
  - Live transcript panel with timestamps
  - Coaching insights panel with MEDDIC table
- Settings management
  - LLM configuration (local/cloud)
  - Audio device selection
  - Coaching interval customization
- Session persistence and export (JSON, plain text, CSV)
- CI/CD pipeline with GitHub Actions
  - Automated builds on push
  - Manual workflow dispatch for one-click builds
  - Artifact upload (app bundle and DMG)
- Fastlane `launch` lane for building and launching the app in one command
  - Use `make run` or `bundle exec fastlane launch`

### Changed
- `Gemfile.lock` is now committed for reproducible builds across environments

### Technical
- Swift 5.9+ with async/await concurrency
- Actor-based architecture for thread safety
- Protocol-based LLM client abstraction
- JSON schema validation with repair flow
- Keychain storage for API keys
- UserDefaults for settings persistence
- Makefile with prerequisite validation and unified install target

## [0.1.0] - TBD

- Initial release

---

## Version History

| Version | Date | Notes |
|---------|------|-------|
| 0.1.0 | TBD | Initial release |

