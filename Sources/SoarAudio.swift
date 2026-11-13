import AVFoundation
import Foundation

/// Original procedurally synthesized arcade effects; no external audio assets.
final class SoarAudio {
    static let shared = SoarAudio()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    var muted = false

    private init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func play(_ effect: Effect) {
        guard !muted else { return }
        if !engine.isRunning { try? engine.start() }
        guard engine.isRunning else { return }
        let seconds: Double
        let frequency: Double
        switch effect {
        case .flap: seconds = 0.11; frequency = 145
        case .shoot: seconds = 0.095; frequency = 640
        case .hit: seconds = 0.23; frequency = 170
        case .destroy: seconds = 0.43; frequency = 105
        case .pickup: seconds = 0.22; frequency = 850
        case .hurt: seconds = 0.55; frequency = 210
        case .wave: seconds = 0.38; frequency = 380
        }
        let frames = AVAudioFrameCount(format.sampleRate * seconds)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?.pointee else { return }
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            let t = Double(i) / format.sampleRate
            let progress = t / seconds
            let sweep: Double
            switch effect {
            case .shoot: sweep = 1.7 - progress * 1.4
            case .pickup, .wave: sweep = 0.65 + progress * 1.25
            default: sweep = 1.2 - progress * 0.75
            }
            let p = 2 * Double.pi * frequency * t * sweep
            let grit = sin(p * 2.03) * 0.22 + sin(p * 3.97) * 0.09
            let envelope = min(1, t * 130) * pow(max(0, 1 - progress), 1.8)
            channel[i] = Float((sin(p) + grit) * envelope * 0.15)
        }
        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }
    enum Effect { case flap, shoot, hit, destroy, pickup, hurt, wave }
}
