import Foundation
// Native subword-nmt BPE (versions 0.1/0.2), used by legacy Argos packages.
struct BPETokenizer:Sendable {
 let ranks:[String:Int]
 let version02:Bool
 let source:String
 let target:String
 init(file:URL,source:String,target:String) throws {
  let lines=try String(contentsOf:file,encoding:.utf8).components(separatedBy:.newlines)
  version02=lines.first?.contains("0.2") ?? false
  var entries:[String:Int]=[:]
  for line in lines where !line.hasPrefix("#") {
   let parts=line.split(separator:" ")
   if parts.count>=2 { let pair=String(parts[0])+" "+String(parts[1]);if entries[pair]==nil { entries[pair]=entries.count } }
  }
  guard !entries.isEmpty else { throw AppFailure.message("BPE merge table is empty") }
  ranks=entries;self.source=source;self.target=target
 }
 func segment(_ word:String) -> [String] {
  var parts=word.unicodeScalars.map(String.init)
  guard !parts.isEmpty else { return [] }
  if version02 { parts[parts.count-1] += "</w>" } else { parts.append("</w>") }
  while parts.count>1 {
   var best:Int?;var rank=Int.max
   for i in 0..<(parts.count-1) { if let current=ranks[parts[i]+" "+parts[i+1]],current<rank { best=i;rank=current } }
   guard let best else { break }
   let left=parts[best],right=parts[best+1];var merged:[String]=[];var i=0
   while i<parts.count { if i+1<parts.count,parts[i]==left,parts[i+1]==right { merged.append(left+right);i += 2 } else { merged.append(parts[i]);i += 1 } }
   parts=merged
  }
  if parts.last=="</w>" { parts.removeLast() } else if parts.last?.hasSuffix("</w>")==true { parts[parts.count-1]=String(parts.last!.dropLast(4)) }
  return parts.enumerated().map { $0.offset<parts.count-1 ? $0.element+"@@" : $0.element }
 }
 private func replace(_ text:String,_ pattern:String,_ value:String) -> String { text.replacingOccurrences(of:pattern,with:value,options:.regularExpression) }
 func encode(_ input:String) -> [String] {
  var text=input.precomposedStringWithCanonicalMapping
  for (a,b) in [("“","\""),("”","\""),("’","'"),("‘","'"),("…","..."),("–","-"),(" "," ")] { text=text.replacingOccurrences(of:a,with:b) }
  // Preserve numeric punctuation, separate words and punctuation like Moses.
  let regex=try! NSRegularExpression(pattern:"[\\p{L}\\p{M}][\\p{L}\\p{M}\\p{N}'-]*|\\p{N}+(?:[.,]\\p{N}+)*|[^\\s]")
  let range=NSRange(text.startIndex...,in:text)
  return regex.matches(in:text,range:range).flatMap { match -> [String] in
   var word=String(text[Range(match.range,in:text)!])
   for (a,b) in [("&","&amp;"),("|","&#124;"),("<","&lt;"),(">","&gt;"),("'","&apos;"),("\"","&quot;"),("[","&#91;"),("]","&#93;")] { word=word.replacingOccurrences(of:a,with:b) }
   return segment(word)
  }
 }
 func decode(_ tokens:[String]) -> String {
  var text=tokens.joined(separator:" ").replacingOccurrences(of:"@@ ",with:"")
  for (a,b) in [("&amp;","&"),("&#124;","|"),("&lt;","<"),("&gt;",">"),("&apos;","'"),("&quot;","\""),("&#91;","["),("&#93;","]")] { text=text.replacingOccurrences(of:a,with:b) }
  text=replace(text,"\\s+([.,!?;:%)\\]，。！？、])","$1")
  text=replace(text,"([\\[(¿¡])\\s+","$1")
  text=replace(text,"\\s+'(s|re|ve|ll|m|d|t)\\b","'$1")
  return text.trimmingCharacters(in:.whitespacesAndNewlines)
 }
}
