# Sales Coach Architecture

## System Overview

Sales Coach is a native macOS application built with SwiftUI that provides real-time transcription and AI-powered coaching during sales calls.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         SwiftUI Layer                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │  MainView    │  │TranscriptView│  │  CoachingPanelView       │  │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         AppState                                     │
│              (ObservableObject - @MainActor)                         │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       CallSession (Actor)                            │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────────┐    │
│  │AudioCaptureService│  │WhisperTranscriber│  │   CoachEngine   │    │
│  └────────────────┘  └────────────────┘  └────────────────────┘    │
│                              │                        │             │
│                              ▼                        ▼             │
│                      ┌─────────────┐          ┌─────────────┐       │
│                      │TickScheduler│          │  LLMClient  │       │
│                      └─────────────┘          └─────────────┘       │
└─────────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
        ┌──────────┐   ┌──────────┐    ┌──────────┐
        │whisper.cpp│   │LM Studio │    │ Cloud API│
        │  (CLI)   │   │ (local)  │    │ (remote) │
        └──────────┘   └──────────┘    └──────────┘
```

## Core Components

### 1. AppState

The central state container for the application. Implements `@MainActor` to ensure UI-safe updates.

**Responsibilities:**
- Holds current session, transcript buffer, and coaching state
- Manages recording lifecycle
- Persists settings
- Broadcasts state changes to views

**Key Properties:**
- `currentSession: CallSession?`
- `transcriptBuffer: TranscriptBuffer`
- `coachingState: CoachingState`
- `settings: AppSettings`

### 2. CallSession

Actor that orchestrates a single call session. Coordinates between audio capture, transcription, and coaching.

**Owned Components:**
- `AudioCaptureService` - Captures microphone audio
- `WhisperTranscriber` - Converts audio to text
- `CoachEngine` - Analyzes transcript and generates insights
- `TickScheduler` - Triggers periodic coaching analysis

**Lifecycle:**
1. `start()` - Initialize and start all components
2. `pause()` - Suspend audio capture and coaching
3. `resume()` - Resume from pause
4. `stop()` - Clean shutdown and persist session

### 3. AudioCaptureService

Actor wrapping AVAudioEngine for microphone capture.

**Format:**
- Output: 16kHz, mono, 16-bit PCM (whisper.cpp format)
- Uses AVAudioConverter for format conversion
- Streams buffers via callback

### 4. WhisperTranscriber

Actor that interfaces with whisper.cpp CLI for transcription.

**Multilingual Support:**
- Uses `ggml-base.bin` (141MB) for multilingual transcription (English, French, and 90+ languages)
- Falls back to `ggml-base.en.bin` if multilingual model not found
- Language setting via `TranscriberConfig.language`:
  - `"auto"` (default) - Automatic language detection per chunk
  - `"en"` - Force English
  - `"fr"` - Force French
  - Other ISO 639-1 codes supported

**Processing Pipeline:**
1. Receive audio buffers from AudioCaptureService
2. Accumulate in AudioRingBuffer (2-3 seconds)
3. Export chunk as WAV file
4. Run whisper-cli process with language flag
5. Parse JSON output
6. Emit TranscriptEvent (partial/final)

**Chunking Strategy:**
- Chunk duration: 3000ms
- Overlap: 500ms (continuity between chunks)
- Cumulative timestamp tracking

### 5. CoachEngine

Actor that manages LLM-based coaching analysis.

**Per-Tick Flow:**
1. Build prompt from transcript + state
2. Call LLM (via LLMClient protocol)
3. Validate JSON response
4. Repair if invalid (retry with simplified prompt)
5. Merge updates into CoachingState

### 6. TickScheduler

Timer-based scheduler for periodic coaching analysis.

**Features:**
- Configurable interval (default: 7 seconds)
- Skip logic (no new transcript = skip)
- Prevents overlapping ticks

## Data Flow

### Transcription Flow

```
Microphone
    │
    ▼
AVAudioEngine (native format)
    │
    ▼
Format Converter (→ 16kHz mono PCM)
    │
    ▼
AudioRingBuffer (accumulate 3s)
    │
    ▼
WAV Export (temp file)
    │
    ▼
whisper-cli (subprocess)
    │
    ▼
JSON Parse → TranscriptSegment[]
    │
    ▼
TranscriptBuffer → UI Update
```

### Coaching Flow

```
TickScheduler (every N seconds)
    │
    ▼
CoachEngine.analyze()
    │
    ├─→ PromptBuilder.buildMessages()
    │       • System prompt (schema, checklist)
    │       • User prompt (transcript, state)
    │
    ▼
LLMClient.complete()
    │
    ▼
JSONSchemaValidator.validate()
    │
    ├─→ Valid: CoachingResponse
    │
    └─→ Invalid: Repair prompt → retry
    │
    ▼
CoachingState.applyUpdates()
    │
    ▼
UI Update (MEDDIC, questions, alerts)
```

## Key Protocols

### LLMClient

```swift
protocol LLMClient: Actor {
    func complete(messages: [ChatMessage], options: CompletionOptions) async throws -> String
    func testConnection() async throws -> Bool
}
```

Implementations:
- `LMStudioClient` - Local LM Studio server
- `OpenAICompatibleClient` - Cloud APIs (OpenAI, etc.)

### Transcriber

```swift
protocol Transcriber: Actor {
    func start() async throws
    func stop() async
    func feedAudio(_ buffer: AVAudioPCMBuffer) async
    var transcriptStream: AsyncStream<TranscriptEvent> { get }
}
```

### PersistenceStore

```swift
protocol PersistenceStore {
    func saveSession(_ session: SessionData) async throws
    func loadSession(id: UUID) async throws -> SessionData?
    func listSessions() async throws -> [SessionMetadata]
    func exportSession(_ session: SessionData, format: ExportFormat) async throws -> URL
}
```

## Storage

### Locations

| Data | Storage | Path |
|------|---------|------|
| Settings | UserDefaults | Standard |
| API Keys | Keychain | `com.salescoach.api` |
| Sessions | File System | `~/Library/Application Support/SalesCoach/sessions/` |
| Exports | File System | `~/Library/Application Support/SalesCoach/exports/` |

### Session Format

Sessions are stored as JSON files:
```json
{
  "id": "uuid",
  "createdAt": "2024-01-01T10:00:00Z",
  "endedAt": "2024-01-01T10:30:00Z",
  "transcript": [...],
  "coachingState": {...},
  "settings": {...}
}
```

## Threading Model

- **Main Actor**: AppState, all SwiftUI views
- **Actors**: CallSession, AudioCaptureService, WhisperTranscriber, CoachEngine, TickScheduler, LMStudioClient, OpenAICompatibleClient
- **Background**: whisper.cpp process, LLM network calls

All cross-actor communication uses `async/await`.

## Error Handling

### Categories

1. **Recoverable**: Retry with backoff (network errors, LLM failures)
2. **User-Action Required**: Show alert (permission denied, missing model)
3. **Fatal**: Log and gracefully degrade (corruption, system errors)

### Error Flow

```
Error occurs
    │
    ▼
Catch in Actor
    │
    ├─→ Recoverable: Retry (max 3x, exponential backoff)
    │
    ├─→ User-Action: Emit via onError callback
    │
    └─→ Fatal: Log, emit error, stop component
    │
    ▼
AppState.errorMessage
    │
    ▼
Alert displayed to user
```

## Future Considerations

### Diarization (Speaker ID)

Currently using placeholder labels. Future options:
- pyannote.audio integration
- Core ML speaker embedding model
- Post-processing with clustering

### Streaming LLM

Current: Request/response per tick
Future: SSE streaming for faster feedback

### C Bindings for whisper.cpp

Current: CLI subprocess
Future: Direct C API for lower latency

