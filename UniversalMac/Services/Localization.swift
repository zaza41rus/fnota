import Foundation
func L(_ key:String) -> String {
 let language=UserDefaults.standard.string(forKey:"uiLanguage") ?? "en"
 guard let path=Bundle.main.path(forResource:language,ofType:"lproj"),let bundle=Bundle(path:path) else { return key }
 return bundle.localizedString(forKey:key,value:key,table:nil)
}
