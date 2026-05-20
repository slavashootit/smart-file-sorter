import Foundation
import AVFoundation
import AppKit

public class SoundManager {
    public static let shared = SoundManager()
    
    private init() {}
    
    public func playWhoosh() {
        guard UserDefaults.standard.bool(forKey: "soundEnabled") else { return }
        
        let localEngine = AVAudioEngine()
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 1)!
        
        var currentSample: Double = 0
        let duration = 0.35
        let totalSamples = Int(44100.0 * duration)
        
        let sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let ptr = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            
            for i in 0..<Int(frameCount) {
                if currentSample >= Double(totalSamples) {
                    ptr[i] = 0
                    continue
                }
                
                let progress = currentSample / Double(totalSamples)
                let frequency = 120.0 + (480.0 * progress)
                let volume = -20.0
                let amplitude = Float(pow(10.0, volume / 20.0) * sin(2.0 * Double.pi * frequency * currentSample / 44100.0))
                
                let envelope = sin(progress * Double.pi)
                ptr[i] = amplitude * Float(envelope)
                
                currentSample += 1
            }
            return noErr
        }
        
        localEngine.attach(sourceNode)
        localEngine.connect(sourceNode, to: localEngine.mainMixerNode, format: audioFormat)
        try? localEngine.start()
        
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + duration) {
            localEngine.stop()
        }
    }
    
    public func playChime() {
        guard UserDefaults.standard.bool(forKey: "soundEnabled") else { return }
        
        let localEngine = AVAudioEngine()
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 1)!
        
        var currentSample: Double = 0
        let duration = 0.5
        let totalSamples = Int(44100.0 * duration)
        
        let sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let ptr = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            
            for i in 0..<Int(frameCount) {
                if currentSample >= Double(totalSamples) {
                    ptr[i] = 0
                    continue
                }
                
                let progress = currentSample / Double(totalSamples)
                
                let val1 = sin(2.0 * Double.pi * 440.0 * currentSample / 44100.0)
                let val2 = sin(2.0 * Double.pi * 659.25 * currentSample / 44100.0)
                
                let volume = -15.0
                let amplitude = Float(pow(10.0, volume / 20.0) * (val1 + val2) * 0.5)
                
                let envelope = 1.0 - progress
                ptr[i] = amplitude * Float(envelope)
                
                currentSample += 1
            }
            return noErr
        }
        
        localEngine.attach(sourceNode)
        localEngine.connect(sourceNode, to: localEngine.mainMixerNode, format: audioFormat)
        try? localEngine.start()
        
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + duration) {
            localEngine.stop()
        }
    }
    
    public func performHapticFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }
}
