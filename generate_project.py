#!/usr/bin/env python3
"""
MacSweep v3.3 Xcode Project Generator
Automatically creates a complete Xcode project from Swift source files.
"""

import os, uuid, shutil
from pathlib import Path

PROJECT = "MacSweep"
BUNDLE  = "com.mehmed.MacSweep"
SWIFT_FILES = [
    "MacSweepApp.swift", "ContentView.swift", "Models.swift",
    "ScanEngine.swift", "CleanEngine.swift", "SidebarView.swift",
    "DashboardView.swift", "SmartScanView.swift", "LargeFilesView.swift",
    "AppLeftoversView.swift", "BrowserCleanerView.swift", "CleanResultSheet.swift",
    "MenuBarView.swift", "SystemJunkView.swift", "MaintenanceView.swift",
    "PrivacyView.swift", "SpaceLensView.swift", "SettingsView.swift",
    "DevCleanerView.swift",
]

def uid(): return uuid.uuid4().hex[:24].upper()

def pbxproj():
    proj_id   = uid(); tgt_id    = uid()
    cl_proj   = uid(); cl_tgt    = uid()
    cd_proj   = uid(); cr_proj   = uid()
    cd_tgt    = uid(); cr_tgt    = uid()
    src_ph    = uid(); frm_ph    = uid(); res_ph = uid()
    main_grp  = uid(); src_grp   = uid(); prod_grp = uid()
    app_ref   = uid(); assets_ref = uid(); assets_build = uid()

    fids = {f: (uid(), uid()) for f in SWIFT_FILES}

    L = ["// !$*UTF8*$!", "{",
         "\tarchiveVersion = 1;", "\tclasses = { };",
         "\tobjectVersion = 56;", "\tobjects = {", ""]

    L += ["/* Begin PBXBuildFile section */"]
    for f, (ref, bld) in fids.items():
        L.append(f"\t\t{bld} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {f} */; }};")
    L.append(f"\t\t{assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_ref} /* Assets.xcassets */; }};")
    L += ["/* End PBXBuildFile section */", ""]

    L += ["/* Begin PBXFileReference section */"]
    L.append(f"\t\t{app_ref} /* {PROJECT}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {PROJECT}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for f, (ref, bld) in fids.items():
        L.append(f'\t\t{ref} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = "<group>"; }};')
    L.append(f'\t\t{assets_ref} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};')
    L += ["/* End PBXFileReference section */", ""]

    L += [f"/* Begin PBXFrameworksBuildPhase section */",
          f"\t\t{frm_ph} /* Frameworks */ = {{",
          "\t\t\tisa = PBXFrameworksBuildPhase;",
          "\t\t\tbuildActionMask = 2147483647;",
          "\t\t\tfiles = ( );",
          "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
          "\t\t};",
          "/* End PBXFrameworksBuildPhase section */", ""]

    L += ["/* Begin PBXGroup section */",
          f"\t\t{main_grp} = {{", "\t\t\tisa = PBXGroup;", "\t\t\tchildren = (",
          f"\t\t\t\t{src_grp} /* {PROJECT} */,",
          f"\t\t\t\t{prod_grp} /* Products */,",
          '\t\t\t);', '\t\t\tsourceTree = "<group>";', "\t\t};",
          f"\t\t{prod_grp} /* Products */ = {{", "\t\t\tisa = PBXGroup;", "\t\t\tchildren = (",
          f"\t\t\t\t{app_ref} /* {PROJECT}.app */,",
          '\t\t\t);', "\t\t\tname = Products;", '\t\t\tsourceTree = "<group>";', "\t\t};",
          f"\t\t{src_grp} /* {PROJECT} */ = {{", "\t\t\tisa = PBXGroup;", "\t\t\tchildren = ("]
    for f, (ref, bld) in fids.items():
        L.append(f"\t\t\t\t{ref} /* {f} */,")
    L += [f"\t\t\t\t{assets_ref} /* Assets.xcassets */,",
          '\t\t\t);', f"\t\t\tpath = {PROJECT};", '\t\t\tsourceTree = "<group>";', "\t\t};",
          "/* End PBXGroup section */", ""]

    L += ["/* Begin PBXNativeTarget section */",
          f"\t\t{tgt_id} /* {PROJECT} */ = {{", "\t\t\tisa = PBXNativeTarget;",
          f'\t\t\tbuildConfigurationList = {cl_tgt} /* Build configuration list for PBXNativeTarget "{PROJECT}" */;',
          "\t\t\tbuildPhases = (",
          f"\t\t\t\t{src_ph} /* Sources */,",
          f"\t\t\t\t{frm_ph} /* Frameworks */,",
          f"\t\t\t\t{res_ph} /* Resources */,",
          "\t\t\t);", "\t\t\tbuildRules = ( );", "\t\t\tdependencies = ( );",
          f"\t\t\tname = {PROJECT};", f"\t\t\tproductName = {PROJECT};",
          f"\t\t\tproductReference = {app_ref} /* {PROJECT}.app */;",
          '\t\t\tproductType = "com.apple.product-type.application";',
          "\t\t};", "/* End PBXNativeTarget section */", ""]

    L += ["/* Begin PBXProject section */",
          f"\t\t{proj_id} /* Project object */ = {{", "\t\t\tisa = PBXProject;",
          "\t\t\tattributes = {", "\t\t\t\tLastSwiftUpdateCheck = 1500;",
          "\t\t\t\tLastUpgradeCheck = 1500;",
          f"\t\t\t\tTargetAttributes = {{ {tgt_id} = {{ CreatedOnToolsVersion = 15.0; }}; }};",
          "\t\t\t};",
          f'\t\t\tbuildConfigurationList = {cl_proj} /* Build configuration list for PBXProject "{PROJECT}" */;',
          '\t\t\tcompatibilityVersion = "Xcode 14.0";',
          "\t\t\tdevelopmentRegion = en;", "\t\t\thasScannedForEncodings = 0;",
          "\t\t\tknownRegions = ( en, Base, );",
          f"\t\t\tmainGroup = {main_grp};", f"\t\t\tproductRefGroup = {prod_grp} /* Products */;",
          '\t\t\tprojectDirPath = "";', '\t\t\tprojectRoot = "";',
          f"\t\t\ttargets = ( {tgt_id} /* {PROJECT} */, );",
          "\t\t};", "/* End PBXProject section */", ""]

    L += ["/* Begin PBXResourcesBuildPhase section */",
          f"\t\t{res_ph} /* Resources */ = {{", "\t\t\tisa = PBXResourcesBuildPhase;",
          "\t\t\tbuildActionMask = 2147483647;", "\t\t\tfiles = (",
          f"\t\t\t\t{assets_build} /* Assets.xcassets in Resources */,",
          "\t\t\t);", "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
          "\t\t};", "/* End PBXResourcesBuildPhase section */", ""]

    L += ["/* Begin PBXSourcesBuildPhase section */",
          f"\t\t{src_ph} /* Sources */ = {{", "\t\t\tisa = PBXSourcesBuildPhase;",
          "\t\t\tbuildActionMask = 2147483647;", "\t\t\tfiles = ("]
    for f, (ref, bld) in fids.items():
        L.append(f"\t\t\t\t{bld} /* {f} in Sources */,")
    L += ["\t\t\t);", "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
          "\t\t};", "/* End PBXSourcesBuildPhase section */", ""]

    def base_settings():
        return ["\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;",
                "\t\t\t\tCLANG_ENABLE_MODULES = YES;",
                "\t\t\t\tSWIFT_VERSION = 5.0;",
                "\t\t\t\tMACOS_DEPLOYMENT_TARGET = 13.0;",
                "\t\t\t\tCODE_SIGN_STYLE = Automatic;",
                "\t\t\t\tCODE_SIGNING_REQUIRED = NO;",
                '\t\t\t\tCODE_SIGN_IDENTITY = "-";']

    def target_settings():
        return [f"\t\t\t\tBUNDLE_IDENTIFIER = {BUNDLE};",
                "\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
                "\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;",
                f"\t\t\t\tINFOPLIST_FILE = {PROJECT}/Info.plist;",
                '\t\t\t\tLD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks";',
                f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {BUNDLE};",
                '\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";',
                "\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;",
                "\t\t\t\tCODE_SIGN_STYLE = Automatic;",
                "\t\t\t\tCODE_SIGNING_REQUIRED = NO;",
                '\t\t\t\tCODE_SIGN_IDENTITY = "-";']

    L += ["/* Begin XCBuildConfiguration section */"]
    for cid, name, extra in [
        (cd_proj, "Debug",   []), (cr_proj, "Release", []),
        (cd_tgt,  "Debug",   target_settings()), (cr_tgt,  "Release", target_settings()),
    ]:
        L += [f"\t\t{cid} /* {name} */ = {{", "\t\t\tisa = XCBuildConfiguration;",
              "\t\t\tbuildSettings = {"]
        L += base_settings() + extra
        L += ["\t\t\t};", f"\t\t\tname = {name};", "\t\t};"]
    L += ["/* End XCBuildConfiguration section */", ""]

    L += ["/* Begin XCConfigurationList section */",
          f'\t\t{cl_proj} /* Build configuration list for PBXProject "{PROJECT}" */ = {{',
          "\t\t\tisa = XCConfigurationList;", "\t\t\tbuildConfigurations = (",
          f"\t\t\t\t{cd_proj} /* Debug */,", f"\t\t\t\t{cr_proj} /* Release */,",
          "\t\t\t);", "\t\t\tdefaultConfigurationIsVisible = 0;",
          "\t\t\tdefaultConfigurationName = Release;", "\t\t};",
          f'\t\t{cl_tgt} /* Build configuration list for PBXNativeTarget "{PROJECT}" */ = {{',
          "\t\t\tisa = XCConfigurationList;", "\t\t\tbuildConfigurations = (",
          f"\t\t\t\t{cd_tgt} /* Debug */,", f"\t\t\t\t{cr_tgt} /* Release */,",
          "\t\t\t);", "\t\t\tdefaultConfigurationIsVisible = 0;",
          "\t\t\tdefaultConfigurationName = Release;", "\t\t};",
          "/* End XCConfigurationList section */", "\t};",
          f"\trootObject = {proj_id} /* Project object */;", "}"]

    return "\n".join(L)


INFO_PLIST = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleDevelopmentRegion</key><string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key><string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key><string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key><string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key><string>3.3</string>
    <key>CFBundleVersion</key><string>33</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>LSUIElement</key><false/>
    <key>NSFullDiskAccessUsageDescription</key>
    <string>MacSweep needs full disk access to scan and clean junk files on your Mac.</string>
    <key>NSHumanReadableCopyright</key><string>Copyright 2026 Mehmed. Open Source - Free for all.</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>LSMultipleInstancesProhibited</key><true/>
</dict></plist>"""


def main():
    here = Path(__file__).parent
    print(f"MacSweep v3.3 - Generating Xcode project...")

    src = here / PROJECT
    src.mkdir(exist_ok=True)

    missing = []
    for f in SWIFT_FILES:
        in_target = src / f
        legacy = here / f
        if in_target.exists():
            print(f"  + {f}")
        elif legacy.exists():
            # One-time migration from legacy root layout.
            shutil.copy2(legacy, in_target)
            print(f"  + {f} (migrated)")
        else:
            missing.append(f)
            print(f"  ! MISSING: {f}")

    if missing:
        print(f"\nMissing files: {missing}")
        return False

    assets = src / "Assets.xcassets"
    appicon = assets / "AppIcon.appiconset"
    appicon.mkdir(parents=True, exist_ok=True)
    (assets / "Contents.json").write_text('{\n  "info" : { "author" : "xcode", "version" : 1 }\n}')
    # Only write empty AppIcon Contents.json if no icon has been generated yet
    appicon_png = appicon / "AppIcon-1024.png"
    if not appicon_png.exists():
        (appicon / "Contents.json").write_text('{\n  "images" : [],\n  "info" : { "author" : "xcode", "version" : 1 }\n}')
    else:
        print(f"  ✓ Preserving existing AppIcon")

    (src / "Info.plist").write_text(INFO_PLIST)

    xcproj = here / f"{PROJECT}.xcodeproj"
    xcproj.mkdir(exist_ok=True)
    (xcproj / "project.pbxproj").write_text(pbxproj())

    print(f"\nXcode project created: {PROJECT}.xcodeproj")
    return True


if __name__ == "__main__":
    import sys
    sys.exit(0 if main() else 1)
