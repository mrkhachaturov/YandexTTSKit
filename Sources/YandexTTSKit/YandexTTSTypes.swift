import Foundation

// MARK: - Voices

/// Yandex SpeechKit voices.
/// Full list: https://yandex.cloud/en/docs/speechkit/tts/voices
public enum YandexTTSVoice: String, Sendable, CaseIterable {
    // Russian voices
    case marina
    case alexander = "alexander"
    case jane
    case omazh
    case filipp
    case ermil
    case alena
    case zahar
    case dasha
    case julia
    case lera
    case masha
    case amira
    case john
    case lea
    case naomi
    case nigora

    public var displayName: String {
        rawValue.capitalized
    }
}

/// Voice roles (speaking styles / emotions).
public enum YandexTTSRole: String, Sendable, CaseIterable {
    case neutral
    case good
    case evil
    case friendly
    case strict
    case whisper
    case sad = "sad"
    case funny = "funny"
}

// MARK: - Audio Formats

/// Audio container formats for v3 API.
public enum YandexTTSContainerFormat: String, Sendable, CaseIterable {
    case wav = "WAV"
    case oggOpus = "OGG_OPUS"
    case mp3 = "MP3"

    /// MIME type for the format.
    public var mimeType: String {
        switch self {
        case .wav: return "audio/wav"
        case .oggOpus: return "audio/ogg"
        case .mp3: return "audio/mpeg"
        }
    }
}

/// Audio formats for v1 API.
public enum YandexTTSV1Format: String, Sendable, CaseIterable {
    case oggopus
    case lpcm
    case mp3
}

/// Loudness normalization type.
public enum YandexTTSLoudnessNormalization: String, Sendable {
    case maxPeak = "MAX_PEAK"
    case lufs = "LUFS"
}

// MARK: - Auth

/// Authentication method for Yandex Cloud.
public enum YandexTTSAuth: Sendable {
    /// IAM token (short-lived, obtained from service account or OAuth).
    case iamToken(String)
    /// API key (long-lived, from Yandex Cloud console).
    case apiKey(String)

    var headerValue: String {
        switch self {
        case .iamToken(let token): return "Bearer \(token)"
        case .apiKey(let key): return "Api-Key \(key)"
        }
    }
}

// MARK: - Errors

/// Errors from Yandex SpeechKit TTS API.
public struct YandexTTSError: Error, Sendable {
    public let statusCode: Int
    public let message: String
    public let grpcCode: Int?

    public init(statusCode: Int, message: String, grpcCode: Int? = nil) {
        self.statusCode = statusCode
        self.message = message
        self.grpcCode = grpcCode
    }
}

extension YandexTTSError: LocalizedError {
    public var errorDescription: String? {
        if let code = grpcCode {
            return "YandexTTS error \(statusCode) (gRPC \(code)): \(message)"
        }
        return "YandexTTS error \(statusCode): \(message)"
    }
}

// MARK: - Speed

/// Speed range for Yandex TTS: 0.1 to 3.0, default 1.0.
public enum YandexTTSSpeed {
    public static let minimum: Double = 0.1
    public static let maximum: Double = 3.0
    public static let defaultSpeed: Double = 1.0

    public static func clamp(_ value: Double) -> Double {
        min(maximum, max(minimum, value))
    }
}
