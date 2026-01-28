import SwiftUI
import UIKit

class RichTextEditorCoordinator: NSObject, UITextViewDelegate {
    var parent: RichTextEditor
    var lastText: String = ""
    var lastFontSize: Double = 0

    init(_ parent: RichTextEditor) {
        self.parent = parent
    }

    // --- MISE À JOUR DU TEXTE (Avec Patch Visuel) ---
    func updateTextContent(textView: UITextView, html: String, fontSize: Double) {
        
        // TEST 4 : PATCH CSS "INLINE"
        // On force les balises <p> à se comporter comme des mots qui se suivent,
        // et non comme des blocs qui vont à la ligne.
        let cssStyle = """
        <style>
            body { 
                font-family: -apple-system; 
                font-size: \(fontSize)px; 
                width: 100%; 
                margin: 0; 
                padding: 0; 
            }
            p {
                display: inline; /* FORCE L'ALIGNEMENT HORIZONTAL */
                margin-right: 4px; /* Un petit espace entre les morceaux recollés */
            }
        </style>
        """
        
        let fullHtml = "<!DOCTYPE html><html><head>\(cssStyle)</head><body>\(html)</body></html>"
        
        if let data = fullHtml.data(using: .utf8) {
            if let attr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil
            ) {
                let mutable = NSMutableAttributedString(attributedString: attr)
                let range = NSRange(location: 0, length: mutable.length)
                
                // On remet les couleurs correctes
                mutable.addAttribute(.foregroundColor, value: UIColor.label, range: range)
                mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: CGFloat(fontSize)), range: range)
                
                applyCustomFormatting(to: mutable)
                
                textView.attributedText = mutable
            } else {
                textView.text = html
            }
        }
    }

    func updateFontSize(textView: UITextView, fontSize: Double) {
        guard let currentAttr = textView.attributedText else { return }
        let mutable = NSMutableAttributedString(attributedString: currentAttr)
        let range = NSRange(location: 0, length: mutable.length)
        mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: CGFloat(fontSize)), range: range)
        textView.attributedText = mutable
    }

    // --- SAUVEGARDE ---
    func textViewDidChange(_ textView: UITextView) {
        if let attr = textView.attributedText {
            if let data = try? attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.html]),
               let fullHtml = String(data: data, encoding: .utf8) {
                
                if parent.text != fullHtml {
                    parent.text = fullHtml
                    lastText = fullHtml
                }
            }
        }
        
        textView.font = UIFont.systemFont(ofSize: CGFloat(parent.fontSize))
        textView.textColor = UIColor.label
        
        let width = textView.bounds.width > 0 ? textView.bounds.width : UIScreen.main.bounds.width
        let size = textView.sizeThatFits(CGSize(width: width, height: .infinity))
        let newHeight = size.height + 20
        if abs(parent.dynamicHeight - newHeight) > 2 {
            parent.dynamicHeight = newHeight
        }
    }
    
    // --- GESTION DES CLICS ---
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if URL.scheme == "tag" {
            let tag = URL.absoluteString.replacingOccurrences(of: "tag://", with: "").removingPercentEncoding ?? ""
            parent.onTagClick?(tag)
            return false
        }
        if URL.scheme == "search" {
             return false
         }
        UIApplication.shared.open(URL)
        return false
    }

    @objc func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
