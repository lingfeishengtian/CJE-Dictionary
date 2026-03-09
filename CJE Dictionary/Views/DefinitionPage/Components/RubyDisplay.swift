//
//  RubyDisplay.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 3/6/26.
//

import SwiftUI

private extension NSAttributedString.Key {
    static let ctRubyAnnotation = NSAttributedString.Key(kCTRubyAnnotationAttributeName as String)
}

private func rubyEnabledAttributedString(from attributedString: AttributedString) -> NSMutableAttributedString {
    let output = (try? NSMutableAttributedString(attributedString, including: \.uiKit)) ?? NSMutableAttributedString(string: String(attributedString.characters))

    for run in attributedString.runs {
        guard let rubyText = run[CTRubyAnnotationAttribute.self], !rubyText.isEmpty else {
            continue
        }

        let rubyAnnotation = CTRubyAnnotationCreateWithAttributes(
            .auto,
            .auto,
            .before,
            rubyText as CFString,
            [:] as CFDictionary
        )
        let range = NSRange(run.range, in: attributedString)
        output.addAttribute(.ctRubyAnnotation, value: rubyAnnotation, range: range)
    }

    return output
}

private func scaledAttributedString(
    from attributedString: AttributedString,
    traitCollection: UITraitCollection
) -> NSMutableAttributedString {
    let output = rubyEnabledAttributedString(from: attributedString)
    let fullRange = NSRange(location: 0, length: output.length)

    output.enumerateAttributes(in: fullRange) { attributes, range, _ in
        let baseFont = (attributes[.font] as? UIFont)
            ?? UIFont.preferredFont(forTextStyle: .body, compatibleWith: traitCollection)
        let scaledFont = UIFontMetrics.default.scaledFont(for: baseFont, compatibleWith: traitCollection)
        output.addAttribute(.font, value: scaledFont, range: range)
    }

    return output
}

struct RubyDisplay: UIViewRepresentable {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var attributedString: AttributedString
    var preferredMaxLayoutWidth: CGFloat = .greatestFiniteMagnitude
    var screenWidth: CGFloat
    var padding: CGFloat = 20
    var textColor: UIColor = .label

    public func makeUIView(context: UIViewRepresentableContext<RubyDisplay>) -> TextView {
        let textView = TextView()
       
        textView.isSelectable = false
        textView.isUserInteractionEnabled = false
        
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        
        textView.textContainerInset = UIEdgeInsets(top: 0, left: padding, bottom: 0, right: padding)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.adjustsFontForContentSizeCategory = true
        
        return textView
    }

    public func updateUIView(_ textView: TextView, context: UIViewRepresentableContext<RubyDisplay>) {
        _ = dynamicTypeSize
        textView.attributedText = scaledAttributedString(from: attributedString, traitCollection: textView.traitCollection)
        textView.invalidateIntrinsicContentSize()
        textView.textColor = textColor
        textView.maxLayoutWidth = screenWidth
    }
}
