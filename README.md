# YandexTTSKit

Streaming TTS client for Yandex SpeechKit. Swift 6.0, zero dependencies, Sendable.

Supports both SpeechKit API v1 (simple REST) and v3 (streaming REST with audio chunks).

## Install

```swift
.package(url: "https://github.com/mrkhachaturov/YandexTTSKit.git", from: "0.1.0")
```

## Usage

### API v3 (streaming, recommended)

```swift
import YandexTTSKit

let client = YandexTTSClient(
    auth: .apiKey("your-yandex-api-key"),
    folderId: "your-folder-id"
)

let stream = client.streamSynthesizeV3(
    text: "Привет! Как дела?",
    voice: "marina",
    role: "friendly",
    containerFormat: .oggOpus
)

for try await chunk in stream {
    audioPlayer.enqueue(chunk)
}
```

### API v1 (simple, single response)

```swift
let audioData = try await client.synthesizeV1(
    text: "Привет мир!",
    voice: "marina",
    lang: "ru-RU",
    format: .oggopus
)
```

### Gateway config passthrough

```swift
// For integration with systems that use voiceId/modelId strings
let stream = client.streamSynthesize(
    text: "Some text",
    voiceId: configuredVoice,
    role: configuredRole,
    speed: configuredSpeed
)
```

## Authentication

Yandex Cloud supports two auth methods:

```swift
// API key (long-lived, from Yandex Cloud console)
let auth = YandexTTSAuth.apiKey("AQVN...")

// IAM token (short-lived, from service account or OAuth)
let auth = YandexTTSAuth.iamToken("t1.9euel...")
```

When using IAM tokens, `folderId` is required. With API keys, it's optional.

## Voices

| Voice | Language | Roles |
|-------|----------|-------|
| marina | ru-RU | neutral, friendly |
| alexander | ru-RU | neutral, good |
| jane | ru-RU | neutral, good, evil |
| alena | ru-RU | neutral, good |
| filipp | ru-RU | neutral |
| dasha | ru-RU | neutral, friendly |
| julia | ru-RU | neutral, strict |
| lera | ru-RU | neutral, friendly |
| masha | ru-RU | neutral, friendly, good |
| john | en-US | neutral, good |
| naomi | he-IL | neutral |
| amira | kk-KK | neutral |
| nigora | uz-UZ | neutral |
| lea | de-DE | neutral |

## Audio Formats

### V3 API (container formats)
- `WAV` — 16-bit PCM with WAV header
- `OGG_OPUS` — Opus codec in OGG container
- `MP3` — MPEG Layer III

### V1 API
- `oggopus` — OGG/Opus
- `lpcm` — Raw PCM (requires `sampleRateHertz`)
- `mp3` — MP3

## Parameters

| Parameter | Range | Default | API |
|-----------|-------|---------|-----|
| speed | 0.1 - 3.0 | 1.0 | v1, v3 |
| volume | (0,1] (MAX_PEAK) or [-145,0) (LUFS) | 0.7 / -19 | v3 |
| pitchShift | -1000 to 1000 Hz | 0 | v3 |
| emotion | neutral, good, evil, etc. | neutral | v1 |
| role | neutral, friendly, strict, etc. | - | v3 |

## License

MIT
