#!/bin/bash

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Переменные
CONFIG_FILE="project_config.yaml"
IOS_DIR="ios"
NOTIFICATIONS_DIR="${IOS_DIR}/notifications"
PBXPROJ="${IOS_DIR}/Runner.xcodeproj/project.pbxproj"

# Функция для чтения значения из конфига
read_config() {
    grep "^$1:" "$CONFIG_FILE" 2>/dev/null | sed "s/^$1:[[:space:]]*//" | sed 's/^"//' | sed 's/"$//'
}

# Чтение bundle_id из конфига
BUNDLE_ID=$(read_config "bundle_id")
NSE_SWIFT_PATH=$(read_config "nse_swift_path")
NSE_PLIST_PATH=$(read_config "nse_plist_path")

if [ -z "$BUNDLE_ID" ]; then
    echo -e "${RED}❌ bundle_id не указан в ${CONFIG_FILE}${NC}"
    exit 1
fi

# Суффикс Bundle ID расширения (по умолчанию .notifications —
# должен совпадать с Bundle ID расширения в App Store Connect).
NSE_BUNDLE_SUFFIX="${NSE_BUNDLE_SUFFIX:-.notifications}"
NSE_BUNDLE_ID="${BUNDLE_ID}${NSE_BUNDLE_SUFFIX}"
echo -e "${YELLOW}🔔 Добавление Notification Service Extension...${NC}"
echo "   NSE Bundle ID: $NSE_BUNDLE_ID"

# Создание директории
echo -e "${YELLOW}   Создание директории notifications...${NC}"
mkdir -p "$NOTIFICATIONS_DIR"

# Создание или копирование NotificationService.swift
echo -e "${YELLOW}   Создание NotificationService.swift...${NC}"
if [ -n "$NSE_SWIFT_PATH" ] && [ -f "$NSE_SWIFT_PATH" ]; then
    echo "   Копирование из: $NSE_SWIFT_PATH"
    cp "$NSE_SWIFT_PATH" "${NOTIFICATIONS_DIR}/NotificationService.swift"
else
    echo "   Создание стандартного файла"
    cat > "${NOTIFICATIONS_DIR}/NotificationService.swift" << 'SWIFT_EOF'
import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            // Modify the notification content here...
            bestAttemptContent.title = "\(bestAttemptContent.title)"
            
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
SWIFT_EOF
fi

# Создание или копирование Info.plist
echo -e "${YELLOW}   Создание Info.plist для NSE...${NC}"
if [ -n "$NSE_PLIST_PATH" ] && [ -f "$NSE_PLIST_PATH" ]; then
    echo "   Копирование из: $NSE_PLIST_PATH"
    cp "$NSE_PLIST_PATH" "${NOTIFICATIONS_DIR}/Info.plist"
else
    echo "   Создание стандартного файла"
    cat > "${NOTIFICATIONS_DIR}/Info.plist" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>notifications</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.usernotifications.service</string>
		<key>NSExtensionPrincipalClass</key>
		<string>$(PRODUCT_MODULE_NAME).NotificationService</string>
	</dict>
</dict>
</plist>
PLIST_EOF
fi

# Проверка, не добавлен ли уже NSE
if grep -q "notifications.appex" "$PBXPROJ"; then
    echo -e "${YELLOW}   ⚠️  Notification Service Extension уже существует${NC}"
    exit 0
fi

echo -e "${YELLOW}   Обновление project.pbxproj...${NC}"

# ID для различных элементов
NSE_FILE_REF_ID="NOTIF001000000000000001"
NSE_PLIST_REF_ID="NOTIF002000000000000001"
NSE_GROUP_ID="NOTIF003000000000000001"
NSE_PRODUCT_REF_ID="NOTIF004000000000000001"
NSE_TARGET_ID="NOTIF005000000000000001"
NSE_BUILD_FILE_ID="NOTIF006000000000000001"
NSE_SOURCES_ID="NOTIF007000000000000001"
NSE_FRAMEWORKS_ID="NOTIF008000000000000001"
NSE_RESOURCES_ID="NOTIF009000000000000001"
NSE_DEPENDENCY_ID="NOTIF010000000000000001"
NSE_CONTAINER_PROXY_ID="NOTIF011000000000000001"
NSE_COPY_FILES_ID="NOTIF012000000000000001"
NSE_COPY_BUILD_FILE_ID="NOTIF013000000000000001"
NSE_DEBUG_CONFIG_ID="NOTIF014000000000000001"
NSE_RELEASE_CONFIG_ID="NOTIF015000000000000001"
NSE_PROFILE_CONFIG_ID="NOTIF016000000000000001"
NSE_CONFIG_LIST_ID="NOTIF017000000000000001"

# PBXBuildFile section
sed -i '' "s|/\* End PBXBuildFile section \*/|		${NSE_BUILD_FILE_ID} /* NotificationService.swift in Sources */ = {isa = PBXBuildFile; fileRef = ${NSE_FILE_REF_ID} /* NotificationService.swift */; };\\
		${NSE_COPY_BUILD_FILE_ID} /* notifications.appex in Embed App Extensions */ = {isa = PBXBuildFile; fileRef = ${NSE_PRODUCT_REF_ID} /* notifications.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };\\
/* End PBXBuildFile section */|" "$PBXPROJ"

# PBXContainerItemProxy section
sed -i '' "s|/\* End PBXContainerItemProxy section \*/|		${NSE_CONTAINER_PROXY_ID} /* PBXContainerItemProxy */ = {\\
			isa = PBXContainerItemProxy;\\
			containerPortal = 97C146E61CF9000F007C117D /* Project object */;\\
			proxyType = 1;\\
			remoteGlobalIDString = ${NSE_TARGET_ID};\\
			remoteInfo = notifications;\\
		};\\
/* End PBXContainerItemProxy section */|" "$PBXPROJ"

# PBXCopyFilesBuildPhase section
sed -i '' "s|/\* End PBXCopyFilesBuildPhase section \*/|		${NSE_COPY_FILES_ID} /* Embed App Extensions */ = {\\
			isa = PBXCopyFilesBuildPhase;\\
			buildActionMask = 2147483647;\\
			dstPath = \"\";\\
			dstSubfolderSpec = 13;\\
			files = (\\
				${NSE_COPY_BUILD_FILE_ID} /* notifications.appex in Embed App Extensions */,\\
			);\\
			name = \"Embed App Extensions\";\\
			runOnlyForDeploymentPostprocessing = 0;\\
		};\\
/* End PBXCopyFilesBuildPhase section */|" "$PBXPROJ"

# PBXFileReference section
sed -i '' "s|/\* End PBXFileReference section \*/|		${NSE_FILE_REF_ID} /* NotificationService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NotificationService.swift; sourceTree = \"<group>\"; };\\
		${NSE_PLIST_REF_ID} /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; };\\
		${NSE_PRODUCT_REF_ID} /* notifications.appex */ = {isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = notifications.appex; sourceTree = BUILT_PRODUCTS_DIR; };\\
/* End PBXFileReference section */|" "$PBXPROJ"

# Add to Products group
sed -i '' "s|97C146EE1CF9000F007C117D /\* Runner.app \*/,|97C146EE1CF9000F007C117D /* Runner.app */,\\
				${NSE_PRODUCT_REF_ID} /* notifications.appex */,|" "$PBXPROJ"

# Add notifications group reference to main group
sed -i '' "s|331C8082294A63A400263BE5 /\* RunnerTests \*/,|${NSE_GROUP_ID} /* notifications */,\\
				331C8082294A63A400263BE5 /* RunnerTests */,|" "$PBXPROJ"

# PBXGroup section - add notifications group
sed -i '' "s|/\* End PBXGroup section \*/|		${NSE_GROUP_ID} /* notifications */ = {\\
			isa = PBXGroup;\\
			children = (\\
				${NSE_FILE_REF_ID} /* NotificationService.swift */,\\
				${NSE_PLIST_REF_ID} /* Info.plist */,\\
			);\\
			path = notifications;\\
			sourceTree = \"<group>\";\\
		};\\
/* End PBXGroup section */|" "$PBXPROJ"

# PBXNativeTarget section
sed -i '' "s|/\* End PBXNativeTarget section \*/|		${NSE_TARGET_ID} /* notifications */ = {\\
			isa = PBXNativeTarget;\\
			buildConfigurationList = ${NSE_CONFIG_LIST_ID} /* Build configuration list for PBXNativeTarget \"notifications\" */;\\
			buildPhases = (\\
				${NSE_SOURCES_ID} /* Sources */,\\
				${NSE_FRAMEWORKS_ID} /* Frameworks */,\\
				${NSE_RESOURCES_ID} /* Resources */,\\
			);\\
			buildRules = (\\
			);\\
			dependencies = (\\
			);\\
			name = notifications;\\
			productName = notifications;\\
			productReference = ${NSE_PRODUCT_REF_ID} /* notifications.appex */;\\
			productType = \"com.apple.product-type.app-extension\";\\
		};\\
/* End PBXNativeTarget section */|" "$PBXPROJ"

# Add target to project targets list
sed -i '' "s|97C146ED1CF9000F007C117D /\* Runner \*/,|97C146ED1CF9000F007C117D /* Runner */,\\
				${NSE_TARGET_ID} /* notifications */,|" "$PBXPROJ"

# Add target attributes
sed -i '' "s|97C146ED1CF9000F007C117D = {|${NSE_TARGET_ID} = {\\
						CreatedOnToolsVersion = 15.0;\\
					};\\
					97C146ED1CF9000F007C117D = {|" "$PBXPROJ"

# Add Embed App Extensions build phase to Runner target
# Find the Runner target section and add the build phase BEFORE Thin Binary (not after)
# This is important to avoid circular dependency issues
sed -i '' 's|3B06AD1E1E4923F5004D2608 /\* Thin Binary \*/,|'"${NSE_COPY_FILES_ID}"' /* Embed App Extensions */,\
				3B06AD1E1E4923F5004D2608 /* Thin Binary */,|' "$PBXPROJ"

# Add dependency to Runner target
# We need to find the Runner target (97C146ED1CF9000F007C117D) and add dependency there
# The Runner target block starts with "97C146ED1CF9000F007C117D /* Runner */ = {"
# We use a more specific pattern to find the correct dependencies = ( block

# Create a temp file for the complex sed operation
TEMP_FILE=$(mktemp)
awk '
/97C146ED1CF9000F007C117D \/\* Runner \*\/ = \{/ { in_runner = 1 }
in_runner && /dependencies = \(/ && !added {
    print
    print "\t\t\t\t'"${NSE_DEPENDENCY_ID}"' /* PBXTargetDependency */,"
    added = 1
    next
}
/\};/ && in_runner { in_runner = 0 }
{ print }
' "$PBXPROJ" > "$TEMP_FILE"
mv "$TEMP_FILE" "$PBXPROJ"

# PBXSourcesBuildPhase section
sed -i '' "s|/\* End PBXSourcesBuildPhase section \*/|		${NSE_SOURCES_ID} /* Sources */ = {\\
			isa = PBXSourcesBuildPhase;\\
			buildActionMask = 2147483647;\\
			files = (\\
				${NSE_BUILD_FILE_ID} /* NotificationService.swift in Sources */,\\
			);\\
			runOnlyForDeploymentPostprocessing = 0;\\
		};\\
/* End PBXSourcesBuildPhase section */|" "$PBXPROJ"

# PBXFrameworksBuildPhase section
sed -i '' "s|/\* End PBXFrameworksBuildPhase section \*/|		${NSE_FRAMEWORKS_ID} /* Frameworks */ = {\\
			isa = PBXFrameworksBuildPhase;\\
			buildActionMask = 2147483647;\\
			files = (\\
			);\\
			runOnlyForDeploymentPostprocessing = 0;\\
		};\\
/* End PBXFrameworksBuildPhase section */|" "$PBXPROJ"

# PBXResourcesBuildPhase section
sed -i '' "s|/\* End PBXResourcesBuildPhase section \*/|		${NSE_RESOURCES_ID} /* Resources */ = {\\
			isa = PBXResourcesBuildPhase;\\
			buildActionMask = 2147483647;\\
			files = (\\
			);\\
			runOnlyForDeploymentPostprocessing = 0;\\
		};\\
/* End PBXResourcesBuildPhase section */|" "$PBXPROJ"

# PBXTargetDependency section
sed -i '' "s|/\* End PBXTargetDependency section \*/|		${NSE_DEPENDENCY_ID} /* PBXTargetDependency */ = {\\
			isa = PBXTargetDependency;\\
			target = ${NSE_TARGET_ID} /* notifications */;\\
			targetProxy = ${NSE_CONTAINER_PROXY_ID} /* PBXContainerItemProxy */;\\
		};\\
/* End PBXTargetDependency section */|" "$PBXPROJ"

# XCBuildConfiguration section - Debug, Release, Profile
sed -i '' "s|/\* End XCBuildConfiguration section \*/|		${NSE_DEBUG_CONFIG_ID} /* Debug */ = {\\
			isa = XCBuildConfiguration;\\
			buildSettings = {\\
				CLANG_ANALYZER_NONNULL = YES;\\
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;\\
				CLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";\\
				CLANG_ENABLE_OBJC_WEAK = YES;\\
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;\\
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;\\
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;\\
				CODE_SIGN_STYLE = Automatic;\\
				CURRENT_PROJECT_VERSION = 1;\\
				DEBUG_INFORMATION_FORMAT = dwarf;\\
				GCC_C_LANGUAGE_STANDARD = gnu17;\\
				GENERATE_INFOPLIST_FILE = YES;\\
				INFOPLIST_FILE = notifications/Info.plist;\\
				INFOPLIST_KEY_CFBundleDisplayName = notifications;\\
				INFOPLIST_KEY_NSHumanReadableCopyright = \"\";\\
				IPHONEOS_DEPLOYMENT_TARGET = 15.0;\\
				LD_RUNPATH_SEARCH_PATHS = (\\
					\"\$(inherited)\",\\
					\"@executable_path/Frameworks\",\\
					\"@executable_path/../../Frameworks\",\\
				);\\
				MARKETING_VERSION = 3.0;\\
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;\\
				MTL_FAST_MATH = YES;\\
				PRODUCT_BUNDLE_IDENTIFIER = \"${NSE_BUNDLE_ID}\";\\
				PRODUCT_NAME = \"\$(TARGET_NAME)\";\\
				SKIP_INSTALL = YES;\\
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG \$(inherited)\";\\
				SWIFT_EMIT_LOC_STRINGS = YES;\\
				SWIFT_OPTIMIZATION_LEVEL = \"-Onone\";\\
				SWIFT_VERSION = 5.0;\\
				TARGETED_DEVICE_FAMILY = \"1,2\";\\
			};\\
			name = Debug;\\
		};\\
		${NSE_RELEASE_CONFIG_ID} /* Release */ = {\\
			isa = XCBuildConfiguration;\\
			buildSettings = {\\
				CLANG_ANALYZER_NONNULL = YES;\\
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;\\
				CLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";\\
				CLANG_ENABLE_OBJC_WEAK = YES;\\
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;\\
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;\\
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;\\
				CODE_SIGN_STYLE = Automatic;\\
				COPY_PHASE_STRIP = NO;\\
				CURRENT_PROJECT_VERSION = 1;\\
				DEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";\\
				GCC_C_LANGUAGE_STANDARD = gnu17;\\
				GENERATE_INFOPLIST_FILE = YES;\\
				INFOPLIST_FILE = notifications/Info.plist;\\
				INFOPLIST_KEY_CFBundleDisplayName = notifications;\\
				INFOPLIST_KEY_NSHumanReadableCopyright = \"\";\\
			IPHONEOS_DEPLOYMENT_TARGET = 15.0;\\
				LD_RUNPATH_SEARCH_PATHS = (\\
					\"\$(inherited)\",\\
					\"@executable_path/Frameworks\",\\
					\"@executable_path/../../Frameworks\",\\
				);\\
				MARKETING_VERSION = 3.0;\\
				MTL_FAST_MATH = YES;\\
				PRODUCT_BUNDLE_IDENTIFIER = \"${NSE_BUNDLE_ID}\";\\
				PRODUCT_NAME = \"\$(TARGET_NAME)\";\\
				SKIP_INSTALL = YES;\\
				SWIFT_EMIT_LOC_STRINGS = YES;\\
				SWIFT_VERSION = 5.0;\\
				TARGETED_DEVICE_FAMILY = \"1,2\";\\
			};\\
			name = Release;\\
		};\\
		${NSE_PROFILE_CONFIG_ID} /* Profile */ = {\\
			isa = XCBuildConfiguration;\\
			buildSettings = {\\
				CLANG_ANALYZER_NONNULL = YES;\\
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;\\
				CLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";\\
				CLANG_ENABLE_OBJC_WEAK = YES;\\
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;\\
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;\\
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;\\
				CODE_SIGN_STYLE = Automatic;\\
				COPY_PHASE_STRIP = NO;\\
				CURRENT_PROJECT_VERSION = 1;\\
				DEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";\\
				GCC_C_LANGUAGE_STANDARD = gnu17;\\
				GENERATE_INFOPLIST_FILE = YES;\\
				INFOPLIST_FILE = notifications/Info.plist;\\
				INFOPLIST_KEY_CFBundleDisplayName = notifications;\\
				INFOPLIST_KEY_NSHumanReadableCopyright = \"\";\\
				IPHONEOS_DEPLOYMENT_TARGET = 15.0;\\
				LD_RUNPATH_SEARCH_PATHS = (\\
					\"\$(inherited)\",\\
					\"@executable_path/Frameworks\",\\
					\"@executable_path/../../Frameworks\",\\
				);\\
				MARKETING_VERSION = 3.0;\\
				MTL_FAST_MATH = YES;\\
				PRODUCT_BUNDLE_IDENTIFIER = \"${NSE_BUNDLE_ID}\";\\
				PRODUCT_NAME = \"\$(TARGET_NAME)\";\\
				SKIP_INSTALL = YES;\\
				SWIFT_EMIT_LOC_STRINGS = YES;\\
				SWIFT_VERSION = 5.0;\\
				TARGETED_DEVICE_FAMILY = \"1,2\";\\
			};\\
			name = Profile;\\
		};\\
/* End XCBuildConfiguration section */|" "$PBXPROJ"

# XCConfigurationList section
sed -i '' "s|/\* End XCConfigurationList section \*/|		${NSE_CONFIG_LIST_ID} /* Build configuration list for PBXNativeTarget \"notifications\" */ = {\\
			isa = XCConfigurationList;\\
			buildConfigurations = (\\
				${NSE_DEBUG_CONFIG_ID} /* Debug */,\\
				${NSE_RELEASE_CONFIG_ID} /* Release */,\\
				${NSE_PROFILE_CONFIG_ID} /* Profile */,\\
			);\\
			defaultConfigurationIsVisible = 0;\\
			defaultConfigurationName = Release;\\
		};\\
/* End XCConfigurationList section */|" "$PBXPROJ"

echo -e "${GREEN}   ✓ Notification Service Extension добавлен${NC}"
echo -e "${GREEN}✅ NSE настройка завершена!${NC}"
