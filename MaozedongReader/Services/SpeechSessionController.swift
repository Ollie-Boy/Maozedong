import AVFoundation
import Foundation

/// One shared speech synthesizer for the whole app so paging between articles does not cancel playback.
@MainActor
final class SpeechSessionController: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    @Published private(set) var isSpeaking = false
    /// Document whose text is currently being read (nil after `stop()` or finish).
    private(set) var speakingDocumentId: UUID?
    /// User started 朗读; while true, the **active** pager page should drive TTS (poetry + anthology).
    private(set) var followActiveDocumentForTTS = false
    /// `stopSpeaking` invokes `didCancel`; skip clearing follow when we are chaining to a new utterance.
    private var isChainingNewUtterance = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Stops audio only; does not clear `followActiveDocumentForTTS` (used when chaining to a new page).
    private func interruptSynthesisOnly() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        speakingDocumentId = nil
        IdleTimerController.setSpeechPlaybackActive(false)
    }

    /// Stops the current utterance but keeps follow mode (e.g. switched to a page whose body is still loading).
    func silencePlaybackPreservingFollow() {
        interruptSynthesisOnly()
    }

    func speak(_ text: String, sourceDocumentId: UUID?, language: String = "zh-CN", rate: Float = 0.5) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isChainingNewUtterance = true
        interruptSynthesisOnly()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = rate
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1

        followActiveDocumentForTTS = true
        isSpeaking = true
        speakingDocumentId = sourceDocumentId
        IdleTimerController.setSpeechPlaybackActive(true)
        synthesizer.speak(utterance)
        isChainingNewUtterance = false
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

    /// True while speaking or paused mid-utterance (still tied to `speakingDocumentId`).
    var isSpeechSessionActive: Bool {
        synthesizer.isSpeaking || synthesizer.isPaused
    }

    /// User tapped 停止朗读 — ends follow mode and stops audio.
    func stop() {
        followActiveDocumentForTTS = false
        interruptSynthesisOnly()
    }
}

extension SpeechSessionController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        speakingDocumentId = nil
        if !isChainingNewUtterance {
            followActiveDocumentForTTS = false
        }
        IdleTimerController.setSpeechPlaybackActive(false)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
        speakingDocumentId = nil
        if !isChainingNewUtterance {
            followActiveDocumentForTTS = false
        }
        IdleTimerController.setSpeechPlaybackActive(false)
    }
}
