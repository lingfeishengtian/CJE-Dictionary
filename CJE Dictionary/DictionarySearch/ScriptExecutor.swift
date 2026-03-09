//
//  ScriptExecutor.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 3/6/26.
//

import Foundation
import WebKit

enum ScriptExecutorError: LocalizedError {
	case invalidScriptResult

	var errorDescription: String? {
		switch self {
		case .invalidScriptResult:
			return "Script.js returned an invalid result payload."
		}
	}
}

@MainActor
final class ScriptExecutor: NSObject, WKNavigationDelegate {
	private var continuation: CheckedContinuation<[DefinitionGroup], Error>?
	private var script = ""
	private lazy var webView: WKWebView = {
		let view = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
		view.navigationDelegate = self
		return view
	}()

	static func execute(html: String, script: String) async throws -> [DefinitionGroup] {
		let executor = ScriptExecutor()
		return try await executor.evaluate(html: html, script: script)
	}

	private func evaluate(html: String, script: String) async throws -> [DefinitionGroup] {
		self.script = script
		return try await withCheckedThrowingContinuation { continuation in
			self.continuation = continuation
			self.webView.loadHTMLString(html, baseURL: nil)
		}
	}

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		webView.evaluateJavaScript(script) { result, error in
			if let error {
				self.finish(with: .failure(error))
				return
			}

			guard let payload = result as? String else {
				self.finish(with: .failure(ScriptExecutorError.invalidScriptResult))
				return
			}

			if let data = payload.data(using: .utf16),
			   let decoded = try? JSONDecoder().decode([DefinitionGroup].self, from: data) {
				self.finish(with: .success(decoded))
				return
			}

			if let data = payload.data(using: .utf8),
			   let decoded = try? JSONDecoder().decode([DefinitionGroup].self, from: data) {
				self.finish(with: .success(decoded))
				return
			}

			self.finish(with: .failure(ScriptExecutorError.invalidScriptResult))
		}
	}

	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		finish(with: .failure(error))
	}

	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		finish(with: .failure(error))
	}

	private func finish(with result: Result<[DefinitionGroup], Error>) {
		guard let continuation else {
			return
		}
		self.continuation = nil
		continuation.resume(with: result)
	}
}
