//
//  DictionaryHelperViews.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 1/7/24.
//

import SwiftUI

struct RubyDisplay: UIViewRepresentable {
    var attributedString: AttributedString
    var preferredMaxLayoutWidth: CGFloat = .greatestFiniteMagnitude
    var screenWidth: CGFloat
    var padding: CGFloat = 20

    public func makeUIView(context: UIViewRepresentableContext<RubyDisplay>) -> TextView {
        let textView = TextView()
       
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true
        
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        
        textView.textContainerInset = UIEdgeInsets(top: 0, left: padding, bottom: 0, right: padding)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.isScrollEnabled = false
        textView.isEditable = false
        
        return textView
    }

    public func updateUIView(_ textView: TextView, context: UIViewRepresentableContext<RubyDisplay>) {
        let p =  try! NSMutableAttributedString(attributedString, including: \.coreText)
        let pF = try! NSMutableAttributedString(attributedString, including: \.uiKit)
        pF.enumerateAttributes(in: NSMakeRange(0, p.length), using: { attributes, range, _ in
            p.addAttributes(attributes, range: range)
        })
        
        textView.attributedText = p
        textView.invalidateIntrinsicContentSize()
        textView.textColor = .label
        textView.maxLayoutWidth = screenWidth
    }
}

final class TextView: UITextView {
    var maxLayoutWidth: CGFloat = 0 {
        didSet {
            guard maxLayoutWidth != oldValue else { return }
            invalidateIntrinsicContentSize()
        }
    }
    
    override var intrinsicContentSize: CGSize {
        guard maxLayoutWidth > 0 else {
            return super.intrinsicContentSize
        }

        return sizeThatFits(
            CGSize(width: maxLayoutWidth, height: .greatestFiniteMagnitude)
        )
    }
}
