import Foundation
import Supabase

// On crée une classe Singleton pour accéder à Supabase de partout
class SupabaseSingleton {
    static let shared = SupabaseSingleton()
    
    let client: SupabaseClient
    
    private init() {
        // Remplace par tes vraies clés (celles que tu avais dans Config.swift)
        let supabaseUrl = URL(string: "https://lomgelwpxlzynuogxsri.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxvbWdlbHdweGx6eW51b2d4c3JpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYyMTQ2MDgsImV4cCI6MjA4MTc5MDYwOH0.aUty5KjHdr0dJVH1ubEKqYz9D1M4u1w1LYhys7dr0Cg"
        
        self.client = SupabaseClient(supabaseURL: supabaseUrl, supabaseKey: supabaseKey)
    }
}
