import AppKit
import WebKit
@MainActor final class Test:NSObject,WKNavigationDelegate {
 let web = WKWebView()
 var continuation:CheckedContinuation<Void,Error>?
 func loaded() async throws { try await withCheckedThrowingContinuation { continuation = $0; web.navigationDelegate = self; web.loadHTMLString("<html><body><p id='a'>Hello world today.</p><p id='b'>Another sentence.</p><pre id='code'>Never translate code</pre><input id='input' value='Private input'></body></html>",baseURL:nil) } }
 func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!) { continuation?.resume(); continuation = nil }
 func js(_ code:String) async throws -> String { let value = try await web.evaluateJavaScript(code);return value as? String ?? "" }
 func require(_ condition:Bool,_ message:String) throws { if !condition { throw NSError(domain:message,code:1) } }
 func run(_ source:String) async throws {
  try await loaded(); _ = try await js(source)
  let api = "window.__universalMacTranslationV2"
  _ = try await js("(()=>{const n=document.querySelector('#a').firstChild;const r=document.createRange();r.setStart(n,6);r.setEnd(n,11);getSelection().removeAllRanges();getSelection().addRange(r);return 'ok'})()")
  let begin = try await js("\(api).begin('one')")
  try require(begin.contains("world") && !begin.contains("Another"),"selection scope")
  _ = try await js("\(api).apply('one',0,'мир');\(api).finish('one')")
  let selected = try await js("getSelection().toString()")
  try require(selected == "мир","selection follows translated text")
  let restore = try await js("\(api).begin('two')")
  try require(restore.contains("\"restored\":true"),"repeat restores selection")
  let original = try await js("document.querySelector('#a').textContent")
  try require(original == "Hello world today.","exact original")
  _ = try await js("getSelection().removeAllRanges();'ok'")
  let full = try await js("\(api).begin('three')")
  try require(full.contains("Another sentence") && !full.contains("Never translate") && !full.contains("Private input"),"whole page excludes sensitive/editable/code")
  _ = try await js("\(api).apply('three',0,'Привет');\(api).apply('three',1,'мир');\(api).finish('three')")
  // Restoring a selection from a translated page must leave other translated nodes alone.
  _ = try await js("(()=>{const n=document.querySelector('#a').firstChild;const r=document.createRange();r.selectNodeContents(n);getSelection().removeAllRanges();getSelection().addRange(r);return 'ok'})()")
  _ = try await js("\(api).begin('four')")
  let mixed = try await js("document.querySelector('#a').textContent")
  try require(mixed.contains("Hello") && mixed.contains("мир"),"selected restore after full translation")
  _ = try await js("getSelection().removeAllRanges();\(api).begin('five')")
  let allOriginal = try await js("document.querySelector('#a').textContent")
  try require(allOriginal == "Hello world today.","whole page restore after partial restore")
  _ = try await js("\(api).begin('six');\(api).apply('six',0,'Тест');\(api).rollback('six')")
  let rolledBack = try await js("document.querySelector('#a').textContent")
  try require(rolledBack == "Hello world today.","rollback")
  _ = try await js("\(api).begin('old');\(api).begin('new')")
  do { _ = try await js("\(api).apply('old',0,'stale')");throw NSError(domain:"stale session accepted",code:2) }
  catch let e as NSError where e.domain == WKError.errorDomain { }
  print("PASS: selection, repeat restore, full page, mixed restore, excluded nodes, rollback, stale session")
 }
}
@main struct BrowserSmoke {
 @MainActor static func main() async {
  _ = NSApplication.shared
  do { let test=Test();try await test.run(String(contentsOfFile:CommandLine.arguments[1],encoding:.utf8));exit(0) }
  catch { fputs("FAIL: \(error)\n",stderr);exit(1) }
 }
}
