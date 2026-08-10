import Foundation
import AVFoundation
import Speech

/// Handles speech-to-text capture and text-to-speech playback for Talk Mode.
///
/// Wraps `SFSpeechRecognizer`, `AVAudioEngine`, and `AVSpeechSynthesizer`.
/// Audio amplitude is published as a normalized 0…1 level so the waveform/orb
/// visualization can react in real time. Configured for background audio so a
/// conversation continues if the user backgrounds the app.
@MainActor
@Observable
final class VoiceService: NSObject {
    enum State: Equatable {
        case idle
        case listening
        case speaking
    }

    private(set) var state: State = .idle
    private(set) var transcript: String = ""

    /// Normalized microphone amplitude (0…1) for visualization.
    private(set) var inputLevel: Float = 0

    /// Most recent authorization outcomes.
    private(set) var micAuthorized = false
    private(set) var speechAuthorized = false

    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    /// Invoked when a complete user utterance is finalized.
    var onUtterance: (@MainActor (String) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Permissions

    func requestPermissions() async {
        micAuthorized = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - Listening

    func startListening() throws {
        guard micAuthorized, speechAuthorized else { throw VoiceError.notAuthorized }
        stopSpeaking()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            // Runs on a realtime audio thread. Appending is thread-safe; the
            // amplitude calculation is nonisolated and hops back to the main
            // actor only to publish the level.
            request.append(buffer)
            self?.updateLevel(from: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        state = .listening
        transcript = ""

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            // The recognition callback may arrive off the main actor.
            let transcription = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                guard let self else { return }
                if let transcription { self.transcript = transcription }
                if isFinal {
                    let final = self.transcript
                    self.stopListening()
                    self.onUtterance?(final)
                } else if failed {
                    self.stopListening()
                }
            }
        }
    }

    func stopListening() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        request?.endAudio()
        recognitionTask?.cancel()
        request = nil
        recognitionTask = nil
        inputLevel = 0
        if state == .listening { state = .idle }
    }

    nonisolated private func updateLevel(from buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frames { sum += channel[i] * channel[i] }
        let rms = sqrt(sum / Float(max(frames, 1)))
        // Map RMS into a perceptually pleasant 0…1 range.
        let level = min(max(rms * 12, 0), 1)
        Task { @MainActor in self.inputLevel = level }
    }

    // MARK: - Speaking

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.prefersAssistiveTechnologySettings = true
        state = .speaking
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        if state == .speaking { state = .idle }
    }

    enum VoiceError: Error, Equatable {
        case notAuthorized
    }
}

extension VoiceService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if self.state == .speaking { self.state = .idle }
        }
    }
}
