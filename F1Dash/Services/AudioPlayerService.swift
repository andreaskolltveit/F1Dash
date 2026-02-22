import Foundation
import AVFoundation
import AppKit
import os

/// Handles playback of team radio audio clips and notification chimes.
@Observable
final class AudioPlayerService {
    private let logger = Logger(subsystem: "com.f1dash", category: "Audio")
    private var player: AVPlayer?
    private var chimePlayer: AVAudioPlayer?
    private var timeObserver: Any?

    var isPlaying = false
    var currentRadioId: UUID?
    var playbackProgress: Double = 0

    /// Play a team radio audio clip from URL.
    func playRadio(capture: RadioCapture, sessionPath: String) {
        guard let url = capture.audioURL(sessionPath: sessionPath) else {
            logger.error("Invalid radio URL for driver \(capture.racingNumber)")
            return
        }

        stop()
        currentRadioId = capture.id

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = 1.0

        // Observe playback progress
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self,
                  let duration = self.player?.currentItem?.duration,
                  duration.seconds.isFinite && duration.seconds > 0 else { return }
            self.playbackProgress = time.seconds / duration.seconds
        }

        // Observe when playback ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
            self?.currentRadioId = nil
            self?.playbackProgress = 0
        }

        player?.play()
        isPlaying = true
        logger.info("Playing radio: driver \(capture.racingNumber)")
    }

    /// Stop current playback.
    func stop() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
        currentRadioId = nil
        playbackProgress = 0
    }

    /// Toggle play/pause for a specific radio capture.
    func toggle(capture: RadioCapture, sessionPath: String) {
        if currentRadioId == capture.id && isPlaying {
            stop()
        } else {
            playRadio(capture: capture, sessionPath: sessionPath)
        }
    }

    /// Play notification chime for race control messages.
    func playChime(volume: Float = 0.5) {
        // Use system sound as chime
        guard let url = Bundle.main.url(forResource: "chime", withExtension: "mp3") else {
            // Fallback: play system sound
            NSSound.beep()
            return
        }

        do {
            chimePlayer = try AVAudioPlayer(contentsOf: url)
            chimePlayer?.volume = volume
            chimePlayer?.play()
        } catch {
            logger.error("Failed to play chime: \(error.localizedDescription)")
            NSSound.beep()
        }
    }
}
