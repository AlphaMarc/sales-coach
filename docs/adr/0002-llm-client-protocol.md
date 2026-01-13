# ADR-0002: LLMClient Protocol Design

## Status

Accepted

## Date

2024-12-31

## Context

The app needs to support multiple LLM backends:
1. **Local**: LM Studio running on the user's machine
2. **Cloud**: OpenAI-compatible APIs (OpenAI, Azure, Anthropic via proxy)

Users should be able to switch between modes without affecting the rest of the application. The coaching engine should not know or care which backend is being used.

Key requirements:
- Swappable backends at runtime
- Thread-safe (used from multiple contexts)
- Consistent error handling
- Support for both streaming and non-streaming responses

## Decision

Define `LLMClient` as an Actor protocol with a minimal interface.

```swift
protocol LLMClient: Actor {
    func complete(messages: [ChatMessage], options: CompletionOptions) async throws -> String
    func testConnection() async throws -> Bool
}
```

Key design choices:
- **Actor protocol**: Ensures thread safety for network operations
- **Async/await**: Native Swift concurrency
- **Non-streaming for v1**: Simpler implementation, streaming can be added later
- **Options struct**: Encapsulates temperature, max tokens, JSON mode

Implementations:
- `LMStudioClient`: Connects to local LM Studio server
- `OpenAICompatibleClient`: Connects to cloud APIs with API key auth

## Consequences

### Positive

- **Clean abstraction**: CoachEngine doesn't know about HTTP details
- **Easy testing**: Can create mock implementations for tests
- **Thread safety**: Actor isolation prevents data races
- **Future flexibility**: Can add new backends (Anthropic, Ollama, etc.)

### Negative

- **No streaming**: Initial implementation blocks until complete response
- **Actor overhead**: Small performance cost for isolation
- **Protocol limitations**: Can't use associated types easily

### Neutral

- Both implementations share OpenAI-compatible wire format
- Error types are shared across implementations

## Alternatives Considered

### Option A: Class with Delegation

Use a class with delegate pattern for callbacks.

**Pros:**
- Familiar pattern
- Easy streaming support

**Cons:**
- More complex callback management
- Harder to reason about concurrency
- Not Swift-native concurrency

**Why not chosen:** Async/await is cleaner and more maintainable.

### Option B: Generic LLMService

Use generics to parameterize the client type.

**Pros:**
- Compile-time type safety
- No protocol overhead

**Cons:**
- Harder to swap at runtime
- Generic constraints propagate through codebase

**Why not chosen:** Runtime swapping is a core requirement.

### Option C: Enum-Based Dispatch

Use an enum for backends and switch internally.

**Pros:**
- Single concrete type
- Exhaustive switching

**Cons:**
- Adding backends requires modifying existing code
- Violates open/closed principle
- Testing requires real backends

**Why not chosen:** Protocol approach is more extensible.

## References

- [Swift Actors](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Actors)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
- [LM Studio API](https://lmstudio.ai/docs/local-server)




