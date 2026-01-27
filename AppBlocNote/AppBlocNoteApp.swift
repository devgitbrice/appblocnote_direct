import SwiftUI
import Supabase // <--- L'IMPORT CRUCIAL QUI MANQUAIT

@main
struct AppBlocNoteApp: App {
    @State private var isLoggedIn = false
    @State private var isLoading = true
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isLoading {
                    ProgressView()
                } else if isLoggedIn {
                    MainSplitView()
                } else {
                    AuthView(onLoginSuccess: {
                        withAnimation {
                            isLoggedIn = true
                        }
                    })
                }
            }
            .task {
                await checkSession()
            }
        }
    }
    
    func checkSession() async {
        do {
            _ = try await SupabaseSingleton.shared.client.auth.session
            isLoggedIn = true
        } catch {
            isLoggedIn = false
        }
        isLoading = false
    }
}
