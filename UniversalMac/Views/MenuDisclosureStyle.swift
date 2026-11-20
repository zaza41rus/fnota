import SwiftUI
// Public system controls/SF Symbols, with the full row as the disclosure target.
struct MenuDisclosureStyle:DisclosureGroupStyle {
 func makeBody(configuration:Configuration) -> some View {
  VStack(alignment:.leading,spacing:0) {
   Button { configuration.isExpanded.toggle() } label: {
    HStack(spacing:10) {
     configuration.label
     Spacer(minLength:8)
     Image(systemName:configuration.isExpanded ? "chevron.down" : "chevron.right")
      .font(.system(size:12,weight:.semibold)).foregroundStyle(.tertiary)
    }.frame(maxWidth:.infinity,minHeight:28,alignment:.leading).contentShape(Rectangle())
   }.buttonStyle(MenuRowButtonStyle()).accessibilityValue(configuration.isExpanded ? Text("Expanded") : Text("Collapsed"))
   if configuration.isExpanded {
    configuration.content.frame(maxWidth:.infinity,alignment:.leading)
    Divider()
   }
  }
 }
}
