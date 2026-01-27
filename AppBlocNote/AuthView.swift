import SwiftUI
import Supabase

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Callback pour dire à l'app "C'est bon, on est connecté"
    var onLoginSuccess: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Bienvenue")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.emailAddress)
                .autocapitalization(.none)
            
            SecureField("Mot de passe", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.password)
            
            Button(action: signIn) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Se connecter")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .disabled(isLoading)
            
            Button("Créer un compte") {
                signUp()
            }
            .font(.footnote)
        }
        .padding(40)
        .frame(maxWidth: 400) // Pour que ça ne soit pas trop large sur Mac
    }
    
    func signIn() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await SupabaseSingleton.shared.client.auth.signIn(email: email, password: password)
                isLoading = false
                onLoginSuccess() // On débloque l'accès
            } catch {
                isLoading = false
                errorMessage = "Erreur : \(error.localizedDescription)"
            }
        }
    }
    
    func signUp() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await SupabaseSingleton.shared.client.auth.signUp(email: email, password: password)
                isLoading = false
                // Sur Supabase, par défaut, il faut confirmer l'email.
                errorMessage = "Compte créé ! Vérifiez vos emails pour confirmer."
            } catch {
                isLoading = false
                errorMessage = "Erreur inscription : \(error.localizedDescription)"
            }
        }
    }
}
