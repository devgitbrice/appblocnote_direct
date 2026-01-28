import SwiftUI
import UIKit

class RichTextEditorCoordinator: NSObject, UITextViewDelegate {
    var parent: RichTextEditor
    var lastText: String = ""
    var lastFontSize: Double = 0

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

                // Style de paragraphe standard
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byWordWrapping
                paragraph.alignment = .natural

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

        // Recalcul de la hauteur
        let width = textView.bounds.width > 0 ? textView.bounds.width : UIScreen.main.bounds.width
        let size = textView.sizeThatFits(CGSize(width: width, height: .infinity))
        let newHeight = size.height + 20
        if abs(parent.dynamicHeight - newHeight) > 2 {
            parent.dynamicHeight = newHeight
        }
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
}
