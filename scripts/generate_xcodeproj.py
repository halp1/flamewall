#!/usr/bin/env python3
"""Generate Flamewall.xcodeproj/project.pbxproj"""
from __future__ import annotations

import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def uid() -> str:
    return uuid.uuid4().hex[:24].upper()


def main() -> None:
    shared = sorted((ROOT / "Shared").glob("*.swift"))
    host_dirs = ["App", "Views", "Services", "Store"]
    host_files = []
    for d in host_dirs:
        host_files += sorted((ROOT / "Flamewall" / d).glob("*.swift"))
    filter_files = sorted((ROOT / "FlamewallFilter").glob("*.swift"))
    test_files = sorted((ROOT / "FlamewallTests").glob("*.swift"))

    ids = {k: uid() for k in [
        "project", "root", "shared_group", "host_group", "filter_group", "tests_group",
        "products_group", "host_app", "filter_product", "tests_product",
        "host_target", "filter_target", "tests_target",
        "host_sources", "host_frameworks", "host_embed",
        "filter_sources", "filter_frameworks",
        "tests_sources", "tests_frameworks",
        "project_configs", "host_configs", "filter_configs", "tests_configs",
        "project_debug", "project_release",
        "host_debug", "host_release", "filter_debug", "filter_release",
        "tests_debug", "tests_release",
        "dep", "proxy", "embed_build",
    ]}
    host_sub = {d: uid() for d in host_dirs + ["Resources"]}

    file_ids: dict[str, str] = {}
    host_build: dict[str, str] = {}
    filter_build: dict[str, str] = {}
    tests_build: dict[str, str] = {}

    def ref(path: Path) -> str:
        key = str(path.relative_to(ROOT))
        if key not in file_ids:
            file_ids[key] = uid()
        return key

    for p in shared + host_files + filter_files + test_files:
        key = ref(p)
        host_build[key] = uid()
        filter_build[key] = uid()
        tests_build[key] = uid()

    info_host = ref(ROOT / "Flamewall/Resources/Info.plist")
    ent_host = ref(ROOT / "Flamewall/Resources/Flamewall.entitlements")
    assets = ref(ROOT / "Flamewall/Resources/Assets.xcassets")
    info_filter = ref(ROOT / "FlamewallFilter/Info.plist")
    ent_filter = ref(ROOT / "FlamewallFilter/FlamewallFilter.entitlements")
    assets_build = uid()
    ids["host_resources_phase"] = uid()

    L: list[str] = []
    a = L.append

    a("// !$*UTF8*$!")
    a("{")
    a("\tarchiveVersion = 1;")
    a("\tclasses = {};")
    a("\tobjectVersion = 56;")
    a("\tobjects = {")
    a("")

    # Build files
    a("/* Begin PBXBuildFile section */")
    for p in shared + host_files:
        key = str(p.relative_to(ROOT))
        a(f"\t\t{host_build[key]} /* {p.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[key]} /* {p.name} */; }};")
    for p in shared + filter_files:
        key = str(p.relative_to(ROOT))
        a(f"\t\t{filter_build[key]} /* {p.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[key]} /* {p.name} */; }};")
    for p in shared + test_files:
        key = str(p.relative_to(ROOT))
        a(f"\t\t{tests_build[key]} /* {p.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[key]} /* {p.name} */; }};")
    a(f"\t\t{ids['embed_build']} /* FlamewallFilter.systemextension in Embed */ = {{isa = PBXBuildFile; fileRef = {ids['filter_product']} /* FlamewallFilter.systemextension */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};")
    a(f"\t\t{assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {file_ids[assets]} /* Assets.xcassets */; }};")
    a("/* End PBXBuildFile section */")
    a("")

    # Container proxy + dependency
    a("/* Begin PBXContainerItemProxy section */")
    a(f"\t\t{ids['proxy']} /* PBXContainerItemProxy */ = {{")
    a("\t\t\tisa = PBXContainerItemProxy;")
    a(f"\t\t\tcontainerPortal = {ids['project']} /* Project object */;")
    a("\t\t\tproxyType = 1;")
    a(f"\t\t\tremoteGlobalIDString = {ids['filter_target']};")
    a("\t\t\tremoteInfo = FlamewallFilter;")
    a("\t\t};")
    a("/* End PBXContainerItemProxy section */")
    a("")

    a("/* Begin PBXCopyFilesBuildPhase section */")
    a(f"\t\t{ids['host_embed']} /* Embed System Extensions */ = {{")
    a("\t\t\tisa = PBXCopyFilesBuildPhase;")
    a("\t\t\tbuildActionMask = 2147483647;")
    a("\t\t\tdstPath = \"$(SYSTEM_EXTENSIONS_FOLDER_PATH)\";")
    a("\t\t\tdstSubfolderSpec = 16;")
    a("\t\t\tfiles = (")
    a(f"\t\t\t\t{ids['embed_build']} /* FlamewallFilter.systemextension in Embed */,")
    a("\t\t\t);")
    a("\t\t\tname = \"Embed System Extensions\";")
    a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a("\t\t};")
    a("/* End PBXCopyFilesBuildPhase section */")
    a("")

    # File refs
    a("/* Begin PBXFileReference section */")
    a(f"\t\t{ids['host_app']} /* Flamewall.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Flamewall.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    a(f"\t\t{ids['filter_product']} /* FlamewallFilter.systemextension */ = {{isa = PBXFileReference; explicitFileType = \"wrapper.systemextension\"; includeInIndex = 0; path = FlamewallFilter.systemextension; sourceTree = BUILT_PRODUCTS_DIR; }};")
    a(f"\t\t{ids['tests_product']} /* FlamewallTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = FlamewallTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for p in shared + host_files + filter_files + test_files:
        key = str(p.relative_to(ROOT))
        a(f"\t\t{file_ids[key]} /* {p.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {p.name}; sourceTree = \"<group>\"; }};")
    a(f"\t\t{file_ids[info_host]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
    a(f"\t\t{file_ids[ent_host]} /* Flamewall.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Flamewall.entitlements; sourceTree = \"<group>\"; }};")
    a(f"\t\t{file_ids[assets]} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
    a(f"\t\t{file_ids[info_filter]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
    a(f"\t\t{file_ids[ent_filter]} /* FlamewallFilter.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = FlamewallFilter.entitlements; sourceTree = \"<group>\"; }};")
    a("/* End PBXFileReference section */")
    a("")

    # Frameworks phases
    a("/* Begin PBXFrameworksBuildPhase section */")
    for key in ("host_frameworks", "filter_frameworks", "tests_frameworks"):
        a(f"\t\t{ids[key]} /* Frameworks */ = {{")
        a("\t\t\tisa = PBXFrameworksBuildPhase;")
        a("\t\t\tbuildActionMask = 2147483647;")
        a("\t\t\tfiles = (")
        a("\t\t\t);")
        a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        a("\t\t};")
    a("/* End PBXFrameworksBuildPhase section */")
    a("")

    a("/* Begin PBXResourcesBuildPhase section */")
    a(f"\t\t{ids['host_resources_phase']} /* Resources */ = {{")
    a("\t\t\tisa = PBXResourcesBuildPhase;")
    a("\t\t\tbuildActionMask = 2147483647;")
    a("\t\t\tfiles = (")
    a(f"\t\t\t\t{assets_build} /* Assets.xcassets in Resources */,")
    a("\t\t\t);")
    a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a("\t\t};")
    a("/* End PBXResourcesBuildPhase section */")
    a("")

    # Groups
    a("/* Begin PBXGroup section */")
    a(f"\t\t{ids['root']} = {{")
    a("\t\t\tisa = PBXGroup;")
    a("\t\t\tchildren = (")
    a(f"\t\t\t\t{ids['host_group']} /* Flamewall */,")
    a(f"\t\t\t\t{ids['filter_group']} /* FlamewallFilter */,")
    a(f"\t\t\t\t{ids['shared_group']} /* Shared */,")
    a(f"\t\t\t\t{ids['tests_group']} /* FlamewallTests */,")
    a(f"\t\t\t\t{ids['products_group']} /* Products */,")
    a("\t\t\t);")
    a("\t\t\tsourceTree = \"<group>\";")
    a("\t\t};")

    a(f"\t\t{ids['products_group']} /* Products */ = {{")
    a("\t\t\tisa = PBXGroup;")
    a("\t\t\tchildren = (")
    a(f"\t\t\t\t{ids['host_app']} /* Flamewall.app */,")
    a(f"\t\t\t\t{ids['filter_product']} /* FlamewallFilter.systemextension */,")
    a(f"\t\t\t\t{ids['tests_product']} /* FlamewallTests.xctest */,")
    a("\t\t\t);")
    a("\t\t\tname = Products;")
    a("\t\t\tsourceTree = \"<group>\";")
    a("\t\t};")

    a(f"\t\t{ids['shared_group']} /* Shared */ = {{")
    a("\t\t\tisa = PBXGroup;")
    a("\t\t\tchildren = (")
    for p in shared:
        key = str(p.relative_to(ROOT))
        a(f"\t\t\t\t{file_ids[key]} /* {p.name} */,")
    a("\t\t\t);")
    a("\t\t\tpath = Shared;")
    a("\t\t\tsourceTree = \"<group>\";")
    a("\t\t};")

    a(f"\t\t{ids['host_group']} /* Flamewall */ = {{")
    a("\t\t\tisa = PBXGroup;")
    a("\t\t\tchildren = (")
    for d in host_dirs + ["Resources"]:
        a(f"\t\t\t\t{host_sub[d]} /* {d} */,")
    a("\t\t\t);")
    a("\t\t\tpath = Flamewall;")
    a("\t\t\tsourceTree = \"<group>\";")
    a("\t\t};")

    for d in host_dirs:
        a(f"\t\t{host_sub[d]} /* {d} */ = {{")
        a("\t\t\tisa = PBXGroup;")
        a("\t\t\tchildren = (")
        for p in sorted((ROOT / "Flamewall" / d).glob("*.swift")):
            key = str(p.relative_to(ROOT))
            a(f"\t\t\t\t{file_ids[key]} /* {p.name} */,")
        a("\t\t\t);")
        a(f"\t\t\tpath = {d};")
        a("\t\t\tsourceTree = \"<group>\";")
        a("\t\t};")

    a(f"\t\t{host_sub['Resources']} /* Resources */ = {{")
    a("\t\t\tisa = PBXGroup;")
    a("\t\t\tchildren = (")
    a(f"\t\t\t\t{file_ids[info_host]} /* Info.plist */,")
    a(f"\t\t\t\t{file_ids[ent_host]} /* Flamewall.entitlements */,")
    a(f"\t\t\t\t{file_ids[assets]} /* Assets.xcassets */,")
    a("\t\t\t);")
    a("\t\t\tpath = Resources;")
    a("\t\t\tsourceTree = \"<group>\";")
    a("\t\t};")

    a(f"\t\t{ids['filter_group']} /* FlamewallFilter */ = {{")
    a("\t\t\tisa = PBXGroup;")
    a("\t\t\tchildren = (")
    for p in filter_files:
        key = str(p.relative_to(ROOT))
        a(f"\t\t\t\t{file_ids[key]} /* {p.name} */,")
    a(f"\t\t\t\t{file_ids[info_filter]} /* Info.plist */,")
    a(f"\t\t\t\t{file_ids[ent_filter]} /* FlamewallFilter.entitlements */,")
    a("\t\t\t);")
    a("\t\t\tpath = FlamewallFilter;")
    a("\t\t\tsourceTree = \"<group>\";")
    a("\t\t};")

    a(f"\t\t{ids['tests_group']} /* FlamewallTests */ = {{")
    a("\t\t\tisa = PBXGroup;")
    a("\t\t\tchildren = (")
    for p in test_files:
        key = str(p.relative_to(ROOT))
        a(f"\t\t\t\t{file_ids[key]} /* {p.name} */,")
    a("\t\t\t);")
    a("\t\t\tpath = FlamewallTests;")
    a("\t\t\tsourceTree = \"<group>\";")
    a("\t\t};")
    a("/* End PBXGroup section */")
    a("")

    # Targets
    a("/* Begin PBXNativeTarget section */")
    a(f"\t\t{ids['host_target']} /* Flamewall */ = {{")
    a("\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {ids['host_configs']} /* Build configuration list for PBXNativeTarget \"Flamewall\" */;")
    a("\t\t\tbuildPhases = (")
    a(f"\t\t\t\t{ids['host_sources']} /* Sources */,")
    a(f"\t\t\t\t{ids['host_frameworks']} /* Frameworks */,")
    a(f"\t\t\t\t{ids['host_resources_phase']} /* Resources */,")
    a(f"\t\t\t\t{ids['host_embed']} /* Embed System Extensions */,")
    a("\t\t\t);")
    a("\t\t\tbuildRules = (")
    a("\t\t\t);")
    a("\t\t\tdependencies = (")
    a(f"\t\t\t\t{ids['dep']} /* PBXTargetDependency */,")
    a("\t\t\t);")
    a("\t\t\tname = Flamewall;")
    a("\t\t\tproductName = Flamewall;")
    a(f"\t\t\tproductReference = {ids['host_app']} /* Flamewall.app */;")
    a("\t\t\tproductType = \"com.apple.product-type.application\";")
    a("\t\t};")

    a(f"\t\t{ids['filter_target']} /* FlamewallFilter */ = {{")
    a("\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {ids['filter_configs']} /* Build configuration list for PBXNativeTarget \"FlamewallFilter\" */;")
    a("\t\t\tbuildPhases = (")
    a(f"\t\t\t\t{ids['filter_sources']} /* Sources */,")
    a(f"\t\t\t\t{ids['filter_frameworks']} /* Frameworks */,")
    a("\t\t\t);")
    a("\t\t\tbuildRules = (")
    a("\t\t\t);")
    a("\t\t\tdependencies = (")
    a("\t\t\t);")
    a("\t\t\tname = FlamewallFilter;")
    a("\t\t\tproductName = FlamewallFilter;")
    a(f"\t\t\tproductReference = {ids['filter_product']} /* FlamewallFilter.systemextension */;")
    a("\t\t\tproductType = \"com.apple.product-type.system-extension\";")
    a("\t\t};")

    a(f"\t\t{ids['tests_target']} /* FlamewallTests */ = {{")
    a("\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {ids['tests_configs']} /* Build configuration list for PBXNativeTarget \"FlamewallTests\" */;")
    a("\t\t\tbuildPhases = (")
    a(f"\t\t\t\t{ids['tests_sources']} /* Sources */,")
    a(f"\t\t\t\t{ids['tests_frameworks']} /* Frameworks */,")
    a("\t\t\t);")
    a("\t\t\tbuildRules = (")
    a("\t\t\t);")
    a("\t\t\tdependencies = (")
    a("\t\t\t);")
    a("\t\t\tname = FlamewallTests;")
    a("\t\t\tproductName = FlamewallTests;")
    a(f"\t\t\tproductReference = {ids['tests_product']} /* FlamewallTests.xctest */;")
    a("\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
    a("\t\t};")
    a("/* End PBXNativeTarget section */")
    a("")

    # Project
    a("/* Begin PBXProject section */")
    a(f"\t\t{ids['project']} /* Project object */ = {{")
    a("\t\t\tisa = PBXProject;")
    a("\t\t\tattributes = {")
    a("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    a("\t\t\t\tLastSwiftUpdateCheck = 1600;")
    a("\t\t\t\tLastUpgradeCheck = 1600;")
    a("\t\t\t};")
    a(f"\t\t\tbuildConfigurationList = {ids['project_configs']} /* Build configuration list for PBXProject \"Flamewall\" */;")
    a("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    a("\t\t\tdevelopmentRegion = en;")
    a("\t\t\thasScannedForEncodings = 0;")
    a("\t\t\tknownRegions = (")
    a("\t\t\t\ten,")
    a("\t\t\t\tBase,")
    a("\t\t\t);")
    a(f"\t\t\tmainGroup = {ids['root']};")
    a(f"\t\t\tproductRefGroup = {ids['products_group']} /* Products */;")
    a("\t\t\tprojectDirPath = \"\";")
    a("\t\t\tprojectRoot = \"\";")
    a("\t\t\ttargets = (")
    a(f"\t\t\t\t{ids['host_target']} /* Flamewall */,")
    a(f"\t\t\t\t{ids['filter_target']} /* FlamewallFilter */,")
    a(f"\t\t\t\t{ids['tests_target']} /* FlamewallTests */,")
    a("\t\t\t);")
    a("\t\t};")
    a("/* End PBXProject section */")
    a("")

    # Sources
    a("/* Begin PBXSourcesBuildPhase section */")
    a(f"\t\t{ids['host_sources']} /* Sources */ = {{")
    a("\t\t\tisa = PBXSourcesBuildPhase;")
    a("\t\t\tbuildActionMask = 2147483647;")
    a("\t\t\tfiles = (")
    for p in shared + host_files:
        key = str(p.relative_to(ROOT))
        a(f"\t\t\t\t{host_build[key]} /* {p.name} in Sources */,")
    a("\t\t\t);")
    a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a("\t\t};")

    a(f"\t\t{ids['filter_sources']} /* Sources */ = {{")
    a("\t\t\tisa = PBXSourcesBuildPhase;")
    a("\t\t\tbuildActionMask = 2147483647;")
    a("\t\t\tfiles = (")
    for p in shared + filter_files:
        key = str(p.relative_to(ROOT))
        a(f"\t\t\t\t{filter_build[key]} /* {p.name} in Sources */,")
    a("\t\t\t);")
    a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a("\t\t};")

    a(f"\t\t{ids['tests_sources']} /* Sources */ = {{")
    a("\t\t\tisa = PBXSourcesBuildPhase;")
    a("\t\t\tbuildActionMask = 2147483647;")
    a("\t\t\tfiles = (")
    for p in shared + test_files:
        key = str(p.relative_to(ROOT))
        a(f"\t\t\t\t{tests_build[key]} /* {p.name} in Sources */,")
    a("\t\t\t);")
    a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a("\t\t};")
    a("/* End PBXSourcesBuildPhase section */")
    a("")

    a("/* Begin PBXTargetDependency section */")
    a(f"\t\t{ids['dep']} /* PBXTargetDependency */ = {{")
    a("\t\t\tisa = PBXTargetDependency;")
    a(f"\t\t\ttarget = {ids['filter_target']} /* FlamewallFilter */;")
    a(f"\t\t\ttargetProxy = {ids['proxy']} /* PBXContainerItemProxy */;")
    a("\t\t};")
    a("/* End PBXTargetDependency section */")
    a("")

    # Build configs
    a("/* Begin XCBuildConfiguration section */")

    def project_cfg(cid: str, name: str) -> None:
        a(f"\t\t{cid} /* {name} */ = {{")
        a("\t\t\tisa = XCBuildConfiguration;")
        a("\t\t\tbuildSettings = {")
        a("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
        a("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
        a("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
        a("\t\t\t\tCOPY_PHASE_STRIP = NO;")
        a("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
        a("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
        a("\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;")
        a("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;")
        a("\t\t\t\tONLY_ACTIVE_ARCH = YES;" if name == "Debug" else "\t\t\t\tONLY_ACTIVE_ARCH = NO;")
        a("\t\t\t\tSDKROOT = macosx;")
        a("\t\t\t\tSWIFT_VERSION = 5.0;")
        if name == "Debug":
            a("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
            a("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;")
            a("\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (")
            a("\t\t\t\t\t\"DEBUG=1\",")
            a("\t\t\t\t\t\"$(inherited)\",")
            a("\t\t\t\t);")
        else:
            a("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
        a("\t\t\t};")
        a(f"\t\t\tname = {name};")
        a("\t\t};")

    project_cfg(ids["project_debug"], "Debug")
    project_cfg(ids["project_release"], "Release")

    def host_cfg(cid: str, name: str) -> None:
        a(f"\t\t{cid} /* {name} */ = {{")
        a("\t\t\tisa = XCBuildConfiguration;")
        a("\t\t\tbuildSettings = {")
        a("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
        # Both configs carry the full NE entitlements; only the signing style differs.
        # Debug is ad-hoc signed, which requires the amfi_get_out_of_my_way=1 boot-arg
        # for the entitlements to be honored (see docs/superpowers/specs).
        # Release uses automatic signing for a paid Developer team.
        if name == "Debug":
            a("\t\t\t\tCODE_SIGN_ENTITLEMENTS = Flamewall/Resources/Flamewall.entitlements;")
            a("\t\t\t\tCODE_SIGN_IDENTITY = \"-\";")
            a("\t\t\t\tCODE_SIGN_STYLE = Manual;")
            a("\t\t\t\tDEVELOPMENT_TEAM = \"\";")
        else:
            a("\t\t\t\tCODE_SIGN_ENTITLEMENTS = Flamewall/Resources/Flamewall.entitlements;")
            a("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        a("\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;")
        a("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        a("\t\t\t\tENABLE_HARDENED_RUNTIME = YES;")
        a("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
        a("\t\t\t\tINFOPLIST_FILE = Flamewall/Resources/Info.plist;")
        a("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
        a("\t\t\t\t\t\"$(inherited)\",")
        a("\t\t\t\t\t\"@executable_path/../Frameworks\",")
        a("\t\t\t\t);")
        a("\t\t\t\tMARKETING_VERSION = 1.0;")
        a("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.flamewall.app;")
        a("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        a("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
        a("\t\t\t\tSWIFT_VERSION = 5.0;")
        a("\t\t\t};")
        a(f"\t\t\tname = {name};")
        a("\t\t};")

    host_cfg(ids["host_debug"], "Debug")
    host_cfg(ids["host_release"], "Release")

    def filter_cfg(cid: str, name: str) -> None:
        a(f"\t\t{cid} /* {name} */ = {{")
        a("\t\t\tisa = XCBuildConfiguration;")
        a("\t\t\tbuildSettings = {")
        if name == "Debug":
            a("\t\t\t\tCODE_SIGN_ENTITLEMENTS = FlamewallFilter/FlamewallFilter.entitlements;")
            a("\t\t\t\tCODE_SIGN_IDENTITY = \"-\";")
            a("\t\t\t\tCODE_SIGN_STYLE = Manual;")
            a("\t\t\t\tDEVELOPMENT_TEAM = \"\";")
        else:
            a("\t\t\t\tCODE_SIGN_ENTITLEMENTS = FlamewallFilter/FlamewallFilter.entitlements;")
            a("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        a("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        a("\t\t\t\tENABLE_HARDENED_RUNTIME = YES;")
        a("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
        a("\t\t\t\tINFOPLIST_FILE = FlamewallFilter/Info.plist;")
        a("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
        a("\t\t\t\t\t\"$(inherited)\",")
        a("\t\t\t\t\t\"@executable_path/../Frameworks\",")
        a("\t\t\t\t);")
        a("\t\t\t\tMARKETING_VERSION = 1.0;")
        a("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.flamewall.app.filter;")
        a("\t\t\t\tPRODUCT_NAME = FlamewallFilter;")
        a("\t\t\t\tSKIP_INSTALL = YES;")
        a("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
        a("\t\t\t\tSWIFT_VERSION = 5.0;")
        a("\t\t\t};")
        a(f"\t\t\tname = {name};")
        a("\t\t};")

    filter_cfg(ids["filter_debug"], "Debug")
    filter_cfg(ids["filter_release"], "Release")

    def tests_cfg(cid: str, name: str) -> None:
        a(f"\t\t{cid} /* {name} */ = {{")
        a("\t\t\tisa = XCBuildConfiguration;")
        a("\t\t\tbuildSettings = {")
        a("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        a("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        a("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
        a("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;")
        a("\t\t\t\tMARKETING_VERSION = 1.0;")
        a("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.flamewall.app.tests;")
        a("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        a("\t\t\t\tSWIFT_VERSION = 5.0;")
        a("\t\t\t};")
        a(f"\t\t\tname = {name};")
        a("\t\t};")

    tests_cfg(ids["tests_debug"], "Debug")
    tests_cfg(ids["tests_release"], "Release")
    a("/* End XCBuildConfiguration section */")
    a("")

    a("/* Begin XCConfigurationList section */")
    for list_id, debug_id, release_id, label in [
        (ids["project_configs"], ids["project_debug"], ids["project_release"], "PBXProject \"Flamewall\""),
        (ids["host_configs"], ids["host_debug"], ids["host_release"], "PBXNativeTarget \"Flamewall\""),
        (ids["filter_configs"], ids["filter_debug"], ids["filter_release"], "PBXNativeTarget \"FlamewallFilter\""),
        (ids["tests_configs"], ids["tests_debug"], ids["tests_release"], "PBXNativeTarget \"FlamewallTests\""),
    ]:
        a(f"\t\t{list_id} /* Build configuration list for {label} */ = {{")
        a("\t\t\tisa = XCConfigurationList;")
        a("\t\t\tbuildConfigurations = (")
        a(f"\t\t\t\t{debug_id} /* Debug */,")
        a(f"\t\t\t\t{release_id} /* Release */,")
        a("\t\t\t);")
        a("\t\t\tdefaultConfigurationIsVisible = 0;")
        a("\t\t\tdefaultConfigurationName = Release;")
        a("\t\t};")
    a("/* End XCConfigurationList section */")
    a("\t};")
    a(f"\trootObject = {ids['project']} /* Project object */;")
    a("}")

    out_dir = ROOT / "Flamewall.xcodeproj"
    out_dir.mkdir(exist_ok=True)
    (out_dir / "project.pbxproj").write_text("\n".join(L) + "\n")

    scheme_dir = out_dir / "xcshareddata" / "xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{ids['host_target']}"
               BuildableName = "Flamewall.app"
               BlueprintName = "Flamewall"
               ReferencedContainer = "container:Flamewall.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "NO"
            buildForProfiling = "NO"
            buildForArchiving = "NO"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{ids['tests_target']}"
               BuildableName = "FlamewallTests.xctest"
               BlueprintName = "FlamewallTests"
               ReferencedContainer = "container:Flamewall.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{ids['tests_target']}"
               BuildableName = "FlamewallTests.xctest"
               BlueprintName = "FlamewallTests"
               ReferencedContainer = "container:Flamewall.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{ids['host_target']}"
            BuildableName = "Flamewall.app"
            BlueprintName = "Flamewall"
            ReferencedContainer = "container:Flamewall.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{ids['host_target']}"
            BuildableName = "Flamewall.app"
            BlueprintName = "Flamewall"
            ReferencedContainer = "container:Flamewall.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    (scheme_dir / "Flamewall.xcscheme").write_text(scheme)
    print(f"Wrote {out_dir / 'project.pbxproj'}")
    print(f"Host target: {ids['host_target']}")
    print(f"Filter target: {ids['filter_target']}")
    print(f"Tests target: {ids['tests_target']}")


if __name__ == "__main__":
    main()
