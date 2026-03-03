//
//  Flow.swift
//  CJE Dictionary
//
//  Created to replace missing Flow framework
//

import SwiftUI

// MARK: - Simple HFlow Layout Implementation (minimal working version)
struct HFlow<Content: View>: View {
    let spacing: CGFloat?
    let content: Content
    
    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        // Use a VStack with horizontal alignment to simulate flow layout
        // This is a simple implementation that should work with the existing code
        HStack(spacing: spacing) {
            content
        }
    }
}

// Simple Flow view that just wraps content (for compatibility)
struct Flow<Content: View>: View {
    let spacing: CGFloat?
    let content: Content
    
    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        // Simple placeholder - in a real implementation this would use HFlow
        // For now, we'll just return the content directly to avoid compilation issues
        content
    }
}