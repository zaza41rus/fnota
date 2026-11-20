import SwiftUI
import AppKit
struct SpeechSettingsView:View {
 @Bindable var state:AppState
 private var busy:Bool { state.models.downloading || state.recording || state.startingRecording || state.processing }
 var body:some View {
  Form {
   Section {
    ForEach(SpeechModel.catalog) { model in
     HStack(alignment:.top,spacing:12) {
      Image(systemName:state.models.installed(model) ? "cpu" : "shippingbox").font(.title2).frame(width:24).padding(.top,3)
      VStack(alignment:.leading,spacing:4) {
       Text(model.title).font(.headline)
       Text(L(model.language)).font(.callout).foregroundStyle(.secondary)
       Text("\(model.size) · CPU · \(model.license)").font(.caption).foregroundStyle(.secondary)
       Text(L(model.purpose)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
       HStack(spacing:12) {
        Link("Learn more…",destination:model.sourceURL)
        if state.models.installed(model) {
         Button("Delete…",role:.destructive) { state.models.remove(model) }.buttonStyle(.plain).foregroundStyle(.red).disabled(busy)
        }
       }.font(.callout)
      }.frame(maxWidth:.infinity,alignment:.leading)
      Group {
       if state.models.installed(model) {
        if state.models.selectedID==model.id { Label("Active",systemImage:"record.circle.fill").foregroundStyle(Color.accentColor) }
        else { Button("Use model") { state.models.select(model) }.disabled(busy) }
       } else { Button("Download and use") { state.models.install(model) }.disabled(busy) }
      }.controlSize(.small).fixedSize()
     }.padding(.vertical,6)
    }
   } header: {
    VStack(alignment:.leading,spacing:4) {
     Text("Speech recognition").font(.headline)
     Text("Choose a model to enable dictation. Delete models you no longer need to free space.").font(.callout).foregroundStyle(.secondary)
    }
   }
   if state.models.downloading {
    Section {
     ProgressView(value:state.models.progress)
     Button("Cancel download") { state.models.task?.cancel() }
    }
   }
   if !state.models.status.isEmpty { Section { Text(L(state.models.status)).font(.callout).foregroundStyle(.secondary).textSelection(.enabled) } }
   Section {
    HStack {
     Button("Verify active model") { state.models.verify() }.disabled(busy || !state.models.installed)
     Spacer()
     Button("Show models in Finder") { try? FileManager.default.createDirectory(at:state.models.root,withIntermediateDirectories:true);NSWorkspace.shared.open(state.models.root) }
    }
   }
  }.formStyle(.grouped)
 }
}
