import SwiftUI
struct TranslationSettingsView:View {
 @Bindable var state:AppState
 private var busy:Bool { state.translationModels.busy || state.recording || state.startingRecording || state.processing }
 private var planIsActive:Bool {
  let folders=state.translationModels.plan.compactMap { state.translationModels.installed($0)?.folder }
  return !folders.isEmpty && folders.count==state.translationModels.plan.count && folders==state.translationFolders
 }
 var body:some View {
  Form {
   Section {
    HStack(spacing:16) {
     Picker("From",selection:$state.translationModels.sourceLanguage) {
      ForEach(languages,id:\.self) { Text(TranslationCatalogItem.language($0)).tag($0) }
     }.labelsHidden().accessibilityLabel("From")
     Button {
      let from=state.translationModels.sourceLanguage
      state.translationModels.sourceLanguage=state.translationModels.targetLanguage;state.translationModels.targetLanguage=from
     } label: { Image(systemName:"arrow.left.arrow.right") }.buttonStyle(.borderless).help("Swap languages")
     Picker("To",selection:$state.translationModels.targetLanguage) {
      ForEach(languages,id:\.self) { Text(TranslationCatalogItem.language($0)).tag($0) }
     }.labelsHidden().accessibilityLabel("To")
    }.disabled(busy)
    ForEach(state.translationModels.installedModels,id:\.folder) { info in installedRow(info) }
    ForEach(state.translationModels.plan.filter { state.translationModels.installed($0)==nil }) { item in
     HStack(alignment:.top,spacing:12) {
      Image(systemName:"shippingbox").font(.title2).frame(width:24)
      VStack(alignment:.leading,spacing:4) {
       Text("Argos \(item.label) · \(item.package_version)").font(.headline)
       Text(state.translationModels.plan.count==2 ? "Two models via English. An intermediate translation may reduce accuracy; both models are needed." : "Direct translation. A dedicated model for this language pair.").font(.callout).foregroundStyle(.secondary)
      }.frame(maxWidth:.infinity,alignment:.leading)
      Button("Download and use") { activatePlan() }.controlSize(.small).disabled(busy)
     }.padding(.vertical,6)
    }
    if state.translationModels.allAvailable.isEmpty {
     Button("Show available translation models") { state.translationModels.refreshCatalog() }.disabled(busy)
    } else if state.translationModels.plan.isEmpty { Text("No supported route for this language pair.").foregroundStyle(.secondary) }
    else if state.translationModels.plan.allSatisfy({state.translationModels.installed($0) != nil}),!planIsActive {
     Button("Use models") { activatePlan() }.disabled(busy)
    }
   } header: {
    VStack(alignment:.leading,spacing:4) {
     Text("Text translation").font(.headline)
     Text("Choose the source and target languages. Translation runs locally after download.").font(.callout).foregroundStyle(.secondary)
    }
   }
   if state.translationModels.busy { Section { ProgressView();Button("Cancel") { state.translationModels.task?.cancel() } } }
   if !state.translationModels.status.isEmpty,!state.translationModels.status.hasPrefix("Available language pairs:") {
    Section { Text(L(state.translationModels.status)).font(.callout).foregroundStyle(.secondary).textSelection(.enabled) }
   }
   Section {
    HStack {
     Button("Refresh model catalog") { state.translationModels.refreshCatalog() }
     Spacer()
     Link("Learn more…",destination:URL(string:"https://github.com/argosopentech/argospm-index")!)
     Menu("Import…") {
      Button("Import model folder…") { state.translationModels.chooseFolder { await state.activateTranslationModel($0) } }
      Button("Import model package…") { state.translationModels.importArchive { await state.activateTranslationModel($0) } }
     }
    }.disabled(busy)
   }
  }.formStyle(.grouped)
   .onAppear { if state.translationModels.allAvailable.isEmpty { state.translationModels.refreshCatalog() } }
 }
 private func activatePlan() { state.translationModels.downloadPlan { await state.activateTranslationRoute($0) } }
 private var languages:[String] { Array(Set(state.translationModels.languages+[state.translationModels.sourceLanguage,state.translationModels.targetLanguage])).sorted() }
 private func installedRow(_ info:TranslationModelInfo) -> some View {
  HStack(alignment:.top,spacing:12) {
   Image(systemName:"cpu").font(.title2).frame(width:24).padding(.top,3)
   VStack(alignment:.leading,spacing:4) {
    Text(info.label).font(.headline)
    Text("\(TranslationCatalogItem.language(info.from)) → \(TranslationCatalogItem.language(info.to)) · \(info.size)").font(.callout).foregroundStyle(.secondary)
    Text("Offline text translation. Small dedicated language model; context and idioms may need review.").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
    Button("Delete…",role:.destructive) { state.removeTranslationModel(info.folder) }.buttonStyle(.plain).foregroundStyle(.red).disabled(busy)
   }.frame(maxWidth:.infinity,alignment:.leading)
   if state.translationFolders.contains(info.folder) { Label("Active",systemImage:"record.circle.fill").foregroundStyle(Color.accentColor).fixedSize() }
   else { Button("Use model") { state.translationModels.checkAndActivate(info.folder) { await state.activateTranslationModel($0) } }.controlSize(.small).disabled(busy) }
  }.padding(.vertical,6)
 }
}
