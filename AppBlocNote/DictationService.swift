import SwiftUI
import Combine
import AVFoundation

class DictationService: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    
    @Published var isRecording = false
    @Published var isTranscribing = false
    
    // ==========================================
    // 1. DÉMARRAGE ENREGISTREMENT
    // ==========================================
    
    func startRecording() {
        print("🎤 Demande d'enregistrement...")
        
        // --- CONFIGURATION SESSION ---
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try session.setActive(true)
        } catch {
            print("❌ Erreur configuration AudioSession : \(error)")
        }
        
        // --- DEMANDE PERMISSION (Compatible iOS 17 et versions antérieures) ---
        if #available(iOS 17.0, *) {
            // Nouvelle méthode pour iOS 17+
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                self?.gererResultatPermission(granted: granted)
            }
        } else {
            // Ancienne méthode pour les vieux iOS
            session.requestRecordPermission { [weak self] granted in
                self?.gererResultatPermission(granted: granted)
            }
        }
    }
    
    // Petite fonction pour éviter de répéter le code deux fois
    private func gererResultatPermission(granted: Bool) {
        if granted {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.setupAndRecord()
            }
        } else {
            print("❌ Permission micro refusée par l'utilisateur.")
        }
    }
    
    private func setupAndRecord() {
        let fileName = "dictation.wav"
        guard let docPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let path = docPath.appendingPathComponent(fileName)
        recordingURL = path
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        do {
            print("🎤 Initialisation du recorder...")
            let newRecorder = try AVAudioRecorder(url: path, settings: settings)
            newRecorder.prepareToRecord()
            
            if newRecorder.record() {
                self.audioRecorder = newRecorder
                print("✅ Enregistrement DÉMARRÉ avec succès.")
                
                DispatchQueue.main.async {
                    self.isRecording = true
                }
            } else {
                print("❌ Échec : record() a renvoyé false.")
            }
        } catch {
            print("❌ Crash setup micro : \(error)")
        }
    }
    
    // ==========================================
    // 2. ARRÊT & ENVOI À OPENAI (Whisper)
    // ==========================================
    
    func stopAndTranscribe(completion: @escaping (String?) -> Void) {
        print("🎤 Arrêt demandé...")
        audioRecorder?.stop()
        
        DispatchQueue.main.async { self.isRecording = false }
        
        guard let url = recordingURL else { completion(nil); return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            Thread.sleep(forTimeInterval: 0.2)
            
            DispatchQueue.main.async { self.isTranscribing = true }
            
            let boundary = "Boundary-\(UUID().uuidString)"
            var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
            request.httpMethod = "POST"
            request.addValue("Bearer \(Config.openAIKey)", forHTTPHeaderField: "Authorization")
            request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var data = Data()
            
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
            data.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
            
            if let audioData = try? Data(contentsOf: url) {
                data.append(audioData)
            } else {
                DispatchQueue.main.async {
                    self.isTranscribing = false
                    completion(nil)
                }
                return
            }
            
            data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"model\"\r\n\r\nwhisper-1\r\n".data(using: .utf8)!)
            data.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = data
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    self.isTranscribing = false
                    
                    if let error = error {
                        print("❌ Erreur Réseau : \(error.localizedDescription)")
                        completion(nil)
                        return
                    }
                    
                    guard let data = data else { completion(nil); return }
                    
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let text = json["text"] as? String {
                            print("✅ Transcription reçue : \(text)")
                            completion(text)
                        } else {
                            completion(nil)
                        }
                    }
                }
            }.resume()
        }
    }
}
