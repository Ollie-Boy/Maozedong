import AVFoundation
import Foundation

/// One shared speech synthesizer for the whole app so paging between articles does not cancel playback.
@MainActor
final class SpeechSessionController: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    @Published private(set) var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: String = "zh-CN", rate: Float = 0.5) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        stop()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = rate
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1

        isSpeaking = true
        IdleTimerController.setSpeechPlaybackActive(true)
        synthesizer.speak(utterance)
    }

    func pause() {
        _ = synthesizer.pauseSpeaking(at: .immediate)
        isSpeaking = false
        IdleTimerController.setSpeechPlaybackActive(false)
    }

    func resume() {
        _ = synthesizer.continueSpeaking()
        isSpeaking = true
        IdleTimerController.setSpeechPlaybackActive(true)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        IdleTimerController.setSpeechPlaybackActive(false)
    }
}

extension SpeechSessionController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        IdleTimerController.setSpeechPlaybackActive(false)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
        IdleTimerController.setSpeechPlaybackActive(false)
    }
}
