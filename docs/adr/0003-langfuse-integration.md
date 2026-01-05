# ADR-0003: Langfuse Integration for LLM Observability

## Status

Accepted

## Date

2026-01-05

## Context

The Sales Coach app makes LLM calls for real-time coaching analysis. To improve debugging, optimize prompts, and monitor production usage, we need observability into:

1. **Execution traces**: Track each LLM call with input, output, latency, and token usage
2. **Sessions**: Group traces by coaching session for analysis
3. **Prompt management**: Version and A/B test prompts without code changes

Langfuse was chosen as the observability platform because:
- Open-source with self-hosting option
- Purpose-built for LLM applications
- Supports prompt management and versioning
- Has a generous free tier for cloud usage
- EU region available (GDPR compliance)

## Decision

Integrate Langfuse via a native Swift REST API client, since no official Swift SDK exists.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Sales Coach App                          │
├─────────────────────────────────────────────────────────────────┤
│  CallSession                                                     │
│      │                                                          │
│      ├── TracingLLMClient (decorator)                          │
│      │       │                                                  │
│      │       ├── LMStudioClient / OpenAICompatibleClient       │
│      │       │                                                  │
│      │       └── LangfuseService ──────────┐                   │
│      │                                      │                   │
│      └── CoachEngine                        │                   │
│              │                              │                   │
│              └── PromptBuilder ─────────────┤                   │
│                                             │                   │
└─────────────────────────────────────────────│───────────────────┘
                                              │
                                              ▼
                               ┌─────────────────────────────┐
                               │   Langfuse EU Cloud         │
                               │   cloud.langfuse.com        │
                               ├─────────────────────────────┤
                               │  POST /api/public/ingestion │
                               │  GET /api/public/v2/prompts │
                               └─────────────────────────────┘
```

### Key Components

1. **LangfuseService** (`Sources/LLM/LangfuseService.swift`)
   - Actor-based REST API client
   - Batched event ingestion with automatic flushing
   - Prompt fetching with local caching (5-minute TTL)
   - Basic Auth using publicKey:secretKey

2. **TracingLLMClient** (`Sources/LLM/TracingLLMClient.swift`)
   - Decorator pattern wrapping existing LLMClient implementations
   - Captures: messages, response, latency, estimated tokens, model name
   - Links generations to current trace/session

3. **LangfuseConfig** (`Sources/Models/AppSettings.swift`)
   - Enable/disable toggle
   - Base URL (defaults to EU cloud)
   - Keys stored securely in Keychain

4. **Prompt Management** (`Sources/LLM/PromptBuilder.swift`)
   - Async methods fetch prompts from Langfuse when enabled
   - Automatic fallback to local prompts on failure
   - Template variable substitution (e.g., `{{checklist}}`)

### Data Flow

1. User starts a recording → CallSession created with unique sessionId
2. LangfuseService sets sessionId for trace grouping
3. A `sales-coaching-session-start` trace is created with session metadata
4. Each coaching tick:
   - CoachEngine creates a `coaching-analysis-tick` trace
   - PromptBuilder fetches prompts from Langfuse (or uses local fallback)
   - TracingLLMClient wraps the LLM call and logs generation
   - Session statistics are updated (tick count, token usage)
5. Events are batched and sent to Langfuse every 5 seconds
6. On session stop:
   - A `sales-coaching-session-end` trace is created with final statistics
   - Session duration, LLM call count, total tokens are logged
   - Remaining events are flushed

### Sessions

Sessions in Langfuse group all traces from a single coaching recording together. This enables:
- **Session replay**: View all LLM interactions from a coaching session in sequence
- **Session metrics**: Aggregate statistics like total tokens, duration, and tick count
- **Session comparison**: Compare different coaching sessions for optimization

**Session Lifecycle:**
```
Recording Start
    │
    ├── setSessionId(uuid)           # Initialize session context
    ├── sales-coaching-session-start # Trace with config metadata
    │
    │   ┌─────────────────────────────────────────────────────────┐
    │   │  Coaching Loop (repeats every tick interval)           │
    │   │  ├── recordCoachingTick()                               │
    │   │  ├── coaching-analysis-tick trace                       │
    │   │  │   └── chat-completion generation                     │
    │   │  │       └── recordGeneration(tokens)                   │
    │   │  └── (optional) JSON repair generation                  │
    │   └─────────────────────────────────────────────────────────┘
    │
Recording Stop
    │
    ├── endSession()                  # Finalize with stats
    │   └── sales-coaching-session-end trace
    │       ├── session_duration_seconds
    │       ├── llm_call_count
    │       ├── coaching_tick_count
    │       ├── total_tokens
    │       └── final coaching state
    │
    └── flush()                       # Send remaining events
```

**Session Statistics Tracked:**
- `llmCallCount`: Number of LLM API calls made
- `coachingTickCount`: Number of analysis ticks completed
- `totalPromptTokens`: Estimated input tokens across all calls
- `totalCompletionTokens`: Estimated output tokens across all calls
- `sessionDuration`: Total recording time in seconds

## Consequences

### Positive

- **Full observability**: Every LLM call is tracked with detailed metadata
- **Session correlation**: All traces from a coaching session are grouped
- **Remote prompt management**: Update prompts without app releases
- **Minimal code changes**: Decorator pattern doesn't modify existing LLM clients
- **Graceful degradation**: App works normally if Langfuse is unavailable

### Negative

- **Network overhead**: Additional API calls for prompt fetching and trace ingestion
- **No native SDK**: Custom implementation requires maintenance
- **Keychain storage**: Two additional secrets to manage

### Neutral

- **Optional feature**: Langfuse can be disabled entirely
- **EU-only**: Hardcoded to EU region for GDPR compliance

## Implementation Notes

### Prompt Template Variables

When using Langfuse prompt management, prompts can include these template variables:

**System Prompt (`coaching-system-prompt`)**:
- `{{checklist}}` - Replaced with the process checklist

**User Prompt (`coaching-user-prompt`)**:
- `{{state}}` - Current coaching state JSON
- `{{window_seconds}}` - Transcript window duration
- `{{windowed_transcript}}` - Recent transcript text
- `{{delta_transcript}}` - New transcript since last analysis

### Token Estimation

Since local LLM servers don't always return token counts, we estimate:
- ~4 characters per token (English text approximation)
- This provides rough metrics for cost tracking

## References

- [Langfuse Documentation](https://langfuse.com/docs)
- [Langfuse API Reference](https://api.reference.langfuse.com)
- [ADR-0002: LLMClient Protocol Design](./0002-llm-client-protocol.md)

