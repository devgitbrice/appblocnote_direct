import SwiftUI
import UIKit

class RichTextEditorCoordinator: NSObject, UITextViewDelegate {
    var parent: RichTextEditor
    weak var currentTextView: UITextView?
    var lastText: String = ""
    var lastFontSize: Double = 0

    init(_ parent: RichTextEditor) {
        self.parent = parent
    }

    // --- 1. RECEPTION ET ANALYSE ---
    func updateTextContent(textView: UITextView, html: String, fontSize: Double) {

        print("\n🔵 ========== updateTextContent APPELÉ ==========")
        print("🔵 [INPUT] HTML reçu (len: \(html.count))")
        print("🔵 [INPUT] lastText (len: \(lastText.count))")
        print("🔵 [INPUT] html == lastText ? \(html == lastText)")

        // ✅ FIX : Protection anti-boucle modifiée - permet l'init des blocs vides
        if html == lastText && !html.isEmpty {
            print("🔵 [SKIP] Protection anti-boucle activée - SORTIE")
            return
        }

        // 1. NETTOYAGE - On garde les &nbsp; pour préserver les espaces!
        var cleanContent = html

        // LOG: Chercher les espaces dans le HTML brut
        let nbspCount = html.components(separatedBy: "&nbsp;").count - 1
        let spaceCount = html.filter { $0 == " " }.count
        print("🔵 [ANALYSE HTML] &nbsp; trouvés: \(nbspCount), espaces normaux: \(spaceCount)")

        // Extraction Body
        if let bodyStart = cleanContent.range(of: "<body"), let bodyEnd = cleanContent.range(of: "</body>") {
            let content = String(cleanContent[bodyStart.lowerBound..<bodyEnd.lowerBound])
            if let firstTag = content.firstIndex(of: ">") {
                cleanContent = String(content[content.index(after: firstTag)...])
            }
            print("🔵 [BODY] Extraction body réussie")
        } else {
            cleanContent = cleanContent.replacingOccurrences(of: "<!DOCTYPE html>", with: "")
            cleanContent = cleanContent.replacingOccurrences(of: "<html>", with: "")
            cleanContent = cleanContent.replacingOccurrences(of: "<body>", with: "")
            cleanContent = cleanContent.replacingOccurrences(of: "</body>", with: "")
            cleanContent = cleanContent.replacingOccurrences(of: "</html>", with: "")
            print("🔵 [BODY] Nettoyage manuel des balises")
        }

        // ✅ FIX ESPACE : On ne supprime QUE les retours à la ligne, PAS les espaces !
        cleanContent = cleanContent.trimmingCharacters(in: .newlines)

        // LOG: Après nettoyage
        let cleanNbspCount = cleanContent.components(separatedBy: "&nbsp;").count - 1
        let cleanSpaceCount = cleanContent.filter { $0 == " " }.count
        print("🔵 [CLEAN] Après nettoyage - &nbsp;: \(cleanNbspCount), espaces: \(cleanSpaceCount)")
        print("🔵 [CLEAN] cleanContent: \"\(cleanContent.prefix(200))...\"")

        // ✅ FIX : Si contenu vide, initialiser typingAttributes et sortir
        if cleanContent.isEmpty {
            print("🔵 [EMPTY] Contenu vide - initialisation")
            textView.text = ""
            textView.typingAttributes = [
                .font: UIFont.systemFont(ofSize: CGFloat(fontSize)),
                .foregroundColor: UIColor.label
            ]
            return
        }

        // 2. CSS CORRECTIF (AVEC INLINE-BLOCK)
        let cssStyle = """
        <style>
            body {
                font-family: -apple-system;
                font-size: \(fontSize)px;

                /* CONTRAINTES DE LARGEUR */
                width: 100%;
                max-width: 100%;
                overflow-x: hidden;
                box-sizing: border-box;

                word-wrap: break-word;
                overflow-wrap: break-word;
                white-space: pre-wrap; /* CRITIQUE pour les espaces */
                color: #000000;
                margin: 0; padding: 0;
            }

            p {
                display: inline-block;
                margin-right: 4px;
            }

            ul, ol { display: block !important; margin-top: 10px; margin-bottom: 10px; padding-left: 20px; }
            li { display: list-item !important; margin-bottom: 4px; }
        </style>
        """

        let fullHtml = "<!DOCTYPE html><html><head>\(cssStyle)</head><body>\(cleanContent)</body></html>"

        if let data = fullHtml.data(using: .utf8) {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]

            if let attr = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
                let mutable = NSMutableAttributedString(attributedString: attr)
                let range = NSRange(location: 0, length: mutable.length)
                mutable.addAttribute(.foregroundColor, value: UIColor.label, range: range)
                mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: CGFloat(fontSize)), range: range)

                // LOG: Vérifier le texte après parsing HTML
                let parsedText = mutable.string
                let parsedSpaces = parsedText.filter { $0 == " " }.count
                let parsedNbsp = parsedText.filter { $0 == "\u{00A0}" }.count
                print("🔵 [PARSED] Texte après parsing HTML: \"\(parsedText)\"")
                print("🔵 [PARSED] Espaces normaux: \(parsedSpaces), NBSP (\\u00A0): \(parsedNbsp)")

                // LOG: Position du curseur avant
                let cursorBefore = textView.selectedRange
                print("🔵 [CURSOR] Position avant: \(cursorBefore)")

                textView.attributedText = mutable

                // LOG: Position du curseur après
                print("🔵 [CURSOR] Position après: \(textView.selectedRange)")

                // LOG: Texte final dans textView
                print("🔵 [FINAL] textView.text: \"\(textView.text ?? "nil")\"")

                textView.typingAttributes = [
                    .font: UIFont.systemFont(ofSize: CGFloat(fontSize)),
                    .foregroundColor: UIColor.label
                ]
            } else {
                print("🔵 [ERROR] Échec parsing HTML - fallback texte brut")
                textView.text = cleanContent
            }
        }

        print("🔵 ========== FIN updateTextContent ==========\n")
    }

    func updateFontSize(textView: UITextView, fontSize: Double) {
        guard let currentAttr = textView.attributedText else { return }
        let mutable = NSMutableAttributedString(attributedString: currentAttr)
        let range = NSRange(location: 0, length: mutable.length)
        mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: CGFloat(fontSize)), range: range)
        textView.attributedText = mutable

        textView.typingAttributes = [
            .font: UIFont.systemFont(ofSize: CGFloat(fontSize)),
            .foregroundColor: UIColor.label
        ]
    }

    // --- 3. INTERCEPTION CLAVIER ---
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        print("\n🟡 ========== shouldChangeTextIn ==========")
        print("🟡 [INPUT] replacementText: \"\(text)\" (len: \(text.count))")
        print("🟡 [INPUT] range: \(range)")
        print("🟡 [INPUT] textView.text avant: \"\(textView.text ?? "nil")\"")

        if text == " " {
            print("🟡 [SPACE] *** ESPACE DÉTECTÉ ***")
        }
        if text == "\u{00A0}" {
            print("🟡 [NBSP] *** ESPACE INSÉCABLE DÉTECTÉ ***")
        }

        // Afficher les codes des caractères
        for (i, char) in text.enumerated() {
            print("🟡 [CHAR \(i)] '\(char)' = Unicode \(char.unicodeScalars.map { String($0.value, radix: 16) })")
        }

        print("🟡 [RETURN] true - autorisation de la modification")
        return true
    }

    // --- 4. VERIFICATION APRES FRAPPE ---
    func textViewDidChange(_ textView: UITextView) {
        print("\n🟢 ========== textViewDidChange ==========")

        let currentText = textView.text ?? ""
        print("🟢 [TEXT] textView.text: \"\(currentText)\"")
        print("🟢 [TEXT] Longueur: \(currentText.count)")

        // Analyser les derniers caractères
        if currentText.count > 0 {
            let lastChar = currentText.last!
            let lastCharCode = lastChar.unicodeScalars.first!.value
            print("🟢 [LAST] Dernier char: '\(lastChar)' (Unicode: \(String(lastCharCode, radix: 16)))")

            if lastChar == " " {
                print("🟢 [LAST] ✅ C'est un ESPACE NORMAL (0x20)")
            } else if lastChar == "\u{00A0}" {
                print("🟢 [LAST] ⚠️ C'est un NBSP (0xA0)")
            }
        }

        // Compter tous les types d'espaces
        let normalSpaces = currentText.filter { $0 == " " }.count
        let nbspSpaces = currentText.filter { $0 == "\u{00A0}" }.count
        print("🟢 [COUNT] Espaces normaux (0x20): \(normalSpaces)")
        print("🟢 [COUNT] NBSP (0xA0): \(nbspSpaces)")

        if let attr = textView.attributedText {
            print("🟢 [ATTR] attributedText.length: \(attr.length)")

            if let data = try? attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.html]),
               let fullHtml = String(data: data, encoding: .utf8) {

                // Analyser le HTML généré
                let htmlNbspCount = fullHtml.components(separatedBy: "&nbsp;").count - 1
                let htmlSpaceCount = fullHtml.filter { $0 == " " }.count
                print("🟢 [HTML] HTML généré (len: \(fullHtml.count))")
                print("🟢 [HTML] &nbsp; dans HTML: \(htmlNbspCount)")
                print("🟢 [HTML] Espaces normaux dans HTML: \(htmlSpaceCount)")
                print("🟢 [HTML] Extrait: \"\(fullHtml.prefix(300))...\"")

                if parent.text != fullHtml {
                    print("🟢 [SAVE] *** SAUVEGARDE - parent.text != fullHtml ***")
                    print("🟢 [SAVE] parent.text (len: \(parent.text.count)) vs fullHtml (len: \(fullHtml.count))")
                    lastText = fullHtml
                    parent.text = fullHtml
                } else {
                    print("🟢 [SKIP] Pas de sauvegarde - contenu identique")
                }
            } else {
                print("🟢 [ERROR] Échec conversion attributedText -> HTML")
            }
        }

        // Maintien visuel
        textView.font = UIFont.systemFont(ofSize: CGFloat(parent.fontSize))
        textView.textColor = UIColor.label

        // Hauteur bornée
        let fixedWidth = UIScreen.main.bounds.width - 40
        let size = textView.sizeThatFits(CGSize(width: fixedWidth, height: .infinity))
        let newHeight = size.height + 20
        if abs(parent.dynamicHeight - newHeight) > 2 {
            parent.dynamicHeight = newHeight
        }

        print("🟢 ========== FIN textViewDidChange ==========\n")
    }

    // --- AUTRES ---
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if URL.scheme == "tag" {
            let tag = URL.absoluteString.replacingOccurrences(of: "tag://", with: "").removingPercentEncoding ?? ""
            parent.onTagClick?(tag)
            return false
        }
        if URL.scheme == "search" { return false }
        UIApplication.shared.open(URL)
        return false
    }

    @objc func toggleBulletList() { currentTextView?.insertText("\n• ") }
    @objc func toggleNumberList() { currentTextView?.insertText("\n1. ") }
    @objc func dismissKeyboard() { currentTextView?.resignFirstResponder() }
}
