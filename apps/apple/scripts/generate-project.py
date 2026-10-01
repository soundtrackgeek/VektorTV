#!/usr/bin/env python3
"""Generate the checked-in Xcode project without third-party project generators."""
from pathlib import Path
import hashlib
import json
import plistlib

root = Path(__file__).resolve().parents[1]
project = root / "VektorTV.xcodeproj"
objects = {}

def identifier(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

def add(identity, isa, **values):
    key = identifier(identity)
    objects[key] = dict(isa=isa, **values)
    return key

def configs(name, settings):
    ids = []
    for config in ["Debug", "Release"]:
        values = dict(settings)
        values.update(SWIFT_OPTIMIZATION_LEVEL="-Onone" if config == "Debug" else "-O",
                      DEBUG_INFORMATION_FORMAT="dwarf" if config == "Debug" else "dwarf-with-dsym",
                      SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG" if config == "Debug" else "")
        ids.append(add(name + config, "XCBuildConfiguration", name=config, buildSettings=values))
    return add(name + "Configs", "XCConfigurationList", buildConfigurations=ids, defaultConfigurationIsVisible=0, defaultConfigurationName="Release")

sources = [add(str(path), "PBXFileReference", lastKnownFileType="sourcecode.swift", path=str(path.relative_to(root)), sourceTree="SOURCE_ROOT") for path in sorted((root / "Shared").glob("*.swift"))]
test_source = add("UITestSource", "PBXFileReference", lastKnownFileType="sourcecode.swift", path="UITests/ViewingRoomUITests.swift", sourceTree="SOURCE_ROOT")
privacy = add("Privacy", "PBXFileReference", lastKnownFileType="text.xml", path="Resources/PrivacyInfo.xcprivacy", sourceTree="SOURCE_ROOT")
flags = add("Flags", "PBXFileReference", lastKnownFileType="folder.assetcatalog", path="Resources/Flags.xcassets", sourceTree="SOURCE_ROOT")
country_license = add("CountryLicense", "PBXFileReference", lastKnownFileType="text", path="Resources/CountryAssets-LICENSE.txt", sourceTree="SOURCE_ROOT")
products = []
targets = []
resource_refs = [privacy, flags, country_license]
for name, sdk, family, deployment, assets in [
    ("VektorTV-iOS", "iphoneos", "1,2", "IPHONEOS_DEPLOYMENT_TARGET", "iOS"),
    ("VektorTV-tvOS", "appletvos", "3", "TVOS_DEPLOYMENT_TARGET", "tvOS"),
]:
    asset = add(name + "Assets", "PBXFileReference", lastKnownFileType="folder.assetcatalog", path=f"Resources/{assets}/Assets.xcassets", sourceTree="SOURCE_ROOT")
    resource_refs.append(asset)
    product = add(name + "Product", "PBXFileReference", explicitFileType="wrapper.application", path=f"{name}.app", sourceTree="BUILT_PRODUCTS_DIR")
    products.append(product)
    source_phase = add(name + "Sources", "PBXSourcesBuildPhase", buildActionMask=2147483647, files=[add(name + source, "PBXBuildFile", fileRef=source) for source in sources], runOnlyForDeploymentPostprocessing=0)
    resource_phase = add(name + "Resources", "PBXResourcesBuildPhase", buildActionMask=2147483647, files=[add(name + ref, "PBXBuildFile", fileRef=ref) for ref in [asset, privacy, flags, country_license]], runOnlyForDeploymentPostprocessing=0)
    framework_phase = add(name + "Frameworks", "PBXFrameworksBuildPhase", buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
    rust_phase = add(name + "Rust", "PBXShellScriptBuildPhase", buildActionMask=2147483647, files=[], inputPaths=[], outputPaths=["$(BUILT_PRODUCTS_DIR)/libvektortv_apple.a"], runOnlyForDeploymentPostprocessing=0, shellPath="/bin/bash", shellScript='"$SRCROOT/scripts/build-rust.sh"', name="Build shared Rust core", alwaysOutOfDate=1)
    settings = dict(
        PRODUCT_NAME="$(TARGET_NAME)", PRODUCT_BUNDLE_IDENTIFIER="com.soundtrackgeek.vektortv",
        DEVELOPMENT_TEAM="3L5769JKCM", CODE_SIGN_STYLE="Automatic", SDKROOT=sdk,
        SUPPORTED_PLATFORMS="iphoneos iphonesimulator" if sdk == "iphoneos" else "appletvos appletvsimulator",
        TARGETED_DEVICE_FAMILY=family, MARKETING_VERSION="0.6.1", CURRENT_PROJECT_VERSION="9",
        INFOPLIST_FILE=f"Resources/{assets}/Info.plist", SWIFT_VERSION="5.0",
        SWIFT_STRICT_CONCURRENCY="complete", SWIFT_OBJC_BRIDGING_HEADER="Bridge/BridgingHeader.h",
        ENABLE_USER_SCRIPT_SANDBOXING="NO", ENABLE_BITCODE="NO", GENERATE_INFOPLIST_FILE="NO",
        ASSETCATALOG_COMPILER_APPICON_NAME="AppIcon", ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME="AccentColor",
        LIBRARY_SEARCH_PATHS=["$(inherited)", "$(BUILT_PRODUCTS_DIR)"],
        LD_RUNPATH_SEARCH_PATHS=["$(inherited)", "@executable_path/Frameworks"],
        OTHER_LDFLAGS=["$(inherited)", "-lvektortv_apple", "-lresolv", "-liconv", "-framework", "Security", "-framework", "SystemConfiguration"],
        SUPPORTS_MACCATALYST="NO", SWIFT_EMIT_LOC_STRINGS="YES",
    )
    settings[deployment] = "18.0"
    if sdk == "appletvos":
        settings["ARCHS"] = "arm64"
    target = add(name, "PBXNativeTarget", name=name, productName=name, productReference=product, productType="com.apple.product-type.application", buildConfigurationList=configs(name, settings), buildPhases=[rust_phase, source_phase, framework_phase, resource_phase], buildRules=[], dependencies=[])
    targets.append(target)
    test_name = name + "UITests"
    test_product = add(test_name + "Product", "PBXFileReference", explicitFileType="wrapper.cfbundle", path=test_name + ".xctest", sourceTree="BUILT_PRODUCTS_DIR")
    products.append(test_product)
    test_sources = add(test_name + "Sources", "PBXSourcesBuildPhase", buildActionMask=2147483647, files=[add(test_name + "Source", "PBXBuildFile", fileRef=test_source)], runOnlyForDeploymentPostprocessing=0)
    proxy = add(test_name + "Proxy", "PBXContainerItemProxy", containerPortal=identifier("Project"), proxyType=1, remoteGlobalIDString=target, remoteInfo=name)
    dependency = add(test_name + "Dependency", "PBXTargetDependency", target=target, targetProxy=proxy)
    test_settings = dict(PRODUCT_NAME="$(TARGET_NAME)", PRODUCT_BUNDLE_IDENTIFIER="com.soundtrackgeek.vektortv." + assets.lower() + "-uitests", SDKROOT=sdk,
        DEVELOPMENT_TEAM="3L5769JKCM", CODE_SIGN_STYLE="Automatic", TARGETED_DEVICE_FAMILY=family,
        SWIFT_VERSION="5.0", GENERATE_INFOPLIST_FILE="YES", TEST_TARGET_NAME=name, **{deployment:"18.0"})
    test_target = add(test_name, "PBXNativeTarget", name=test_name, productName=test_name, productReference=test_product,
        productType="com.apple.product-type.bundle.ui-testing", buildConfigurationList=configs(test_name, test_settings),
        buildPhases=[test_sources], buildRules=[], dependencies=[dependency])
    targets.append(test_target)
    test_reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{test_target}" BuildableName="{test_name}.xctest" BlueprintName="{test_name}" ReferencedContainer="container:VektorTV.xcodeproj"/>'
    schemes = project / "xcshareddata/xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{name}.app" BlueprintName="{name}" ReferencedContainer="container:VektorTV.xcodeproj"/>'
    (schemes / f"{name}.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2650" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test_reference}</TestableReference></Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')

source_group = add("Shared", "PBXGroup", name="Shared", children=sources + [test_source], sourceTree="<group>")
resource_group = add("Resources", "PBXGroup", name="Resources", children=resource_refs, sourceTree="<group>")
product_group = add("Products", "PBXGroup", name="Products", children=products, sourceTree="<group>")
main_group = add("Main", "PBXGroup", children=[source_group, resource_group, product_group], sourceTree="<group>")
project_id = add("Project", "PBXProject", attributes={"LastUpgradeCheck":"2650", "TargetAttributes":{target:{"CreatedOnToolsVersion":"26.5", "DevelopmentTeam":"3L5769JKCM", "ProvisioningStyle":"Automatic"} for target in targets}}, buildConfigurationList=configs("Project", {"CLANG_ENABLE_MODULES":"YES", "CLANG_ENABLE_OBJC_ARC":"YES", "ONLY_ACTIVE_ARCH":"YES"}), compatibilityVersion="Xcode 14.0", developmentRegion="en", hasScannedForEncodings=0, knownRegions=["en", "Base"], mainGroup=main_group, productRefGroup=product_group, projectDirPath="", projectRoot="", targets=targets)

def serialize(value, depth=0):
    indent = "\t" * depth
    if isinstance(value, dict):
        return "{\n" + "".join(f"{indent}\t{json.dumps(str(key))} = {serialize(item, depth+1)};\n" for key, item in value.items()) + indent + "}"
    if isinstance(value, list):
        return "(\n" + "".join(f"{indent}\t{serialize(item, depth+1)},\n" for item in value) + indent + ")"
    if isinstance(value, int):
        return str(value)
    return json.dumps(value)

(project / "project.pbxproj").write_text("// !$*UTF8*$!\n" + serialize(dict(archiveVersion=1, classes={}, objectVersion=56, objects=objects, rootObject=project_id)) + "\n")

common = dict(CFBundleDevelopmentRegion="$(DEVELOPMENT_LANGUAGE)", CFBundleDisplayName="VektorTV", CFBundleExecutable="$(EXECUTABLE_NAME)", CFBundleIdentifier="$(PRODUCT_BUNDLE_IDENTIFIER)", CFBundleInfoDictionaryVersion="6.0", CFBundleName="$(PRODUCT_NAME)", CFBundlePackageType="APPL", CFBundleShortVersionString="$(MARKETING_VERSION)", CFBundleVersion="$(CURRENT_PROJECT_VERSION)", ITSAppUsesNonExemptEncryption=False, NSAppTransportSecurity={"NSAllowsArbitraryLoads":True}, UIBackgroundModes=["audio"])
for platform in ["iOS", "tvOS"]:
    values = dict(common)
    if platform == "iOS":
        values.update(LSRequiresIPhoneOS=True, UILaunchScreen={}, UIApplicationSupportsIndirectInputEvents=True, UISupportedInterfaceOrientations=["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"], **{"UISupportedInterfaceOrientations~ipad":["UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"]})
    directory = root / "Resources" / platform
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "Info.plist").write_bytes(plistlib.dumps(values))
cloud = project / "xcshareddata/xcodecloud"
cloud.mkdir(parents=True, exist_ok=True)
# Xcode can regenerate the cloud manifest when the workflows are connected.
print("Generated VektorTV iOS and tvOS projects and shared schemes.")
