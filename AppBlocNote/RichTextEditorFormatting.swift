import SwiftUI
import UIKit

// On étend la NOUVELLE classe
extension RichTextEditorCoordinator {
    
    func applyCustomFormatting(to text: NSMutableAttributedString) {
        let string = text.string
        let fullRange = NSRange(location: 0, length: string.utf16.count)
        
        // 1. DÉTECTION DES LIENS (URL)
        let types: NSTextCheckingResult.CheckingType = .link
        if let detector = try? NSDataDetector(types: types.rawValue) {
            let matches = detector.matches(in: string, options: [], range: fullRange)
            for match in matches {
                if let url = match.url {
                    text.addAttribute(.link, value: url, range: match.range)
                    text.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: match.range)
                    text.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
                }
            }
        }
        
        // 2. DÉTECTION DES TAGS (#exemple)
        let tagPattern = "#[a-zA-Z0-9_]+"
        if let regex = try? NSRegularExpression(pattern: tagPattern) {
            let matches = regex.matches(in: string, options: [], range: fullRange)
            for match in matches {
                if let range = Range(match.range, in: string) {
                    let word = String(string[range])
                    if let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                       let url = URL(string: "tag://\(encoded)") {
                        text.addAttribute(.link, value: url, range: match.range)
                        text.addAttribute(.foregroundColor, value: UIColor.systemIndigo, range: match.range)
                        text.addAttribute(.underlineStyle, value: 0, range: match.range)
                    }
                }
            }
        }
        
        // 3. DÉTECTION DES MAJUSCULES (Si pas déjà un lien)
        let capsPattern = "\\b[A-Z0-9]{2,}\\b"
        if let regex = try? NSRegularExpression(pattern: capsPattern) {
            let matches = regex.matches(in: string, options: [], range: fullRange)
            for match in matches {
                // On vérifie qu'on n'est pas déjà sur un lien
                if text.attribute(.link, at: match.range.location, effectiveRange: nil) == nil {
                    if let range = Range(match.range, in: string) {
                        let word = String(string[range])
                        if let url = URL(string: "search://\(word)") {
                            text.addAttribute(.link, value: url, range: match.range)
                            text.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: match.range)
                        }
                    }
                }
            }
        }
    }
}
