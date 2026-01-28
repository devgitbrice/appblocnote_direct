import SwiftUI
import UIKit

// CLASSE RENOMMÉE pour éviter l'erreur "Incorrect argument label"
class RichTextEditorCoordinator: NSObject, UITextViewDelegate {
    var parent: RichTextEditor
    var lastText: String = ""
    var lastFontSize: Double = 0
    var currentWidth: CGFloat = UIScreen.main.bounds.width  // 🔧 FIX: Stocker la largeur actuelle
    
    init(_ parent: RichTextEditor) {
        self.parent = parent
    }
    
    // --- GESTION DES MISES À JOUR (Venant de SwiftUI) ---
    
    func updateTextContent(textView: UITextView, html: String, fontSize: Double) {
        // Conversion HTML -> Attributed String
        if let data = html.data(using: .utf8) {
            if let attr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil
            ) {
                let mutable = NSMutableAttributedString(attributedString: attr)
                let range = NSRange(location: 0, length: mutable.length)
                
                // RESET TOTAL DU STYLE (Pour tuer le bug vertical)
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byWordWrapping
                paragraph.alignment = .natural // Important !
                
                mutable.addAttribute(.paragraphStyle, value: paragraph, range: range)
                mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: CGFloat(fontSize)), range: range)
                mutable.addAttribute(.foregroundColor, value: UIColor.label, range: range)
                
                // Application de la coloration (Tags, URL, Caps)
                applyCustomFormatting(to: mutable)
                
                textView.attributedText = mutable
            } else {
                textView.text = html
            }
        }
    }
    
    func updateFontSize(textView: UITextView, fontSize: Double) {
        let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
        let range = NSRange(location: 0, length: mutable.length)
        mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: CGFloat(fontSize)), range: range)
        textView.attributedText = mutable
    }
    
    // --- GESTION DU CLAVIER (Venant de l'utilisateur) ---
    
    func textViewDidChange(_ textView: UITextView) {
        // 🔧 FIX: S'assurer que le textContainer a la bonne largeur pendant la frappe
        if currentWidth > 0 {
            textView.textContainer.size.width = currentWidth
        }

        // Sauvegarde HTML
        if let attr = textView.attributedText {
            if let data = try? attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.html]),
               let html = String(data: data, encoding: .utf8) {

                if parent.text != html {
                    parent.text = html
                    lastText = html
                }
            }
        }

        // Force la réapplication de la police pour le confort visuel immédiat
        textView.font = UIFont.systemFont(ofSize: CGFloat(parent.fontSize))
        textView.textColor = UIColor.label

        recalculateHeight(view: textView, dynamicHeight: parent.$dynamicHeight, availableWidth: currentWidth)
    }
    
    // --- GESTION DU CLIC ---
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if URL.scheme == "tag" {
            let tag = URL.absoluteString.replacingOccurrences(of: "tag://", with: "").removingPercentEncoding ?? ""
            parent.onTagClick?(tag)
            return false
        }
        if URL.scheme == "search" {
            let term = URL.host ?? ""
            if let searchURL = Foundation.URL(string: "https://www.google.com/search?q=\(term)") {
                UIApplication.shared.open(searchURL)
            }
            return false
        }
        UIApplication.shared.open(URL)
        return false
    }
    
    @objc func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func recalculateHeight(view: UITextView, dynamicHeight: Binding<CGFloat>, availableWidth: CGFloat = 0) {
        DispatchQueue.main.async {
            // 🔧 FIX: Utiliser la largeur disponible fournie par GeometryReader
            let width: CGFloat
            if availableWidth > 0 {
                width = availableWidth
            } else if view.frame.width > 0 {
                width = view.frame.width
            } else {
                width = UIScreen.main.bounds.width
            }

            let size = view.sizeThatFits(CGSize(width: width, height: .infinity))
            let height = size.height + 20

            if abs(dynamicHeight.wrappedValue - height) > 2 {
                dynamicHeight.wrappedValue = height
            }
        }
    }
}
