import AppKit
@MainActor final class BrowserTranslation {
 struct Item:Codable { let id:Int; let text:String }
 private var browser:String?
 private var pageURL:String?
 func evaluate(_ js:String,timeout:Int? = nil) throws -> String {
  let name = browser ?? NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
  let quoted = "\"" + js.replacingOccurrences(of:"\\",with:"\\\\").replacingOccurrences(of:"\"",with:"\\\"").replacingOccurrences(of:"\n",with:"\\n") + "\""
  let script:String
  if name == "Safari" { script = "tell application \"Safari\" to do JavaScript \(quoted) in current tab of front window" }
  else if name == "Google Chrome" { script = "tell application \"Google Chrome\" to execute active tab of front window javascript \(quoted)" }
  else { throw AppFailure.message("Open a page in Safari or Google Chrome") }
  var error:NSDictionary?
  let bounded=timeout.map { "with timeout of \($0) seconds\n\(script)\nend timeout" } ?? script
  let result = NSAppleScript(source:bounded)?.executeAndReturnError(&error)
  if let error {
   let message = String(describing:error[NSAppleScript.errorMessage] ?? error)
   if name=="Safari",message.localizedCaseInsensitiveContains("JavaScript"),["Apple Events","AppleScript","allow","disabled","turned off","разреш","отключ"].contains(where:{message.localizedCaseInsensitiveContains($0)}) {
    throw AppFailure.message("Safari: open Safari → Settings… → Developer and turn on ‘Allow JavaScript from Apple Events’. If Developer is hidden, enable web developer features in Settings… → Advanced.")
   }
   if message.contains("JavaScript through AppleScript is turned off") { throw AppFailure.message("Chrome: enable View → Developer → Allow JavaScript from Apple Events in the window where you translate.") }
   throw AppFailure.message("Translation error in \(name): \(message)")
  }
  return result?.stringValue ?? ""
 }
 func checkAccess(browserName:String) throws { browser = browserName; _ = try evaluate("JSON.stringify({ready:true})",timeout:3) }
 struct Request:Decodable { let restored:Bool; let selection:Bool; let items:[Item] }
 private var token = ""
 var isBrowser:Bool { ["com.apple.Safari","com.google.Chrome"].contains(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "") }
 private func json(_ text:String) throws -> String { String(data:try JSONEncoder().encode(text),encoding:.utf8)! }
 func begin(browserName:String? = nil) throws -> Request {
  browser = browserName ?? NSWorkspace.shared.frontmostApplication?.localizedName
  pageURL = try evaluate("location.href")
  guard let url = Bundle.main.url(forResource:"browserTranslation",withExtension:"js") else { throw AppFailure.message("Browser translation module is missing") }
  _ = try evaluate(String(contentsOf:url,encoding:.utf8))
  token = UUID().uuidString
  let raw = try evaluate("window.__universalMacTranslationV2.begin(\(try json(token)))")
  guard let data = raw.data(using:.utf8) else { throw AppFailure.message("The browser did not return page text") }
  return try JSONDecoder().decode(Request.self,from:data)
 }
 func apply(id:Int,text:String) throws {
  guard try evaluate("location.href") == pageURL else { throw AppFailure.message("The page changed; translation stopped") }
  _ = try evaluate("window.__universalMacTranslationV2.apply(\(try json(token)),\(id),\(try json(text)))")
 }
 func finish() { _ = try? evaluate("window.__universalMacTranslationV2.finish(\(try json(token)))") }
 func rollback() { guard (try? evaluate("location.href")) == pageURL else { return }; _ = try? evaluate("window.__universalMacTranslationV2.rollback(\(try json(token)))") }
}
