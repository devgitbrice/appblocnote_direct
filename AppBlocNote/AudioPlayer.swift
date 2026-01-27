import Foundation
import AVFoundation

class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    var player: AVAudioPlayer?
    var onFinish: (() -> Void)?
    
    func play(data: Data, onFinish: @escaping () -> Void) {
        // 1. On stocke l'action à faire à la fin (passer à la note suivante ou arrêter)
        self.onFinish = onFinish
        
        do {
            // --- SPÉCIFIQUE IOS : GESTION DU MODE SILENCIEUX ---
            // On configure la session pour que le son sorte même si l'iPhone est en silencieux
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            // ---------------------------------------------------
            
            // 2. Création du lecteur avec les données audio (MP3/WAV reçus d'OpenAI)
            player = try AVAudioPlayer(data: data)
            player?.delegate = self // Important pour détecter la fin
            player?.prepareToPlay()
            
            // 3. Lancement
            let success = player?.play() ?? false
            
            if !success {
                print("⚠️ AudioPlayer: Impossible de lancer la lecture.")
                onFinish()
            }
        } catch {
            print("❌ AudioPlayer Erreur: \(error)")
            onFinish()
        }
    }
    
    func stop() {
        player?.stop()
        player = nil
        
        // On libère la session audio pour ne pas bloquer d'autres apps (Music, Spotify...)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    // --- DÉLÉGUÉS (Appelés automatiquement par iOS) ---
    
    // Quand la lecture est finie naturellement
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("✅ AudioPlayer: Fin de lecture.")
        // Toujours mettre à jour l'interface sur le fil principal (Main Thread)
        DispatchQueue.main.async {
            self.onFinish?()
        }
    }
    
    // Si le fichier audio est corrompu
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ AudioPlayer: Erreur de décodage.")
        DispatchQueue.main.async {
            self.onFinish?()
        }
    }
}
