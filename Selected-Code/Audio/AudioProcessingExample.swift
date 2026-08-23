import AVFoundation
import Combine
import QuartzCore

/// Simplified public example derived from the production audio pipeline
/// used by True Lock Tuner.
///
/// Demonstrates:
/// - microphone permission handling
/// - AVAudioEngine configuration
/// - PCM buffer processing
/// - RMS noise gating
/// - rolling median filtering
/// - note-change stabilization
/// - main-thread UI publication
///
/// The production pitch-detection and chord-recognition algorithms are
/// intentionally omitted from this public engineering sample.
final class AudioProcessingExample: NSObject, ObservableObject {

    // MARK: - Published State

    @Published private(set) var displayedNote: String = "—"
    @Published private(set) var frequency: Double?
    @Published private(set) var centsOff: Double = 0
    @Published private(set) var isListening = false

    // MARK: - Audio

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    /// Injected pitch detector.
    /// The production implementation is intentionally private.
    private let pitchDetector: PitchDetecting

    // MARK: - Stabilization

    private var frequencyHistory: [Double] = []
    private let frequencyHistoryLimit = 5

    private var candidateNote: String?
    private var candidateCount = 0
    private let observationsRequiredForNoteChange = 2

    private var lastSuccessfulDetectionTime: CFTimeInterval = 0
    private let idleResetInterval: CFTimeInterval = 2.0

    /// Illustrative threshold for rejecting very quiet input.
    private let noiseGateRMS: Float = 0.003

    // MARK: - Initialization

    init(pitchDetector: PitchDetecting) {
        self.pitchDetector = pitchDetector
        super.init()
    }

    // MARK: - Public Control

    func startListening() {
        requestMicrophonePermission { [weak self] granted in
            guard let self else { return }

            DispatchQueue.main.async {
                if granted {
                    self.setupAudioEngine()
                } else {
                    self.isListening = false
                }
            }
        }
    }

    func stopListening() {
        audioEngine?.stop()

        if let inputNode {
            inputNode.removeTap(onBus: 0)
        }

        audioEngine = nil
        inputNode = nil

        resetDetectionState(updateUI: false)

        DispatchQueue.main.async { [weak self] in
            self?.isListening = false
        }
    }

    // MARK: - Microphone Permission

    private func requestMicrophonePermission(
        completion: @escaping (Bool) -> Void
    ) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                completion(granted)
            }
        } else {
            AVAudioSession.sharedInstance()
                .requestRecordPermission { granted in
                    completion(granted)
                }
        }
    }

    // MARK: - Audio Engine

    private func setupAudioEngine() {
        do {
            let session = AVAudioSession.sharedInstance()

            try session.setCategory(
                .record,
                mode: .measurement,
                options: []
            )

            try session.setActive(true)

            let engine = AVAudioEngine()
            let input = engine.inputNode
            let hardwareFormat = input.outputFormat(forBus: 0)

            let processingFormat: AVAudioFormat

            if hardwareFormat.channelCount > 1 {
                guard let monoFormat = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: hardwareFormat.sampleRate,
                    channels: 1,
                    interleaved: false
                ) else {
                    return
                }

                processingFormat = monoFormat
            } else {
                processingFormat = hardwareFormat
            }

            let bufferSize: AVAudioFrameCount = 4096

            input.installTap(
                onBus: 0,
                bufferSize: bufferSize,
                format: processingFormat
            ) { [weak self] buffer, _ in

                self?.processBuffer(
                    buffer,
                    sampleRate: processingFormat.sampleRate
                )
            }

            engine.prepare()
            try engine.start()

            audioEngine = engine
            inputNode = input

            DispatchQueue.main.async { [weak self] in
                self?.isListening = true
            }

        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.isListening = false
            }
        }
    }

    // MARK: - Buffer Processing

    private func processBuffer(
        _ buffer: AVAudioPCMBuffer,
        sampleRate: Double
    ) {
        guard
            let channelData = buffer.floatChannelData
        else {
            return
        }

        let frameLength = Int(buffer.frameLength)

        guard frameLength > 0 else {
            return
        }

        let samples = Array(
            UnsafeBufferPointer(
                start: channelData.pointee,
                count: frameLength
            )
        )

        let rms = rootMeanSquare(samples)

        checkIdleTimeout()

        guard rms >= noiseGateRMS else {
            return
        }

        // Production implementation performs the actual frequency analysis.
        guard let detectedFrequency = pitchDetector.detectFrequency(
            samples: samples,
            sampleRate: sampleRate
        ) else {
            return
        }

        lastSuccessfulDetectionTime = CACurrentMediaTime()

        let stableFrequency = medianFilteredFrequency(detectedFrequency)

        let result = pitchDetector.note(
            for: stableFrequency
        )

        stabilize(
            note: result.note,
            frequency: stableFrequency,
            centsOff: result.centsOff
        )
    }

    // MARK: - RMS / Noise Gate

    private func rootMeanSquare(
        _ samples: [Float]
    ) -> Float {

        guard !samples.isEmpty else {
            return 0
        }

        let sumSquares = samples.reduce(Float.zero) {
            $0 + ($1 * $1)
        }

        return sqrt(
            sumSquares / Float(samples.count)
        )
    }

    // MARK: - Median Filtering

    private func medianFilteredFrequency(
        _ newFrequency: Double
    ) -> Double {

        frequencyHistory.append(newFrequency)

        if frequencyHistory.count > frequencyHistoryLimit {
            frequencyHistory.removeFirst()
        }

        let sorted = frequencyHistory.sorted()
        let middle = sorted.count / 2

        if sorted.count.isMultiple(of: 2) {
            return (
                sorted[middle - 1] +
                sorted[middle]
            ) / 2
        }

        return sorted[middle]
    }

    // MARK: - Display Stabilization

    private func stabilize(
        note: String,
        frequency: Double,
        centsOff: Double
    ) {
        if note == displayedNote {
            candidateNote = nil
            candidateCount = 0

            publish(
                note: note,
                frequency: frequency,
                centsOff: centsOff
            )

            return
        }

        if note == candidateNote {
            candidateCount += 1
        } else {
            candidateNote = note
            candidateCount = 1
        }

        guard candidateCount >= observationsRequiredForNoteChange else {
            return
        }

        candidateNote = nil
        candidateCount = 0

        publish(
            note: note,
            frequency: frequency,
            centsOff: centsOff
        )
    }

    // MARK: - Idle Handling

    private func checkIdleTimeout() {
        guard
            displayedNote != "—",
            lastSuccessfulDetectionTime > 0
        else {
            return
        }

        guard
            CACurrentMediaTime() - lastSuccessfulDetectionTime
                > idleResetInterval
        else {
            return
        }

        resetDetectionState(updateUI: true)
    }

    private func resetDetectionState(
        updateUI: Bool
    ) {
        frequencyHistory.removeAll()

        candidateNote = nil
        candidateCount = 0

        lastSuccessfulDetectionTime = 0

        guard updateUI else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.displayedNote = "—"
            self?.frequency = nil
            self?.centsOff = 0
        }
    }

    // MARK: - UI Publication

    private func publish(
        note: String,
        frequency: Double,
        centsOff: Double
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.displayedNote = note
            self?.frequency = frequency
            self?.centsOff = centsOff
        }
    }
}


// MARK: - Public Showcase Abstractions

/// Represents the boundary between microphone processing and the
/// proprietary pitch-detection implementation.
protocol PitchDetecting {

    func detectFrequency(
        samples: [Float],
        sampleRate: Double
    ) -> Double?

    func note(
        for frequency: Double
    ) -> PitchResult
}

struct PitchResult {
    let note: String
    let centsOff: Double
}
