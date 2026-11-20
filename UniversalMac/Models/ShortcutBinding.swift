import Foundation
struct ShortcutBinding:Codable,Equatable,Sendable {
 var keyCode:UInt32
 var modifiers:UInt32
 var label:String
 var isFn:Bool { keyCode == 63 && modifiers == 0 }
 static let voice = ShortcutBinding(keyCode:63,modifiers:0,label:"Fn")
 static let translate = ShortcutBinding(keyCode:63,modifiers:0,label:"Fn ×2")
 static func load(_ key:String,default value:Self)->Self {
  guard let data = UserDefaults.standard.data(forKey:key),let binding = try? JSONDecoder().decode(Self.self,from:data) else { return value }; return binding
 }
 func save(_ key:String) { if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data,forKey:key) } }
}
