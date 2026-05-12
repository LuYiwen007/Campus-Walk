import AVFoundation
import Foundation

/// 将顶栏导航文案转为语音（去重、限频），与高德步骤指引对齐。
final class NavigationSpeechController {
    static let shared = NavigationSpeechController()

    private let synthesizer = AVSpeechSynthesizer()
    private var lastSpokenNormalized: String?
    private var lastSpeakTime: Date = .distantPast
    private let minInterval: TimeInterval = 2.5

    private init() {}

    func speakGuidance(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { return }
        let norm = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let now = Date()
        if norm == lastSpokenNormalized, now.timeIntervalSince(lastSpeakTime) < minInterval * 3 {
            return
        }
        if now.timeIntervalSince(lastSpeakTime) < minInterval {
            return
        }
        lastSpokenNormalized = norm
        lastSpeakTime = now

        let u = AVSpeechUtterance(string: text)
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        u.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        synthesizer.speak(u)
    }

    func speakImmediate(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        lastSpokenNormalized = t
        lastSpeakTime = Date()
        let u = AVSpeechUtterance(string: t)
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        u.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        synthesizer.speak(u)
    }
}
