import Foundation

/// Minimal streaming TTS client for Yandex SpeechKit.
///
/// Supports two APIs:
/// - **v1 REST**: Simple POST, returns audio binary. Good for short texts.
/// - **v3 REST**: POST to utteranceSynthesis, returns streamed JSON with base64 audio chunks.
///
/// Both return an `AsyncThrowingStream<Data, Error>` for incremental playback.
public final class YandexTTSClient: Sendable {

    /// Default v1 endpoint.
    public static let defaultV1BaseURL = "https://tts.api.cloud.yandex.net/speech/v1/tts:synthesize"

    /// Default v3 endpoint.
    public static let defaultV3BaseURL = "https://tts.api.cloud.yandex.net/tts/v3/utteranceSynthesis"

    private let auth: YandexTTSAuth
    private let folderId: String?
    private let session: URLSession
    private let v1BaseURL: String
    private let v3BaseURL: String
    private let timeoutInterval: TimeInterval

    /// Creates a new Yandex TTS client.
    /// - Parameters:
    ///   - auth: Authentication method (IAM token or API key).
    ///   - folderId: Yandex Cloud folder ID. Required for IAM token auth, optional for API key.
    ///   - v1BaseURL: Override for v1 endpoint (proxies, etc.).
    ///   - v3BaseURL: Override for v3 endpoint.
    ///   - timeoutInterval: Request timeout in seconds (default 30).
    ///   - session: URLSession to use (default shared).
    public init(
        auth: YandexTTSAuth,
        folderId: String? = nil,
        v1BaseURL: String? = nil,
        v3BaseURL: String? = nil,
        timeoutInterval: TimeInterval = 30,
        session: URLSession = .shared
    ) {
        self.auth = auth
        self.folderId = folderId
        self.session = session
        self.v1BaseURL = v1BaseURL ?? Self.defaultV1BaseURL
        self.v3BaseURL = v3BaseURL ?? Self.defaultV3BaseURL
        self.timeoutInterval = timeoutInterval
    }

    // MARK: - V1 API (simple REST)

    /// Synthesize speech using API v1. Returns the full audio as a single Data blob.
    ///
    /// Best for short texts. The response is a raw audio file in the requested format.
    public func synthesizeV1(
        text: String,
        voice: String = "marina",
        lang: String = "ru-RU",
        speed: Double? = nil,
        emotion: String? = nil,
        format: YandexTTSV1Format = .oggopus,
        sampleRateHertz: Int? = nil
    ) async throws -> Data {
        guard let url = URL(string: v1BaseURL) else {
            throw YandexTTSError(statusCode: 0, message: "Invalid v1 base URL: \(v1BaseURL)")
        }

        var body = "text=\(Self.formEncode(text))&lang=\(lang)&voice=\(voice)&format=\(format.rawValue)"
        if let speed { body += "&speed=\(YandexTTSSpeed.clamp(speed))" }
        if let emotion { body += "&emotion=\(emotion)" }
        if let rate = sampleRateHertz { body += "&sampleRateHertz=\(rate)" }
        if let folderId { body += "&folderId=\(folderId)" }

        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = "POST"
        request.setValue(auth.headerValue, forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw YandexTTSError(statusCode: 0, message: "Non-HTTP response")
        }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw YandexTTSError(statusCode: http.statusCode, message: msg)
        }
        return data
    }

    /// Synthesize speech using API v1, returning a stream of audio chunks.
    ///
    /// Wraps v1 in a stream for compatibility with the streaming player interface.
    /// Note: v1 returns audio all at once, so this yields a single chunk.
    public func streamSynthesizeV1(
        text: String,
        voice: String = "marina",
        lang: String = "ru-RU",
        speed: Double? = nil,
        emotion: String? = nil,
        format: YandexTTSV1Format = .oggopus,
        sampleRateHertz: Int? = nil
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let data = try await self.synthesizeV1(
                        text: text, voice: voice, lang: lang,
                        speed: speed, emotion: emotion,
                        format: format, sampleRateHertz: sampleRateHertz
                    )
                    continuation.yield(data)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - V3 API (streaming REST)

    /// Synthesize speech using API v3 (utteranceSynthesis).
    ///
    /// Returns an `AsyncThrowingStream` of audio chunks decoded from the
    /// streamed JSON response. Each chunk contains raw audio bytes.
    public func streamSynthesizeV3(
        text: String,
        voice: String = "marina",
        role: String? = nil,
        speed: Double? = nil,
        volume: Double? = nil,
        pitchShift: Double? = nil,
        containerFormat: YandexTTSContainerFormat = .oggOpus,
        loudnessNormalization: YandexTTSLoudnessNormalization? = nil
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.performV3Synthesis(
                        text: text, voice: voice, role: role,
                        speed: speed, volume: volume, pitchShift: pitchShift,
                        containerFormat: containerFormat,
                        loudnessNormalization: loudnessNormalization,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Raw-string variant for gateway config passthrough.
    public func streamSynthesize(
        text: String,
        voiceId: String?,
        role: String? = nil,
        speed: Double? = nil,
        format: String? = nil
    ) -> AsyncThrowingStream<Data, Error> {
        let voice = voiceId ?? "marina"
        let containerFormat = YandexTTSContainerFormat(rawValue: format ?? "") ?? .oggOpus
        return streamSynthesizeV3(
            text: text,
            voice: voice,
            role: role,
            speed: speed,
            containerFormat: containerFormat
        )
    }

    // MARK: - Private

    private func performV3Synthesis(
        text: String,
        voice: String,
        role: String?,
        speed: Double?,
        volume: Double?,
        pitchShift: Double?,
        containerFormat: YandexTTSContainerFormat,
        loudnessNormalization: YandexTTSLoudnessNormalization?,
        continuation: AsyncThrowingStream<Data, Error>.Continuation
    ) async throws {
        guard let url = URL(string: v3BaseURL) else {
            throw YandexTTSError(statusCode: 0, message: "Invalid v3 base URL: \(v3BaseURL)")
        }

        // Build hints array
        var hints: [[String: Any]] = [["voice": voice]]
        if let role { hints.append(["role": role]) }
        if let speed { hints.append(["speed": YandexTTSSpeed.clamp(speed)]) }
        if let volume { hints.append(["volume": volume]) }
        if let pitchShift { hints.append(["pitch_shift": pitchShift]) }

        var body: [String: Any] = [
            "text": text,
            "outputAudioSpec": [
                "containerAudio": [
                    "containerAudioType": containerFormat.rawValue
                ]
            ],
            "hints": hints,
        ]
        if let norm = loudnessNormalization {
            body["loudnessNormalizationType"] = norm.rawValue
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = "POST"
        request.setValue(auth.headerValue, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let folderId {
            request.setValue(folderId, forHTTPHeaderField: "x-folder-id")
        }
        request.httpBody = jsonData

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw YandexTTSError(statusCode: 0, message: "Non-HTTP response")
        }
        guard (200...299).contains(http.statusCode) else {
            var errorData = Data()
            for try await byte in bytes { errorData.append(byte) }
            let msg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw YandexTTSError(statusCode: http.statusCode, message: msg)
        }

        // V3 REST returns newline-delimited JSON objects, each containing
        // { "result": { "audioChunk": { "data": "<base64>" } } }
        var lineBuffer = Data()
        for try await byte in bytes {
            if byte == UInt8(ascii: "\n") {
                if !lineBuffer.isEmpty {
                    if let chunk = Self.extractAudioChunk(from: lineBuffer) {
                        continuation.yield(chunk)
                    }
                    lineBuffer.removeAll(keepingCapacity: true)
                }
            } else {
                lineBuffer.append(byte)
            }
        }
        // Process any remaining data
        if !lineBuffer.isEmpty {
            if let chunk = Self.extractAudioChunk(from: lineBuffer) {
                continuation.yield(chunk)
            }
        }
        continuation.finish()
    }

    /// Extract base64-encoded audio data from a JSON line.
    private static func extractAudioChunk(from jsonLine: Data) -> Data? {
        guard let obj = try? JSONSerialization.jsonObject(with: jsonLine) as? [String: Any] else {
            return nil
        }
        // Handle both wrapped {"result": {"audioChunk": {"data": ...}}}
        // and direct {"audioChunk": {"data": ...}} formats
        let audioChunk: [String: Any]?
        if let result = obj["result"] as? [String: Any] {
            audioChunk = result["audioChunk"] as? [String: Any]
        } else {
            audioChunk = obj["audioChunk"] as? [String: Any]
        }
        guard let base64 = audioChunk?["data"] as? String else { return nil }
        return Data(base64Encoded: base64)
    }

    /// URL-encode a string for form data.
    private static func formEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "+", with: "%2B")
            .replacingOccurrences(of: "&", with: "%26")
            .replacingOccurrences(of: "=", with: "%3D")
            ?? string
    }
}
