from pathlib import Path
import hashlib
root=Path(__file__).resolve().parents[1]
def uid(s):return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
files=sorted([*root.glob('App/*.swift'),*root.glob('Views/*.swift'),*root.glob('Services/**/*.swift'),*root.glob('Models/*.swift'),root/'NativeCore/NativeBridge.c',root/'NativeCore/TranslationBridge.cc'])
objects=[]
def obj(key,body):objects.append(f'{uid(key)} = {{ {body} }};')
refs=[]; builds=[]
for p in files:
 if p.name.startswith('._'):continue
 path=str(p.relative_to(root));key='file:'+path;build='build:'+path
 obj(key,f'isa = PBXFileReference; lastKnownFileType = {"sourcecode.cpp.cpp" if p.suffix==".cc" else "sourcecode.c.c" if p.suffix==".c" else "sourcecode.swift"}; path = "{path}"; sourceTree = "<group>";')
 obj(build,f'isa = PBXBuildFile; fileRef = {uid(key)};');refs.append(uid(key));builds.append(uid(build))
obj('app','isa = PBXFileReference; explicitFileType = wrapper.application; path = fnota.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj('products',f'isa = PBXGroup; children = ({uid("app")},); name = Products; sourceTree = "<group>";')
obj('main',f'isa = PBXGroup; children = ({",".join(refs)},{uid("products")},); sourceTree = "<group>";')
obj('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)},); runOnlyForDeploymentPostprocessing = 0;')
obj('frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
obj('resources','isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
settings='''MARKETING_VERSION = 0.1.0; CURRENT_PROJECT_VERSION = 1; ARCHS = arm64; ENABLE_DEBUG_DYLIB = NO; SDKROOT = macosx; MACOSX_DEPLOYMENT_TARGET = 27.0; SWIFT_VERSION = 6.0; CLANG_ENABLE_MODULES = YES; CLANG_CXX_LANGUAGE_STANDARD = "c++17"; GCC_C_LANGUAGE_STANDARD = gnu11; PRODUCT_BUNDLE_IDENTIFIER = local.safarilocalru.UniversalMac; PRODUCT_NAME = fnota; EXECUTABLE_NAME = UniversalMac; PRODUCT_MODULE_NAME = UniversalMac; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_LSUIElement = YES; INFOPLIST_KEY_CFBundleIconFile = AppIcon; INFOPLIST_KEY_CFBundleDisplayName = fnota; INFOPLIST_KEY_CFBundleName = fnota; INFOPLIST_KEY_NSMicrophoneUsageDescription = "Records speech for local dictation. Audio stays on your Mac."; INFOPLIST_KEY_NSAppleEventsUsageDescription = "Translates the current browser page locally at your request."; INFOPLIST_KEY_NSPrincipalClass = NSApplication; SWIFT_OBJC_BRIDGING_HEADER = NativeCore/include/NativeBridge.h; LIBRARY_SEARCH_PATHS = ("$(inherited)","$(SRCROOT)/Vendor/sherpa-onnx-v2.0.0-osx-arm64-shared-no-tts/lib"); HEADER_SEARCH_PATHS = ("$(SRCROOT)/Vendor/CTranslate2-4.8.3/include","$(SRCROOT)/Vendor/sentencepiece-0.2.1/src"); OTHER_LDFLAGS = ("$(inherited)","-lsherpa-onnx-c-api","$(SRCROOT)/Vendor/native-libs/libctranslate2.4.8.3.dylib","$(SRCROOT)/Vendor/native-libs/libsentencepiece.a","-lc++"); LD_RUNPATH_SEARCH_PATHS = ("$(inherited)","@executable_path/../Frameworks"); ENABLE_APP_SANDBOX = NO; CODE_SIGNING_ALLOWED = NO; SWIFT_OPTIMIZATION_LEVEL = "-Onone";'''
for kind in ['Debug','Release']:
 obj('project'+kind,f'isa = XCBuildConfiguration; buildSettings = {{ }}; name = {kind};')
 obj('target'+kind,f'isa = XCBuildConfiguration; buildSettings = {{ {settings} }}; name = {kind};')
obj('projectconfigs',f'isa = XCConfigurationList; buildConfigurations = ({uid("projectDebug")},{uid("projectRelease")}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;')
obj('targetconfigs',f'isa = XCConfigurationList; buildConfigurations = ({uid("targetDebug")},{uid("targetRelease")}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;')
obj('target',f'isa = PBXNativeTarget; buildConfigurationList = {uid("targetconfigs")}; buildPhases = ({uid("sources")},{uid("frameworks")},{uid("resources")}); buildRules = (); dependencies = (); name = UniversalMac; productName = UniversalMac; productReference = {uid("app")}; productType = "com.apple.product-type.application";')
obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2700; }}; buildConfigurationList = {uid("projectconfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = ru; knownRegions = (ru,en,Base); mainGroup = {uid("main")}; productRefGroup = {uid("products")}; projectDirPath = ""; projectRoot = ""; targets = ({uid("target")},);')
project=root/'UniversalMac.xcodeproj';project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+'\n}; rootObject = '+uid('project')+'; }\n')
