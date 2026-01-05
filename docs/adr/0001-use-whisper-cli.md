# ADR-0001: Use whisper.cpp CLI over C bindings

## Status

Accepted

## Date

2024-12-31

## Context

We need to integrate whisper.cpp for local speech-to-text transcription. The app must support real-time transcription with low latency on Apple Silicon Macs.

Two main integration approaches exist:

1. **C Bindings**: Compile whisper.cpp as a static library, create Objective-C/Swift bridging headers, and call the whisper API directly from Swift.

2. **CLI Process**: Bundle the whisper.cpp CLI binary (`main`), spawn it as a subprocess for each audio chunk, and parse the JSON output.

Key considerations:
- Development complexity and timeline
- Latency requirements
- Maintenance burden
- Debugging ease
- Future flexibility

## Decision

Use the CLI process approach for v1.

We will:
- Bundle the `whisper-cli` binary in the app's Resources
- Bundle the `ggml-base.en.bin` model (~140MB)
- Use Swift's `Process` class to spawn whisper-cli
- Export audio chunks as temporary WAV files
- Parse the JSON output (`-oj` flag) for transcript segments
- Implement chunked streaming with overlap for continuity

## Consequences

### Positive

- **Simpler implementation**: No C/Objective-C bridging complexity
- **Easier debugging**: Can test CLI manually with sample audio
- **Independent updates**: Can update whisper.cpp without recompiling the app
- **Clearer error handling**: Process exit codes and stderr are straightforward
- **Faster development**: Ship v1 sooner

### Negative

- **Higher latency**: Process spawn overhead (~50-100ms per chunk)
- **More disk I/O**: Temporary WAV files for each chunk
- **Less fine-grained control**: Can't access whisper's internal state
- **Larger binary**: whisper-cli includes full whisper.cpp code

### Neutral

- Audio format conversion still required (16kHz mono PCM)
- Model file bundled in either approach

## Alternatives Considered

### Option A: C Bindings via Bridging Header

Compile whisper.cpp as a static library and call directly from Swift via Objective-C bridging.

**Pros:**
- Lower latency (no process spawn)
- No disk I/O for audio
- Direct memory buffer access
- More efficient for long sessions

**Cons:**
- Complex bridging header setup
- Must handle memory management carefully
- Harder to debug C/Swift interop issues
- Tightly coupled to whisper.cpp version

**Why not chosen:** Development complexity would significantly delay v1. We can migrate to C bindings in v2 if latency becomes an issue.

### Option B: whisper.swift Wrapper

Use an existing Swift wrapper for whisper.cpp.

**Pros:**
- Swift-native API
- Abstracts C complexity

**Cons:**
- Limited maturity (early development)
- Not optimized for our use case
- Adds external dependency

**Why not chosen:** Available wrappers are not mature enough for production use.

### Option C: External Whisper Server

Run whisper as a separate local service (HTTP API).

**Pros:**
- Language-agnostic
- Could share across apps

**Cons:**
- Additional deployment complexity
- Users must manage separate process
- More points of failure

**Why not chosen:** Contradicts "single app" user experience goal.

## References

- [whisper.cpp GitHub](https://github.com/ggerganov/whisper.cpp)
- [whisper.cpp JSON output documentation](https://github.com/ggerganov/whisper.cpp#output-formats)
- [Swift Process documentation](https://developer.apple.com/documentation/foundation/process)

