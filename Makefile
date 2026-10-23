# Makefile для настройки iOS/Flutter проекта
# Использование: make setup

# Переменные
CONFIG_FILE := project_config.yaml
IOS_DIR := ios
RUNNER_DIR := $(IOS_DIR)/Runner
PBXPROJ := $(IOS_DIR)/Runner.xcodeproj/project.pbxproj
INFO_PLIST := $(RUNNER_DIR)/Info.plist
ASSETS_DIR := $(RUNNER_DIR)/Assets.xcassets/AppIcon.appiconset

# Суффикс Bundle ID для Notification Service Extension.
# Должен совпадать с Bundle ID расширения, зарегистрированным в App Store Connect
# (полный Bundle ID расширения = bundle_id из project_config.yaml + этот суффикс).
NSE_BUNDLE_SUFFIX := .notifications

# Цвета для вывода
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Проверка наличия необходимых утилит
.PHONY: check-deps
check-deps:
	@command -v sips >/dev/null 2>&1 || { echo "$(RED)sips не найден. Установите ImageMagick или используйте macOS.$(NC)"; exit 1; }
	@command -v plutil >/dev/null 2>&1 || { echo "$(RED)plutil не найден.$(NC)"; exit 1; }
	@command -v sed >/dev/null 2>&1 || { echo "$(RED)sed не найден.$(NC)"; exit 1; }

# Чтение конфигурации из YAML файла
define read_config
$(shell grep "^$(1):" $(CONFIG_FILE) 2>/dev/null | sed 's/^$(1):[[:space:]]*//' | sed 's/^"//' | sed 's/"$$//')
endef

# Основная цель
.PHONY: setup-clear
setup-clear: check-deps setup-name setup-icon  setup-bundle-id 
	@echo "$(GREEN)✅ Настройка проекта завершена!$(NC)"

# Основная цель
.PHONY: setup-core
setup-core: check-deps setup-name setup-icon setup-notifications setup-bundle-id setup-podfile setup-capabilities setup-privacy setup-notifications-frameworks
	@echo "$(GREEN)✅ Настройка проекта завершена!$(NC)"

# Настройка названия приложения
.PHONY: setup-name
setup-name:
	@echo "$(YELLOW)📝 Настройка названия приложения...$(NC)"
	@APP_NAME="$(call read_config,app_name)"; \
	if [ -z "$$APP_NAME" ]; then \
		echo "$(RED)❌ app_name не указан в $(CONFIG_FILE)$(NC)"; \
		exit 1; \
	fi; \
	case "$$APP_NAME" in \
		*:*) echo "$(RED)❌ app_name не должен содержать символ ':'$(NC)"; exit 1;; \
	esac; \
	echo "   Название: $$APP_NAME"; \
	plutil -replace CFBundleDisplayName -string "$$APP_NAME" $(INFO_PLIST); \
	plutil -replace CFBundleName -string "$$APP_NAME" $(INFO_PLIST); \
	echo "$(GREEN)   ✓ Название обновлено в Info.plist$(NC)"

# Настройка Bundle ID
.PHONY: setup-bundle-id
setup-bundle-id:
	@echo "$(YELLOW)🔧 Настройка Bundle ID...$(NC)"
	@BUNDLE_ID="$(call read_config,bundle_id)"; \
	if [ -z "$$BUNDLE_ID" ]; then \
		echo "$(RED)❌ bundle_id не указан в $(CONFIG_FILE)$(NC)"; \
		exit 1; \
	fi; \
	echo "   Bundle ID: $$BUNDLE_ID"; \
	OLD_BUNDLE_ID=$$(grep 'PRODUCT_BUNDLE_IDENTIFIER' $(PBXPROJ) | grep -vF '$(NSE_BUNDLE_SUFFIX)' | grep -v '\.RunnerTests' | head -1 | sed 's/.*= \(.*\);.*/\1/'); \
	if [ -z "$$OLD_BUNDLE_ID" ]; then \
		echo "$(RED)❌ Не удалось определить старый Bundle ID$(NC)"; \
		exit 1; \
	fi; \
	echo "   Старый Bundle ID: $$OLD_BUNDLE_ID"; \
	sed -i '' "s|PRODUCT_BUNDLE_IDENTIFIER = $$OLD_BUNDLE_ID;|PRODUCT_BUNDLE_IDENTIFIER = $$BUNDLE_ID;|g" $(PBXPROJ); \
	echo "$(GREEN)   ✓ Bundle ID обновлен в project.pbxproj$(NC)"; \
	NSE_BUNDLE_ID="$$BUNDLE_ID$(NSE_BUNDLE_SUFFIX)"; \
	if grep -q 'PRODUCT_BUNDLE_IDENTIFIER = "\{0,1\}[^;]*\.notifications\{0,1\}"\{0,1\};' $(PBXPROJ); then \
		echo "   NSE Bundle ID: $$NSE_BUNDLE_ID"; \
		sed -i '' -E "s|PRODUCT_BUNDLE_IDENTIFIER = \"?[^\";]*\.notifications?\"?;|PRODUCT_BUNDLE_IDENTIFIER = $$NSE_BUNDLE_ID;|g" $(PBXPROJ); \
		echo "$(GREEN)   ✓ NSE Bundle ID обновлен в project.pbxproj$(NC)"; \
	else \
		echo "$(YELLOW)   ⚠️  Notification Service Extension не найден в project.pbxproj, пропускаем...$(NC)"; \
	fi

# Настройка иконки
.PHONY: setup-icon
setup-icon:
	@echo "$(YELLOW)🎨 Настройка иконки приложения...$(NC)"
	@ICON_PATH="$(call read_config,icon_path)"; \
	if [ -z "$$ICON_PATH" ]; then \
		echo "$(YELLOW)   ⚠️  icon_path не указан, пропускаем...$(NC)"; \
		exit 0; \
	fi; \
	if [ ! -f "$$ICON_PATH" ]; then \
		echo "$(RED)❌ Файл иконки не найден: $$ICON_PATH$(NC)"; \
		exit 1; \
	fi; \
	echo "   Исходный файл: $$ICON_PATH"; \
	mkdir -p $(ASSETS_DIR); \
	TMPDIR=$$(mktemp -d); \
	trap 'rm -rf "$$TMPDIR"' EXIT; \
	sips -s format jpeg -s formatOptions 100 "$$ICON_PATH" --out "$$TMPDIR/icon.jpg" >/dev/null 2>&1; \
	sips -s format png "$$TMPDIR/icon.jpg" --out "$$TMPDIR/icon.png" >/dev/null 2>&1; \
	FLAT_ICON="$$TMPDIR/icon.png"; \
	for size in 20 29 40 57 58 60 76 80 87 114 120 152 167 180 1024; do \
		echo "   Создание иконки $${size}x$${size}..."; \
		sips -s format png -z $$size $$size "$$FLAT_ICON" --out "$(ASSETS_DIR)/$$size.png" >/dev/null 2>&1; \
	done; \
	echo '{"images":[{"size":"60x60","expected-size":"180","filename":"180.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"iphone","scale":"3x"},{"size":"40x40","expected-size":"80","filename":"80.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"iphone","scale":"2x"},{"size":"40x40","expected-size":"120","filename":"120.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"iphone","scale":"3x"},{"size":"60x60","expected-size":"120","filename":"120.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"iphone","scale":"2x"},{"size":"57x57","expected-size":"57","filename":"57.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"iphone","scale":"1x"},{"size":"29x29","expected-size":"58","filename":"58.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"iphone","scale":"2x"},{"size":"29x29","expected-size":"29","filename":"29.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"iphone","scale":"1x"},{"size":"29x29","expected-size":"87","filename":"87.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"iphone","scale":"3x"},{"size":"57x57","expected-size":"114","filename":"114.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"iphone","scale":"2x"},{"size":"20x20","expected-size":"40","filename":"40.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"iphone","scale":"2x"},{"size":"20x20","expected-size":"60","filename":"60.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"iphone","scale":"3x"},{"size":"1024x1024","filename":"1024.png","expected-size":"1024","idiom":"ios-marketing","folder":"Assets.xcassets/AppIcon.appiconset/","scale":"1x"},{"size":"20x20","expected-size":"20","filename":"20.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"ipad","scale":"1x"},{"size":"20x20","expected-size":"40","filename":"40.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"ipad","scale":"2x"},{"size":"29x29","expected-size":"29","filename":"29.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"ipad","scale":"1x"},{"size":"29x29","expected-size":"58","filename":"58.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"ipad","scale":"2x"},{"size":"40x40","expected-size":"40","filename":"40.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"ipad","scale":"1x"},{"size":"40x40","expected-size":"80","filename":"80.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"ipad","scale":"2x"},{"size":"76x76","expected-size":"76","filename":"76.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"ipad","scale":"1x"},{"size":"76x76","expected-size":"152","filename":"152.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"ipad","scale":"2x"},{"size":"83.5x83.5","expected-size":"167","filename":"167.png","folder":"Assets.xcassets/AppIcon.appiconset/","idiom":"ipad","scale":"2x"}]}' > "$(ASSETS_DIR)/Contents.json"; \
	echo "$(GREEN)   ✓ Иконки созданы и сохранены$(NC)"

# Настройка версии приложения
.PHONY: setup-version
setup-version:
	@echo "$(YELLOW)📌 Настройка версии приложения...$(NC)"
	@APP_VERSION="$(call read_config,app_version)"; \
	BUILD_NUMBER="$(call read_config,build_number)"; \
	if [ -n "$$APP_VERSION" ]; then \
		echo "   Версия: $$APP_VERSION"; \
		plutil -replace CFBundleShortVersionString -string "$$APP_VERSION" $(INFO_PLIST); \
	fi; \
	if [ -n "$$BUILD_NUMBER" ]; then \
		echo "   Номер сборки: $$BUILD_NUMBER"; \
		plutil -replace CFBundleVersion -string "$$BUILD_NUMBER" $(INFO_PLIST); \
	fi; \
	echo "$(GREEN)   ✓ Версия обновлена$(NC)"

# Полная настройка включая версию
.PHONY: setup-all
setup-all: setup setup-version
	@echo "$(GREEN)✅ Полная настройка проекта завершена!$(NC)"

# Показать текущую конфигурацию проекта
.PHONY: show-config
show-config:
	@echo "$(YELLOW)📋 Текущая конфигурация проекта:$(NC)"
	@echo ""
	@echo "Info.plist:"
	@echo "   Display Name: $$(plutil -extract CFBundleDisplayName raw $(INFO_PLIST) 2>/dev/null || echo 'не найдено')"
	@echo "   Bundle Name: $$(plutil -extract CFBundleName raw $(INFO_PLIST) 2>/dev/null || echo 'не найдено')"
	@echo "   Version: $$(plutil -extract CFBundleShortVersionString raw $(INFO_PLIST) 2>/dev/null || echo 'не найдено')"
	@echo "   Build: $$(plutil -extract CFBundleVersion raw $(INFO_PLIST) 2>/dev/null || echo 'не найдено')"
	@echo ""
	@echo "project.pbxproj:"
	@echo "   Bundle ID: $$(grep 'PRODUCT_BUNDLE_IDENTIFIER' $(PBXPROJ) | grep -vF '$(NSE_BUNDLE_SUFFIX)' | grep -v '\.RunnerTests' | head -1 | sed 's/.*PRODUCT_BUNDLE_IDENTIFIER = "\{0,1\}\([^";]*\)"\{0,1\};.*/\1/')"
	@echo "   NSE Bundle ID: $$(grep 'PRODUCT_BUNDLE_IDENTIFIER' $(PBXPROJ) | grep -F '$(NSE_BUNDLE_SUFFIX)' | head -1 | sed 's/.*PRODUCT_BUNDLE_IDENTIFIER = "\{0,1\}\([^";]*\)"\{0,1\};.*/\1/')"

# Показать конфигурацию из файла
.PHONY: show-yaml-config
show-yaml-config:
	@echo "$(YELLOW)📄 Конфигурация из $(CONFIG_FILE):$(NC)"
	@echo ""
	@cat $(CONFIG_FILE)

# Очистка сгенерированных иконок
.PHONY: clean-icons
clean-icons:
	@echo "$(YELLOW)🧹 Удаление сгенерированных иконок...$(NC)"
	@rm -f $(ASSETS_DIR)/*.png
	@echo "$(GREEN)   ✓ Иконки удалены$(NC)"

# Резервное копирование важных файлов
.PHONY: backup
backup:
	@echo "$(YELLOW)💾 Создание резервной копии...$(NC)"
	@TIMESTAMP=$$(date +%Y%m%d_%H%M%S); \
	mkdir -p backups/$$TIMESTAMP; \
	cp $(INFO_PLIST) backups/$$TIMESTAMP/Info.plist; \
	cp $(PBXPROJ) backups/$$TIMESTAMP/project.pbxproj; \
	cp -r $(ASSETS_DIR) backups/$$TIMESTAMP/AppIcon.appiconset; \
	echo "$(GREEN)   ✓ Резервная копия создана в backups/$$TIMESTAMP$(NC)"

# Восстановление из резервной копии
.PHONY: restore
restore:
	@echo "$(YELLOW)📂 Доступные резервные копии:$(NC)"
	@ls -la backups/ 2>/dev/null || echo "   Резервные копии не найдены"
	@echo ""
	@echo "Для восстановления выполните:"
	@echo "   cp backups/<TIMESTAMP>/Info.plist $(INFO_PLIST)"
	@echo "   cp backups/<TIMESTAMP>/project.pbxproj $(PBXPROJ)"

# Podfile
PODFILE := $(IOS_DIR)/Podfile

.PHONY: setup-podfile
setup-podfile:
	@echo "$(YELLOW)📦 Настройка Podfile...$(NC)"
	@PODFILE_PATH=$$(grep "^podfile_path:" $(CONFIG_FILE) 2>/dev/null | sed 's/^podfile_path:[[:space:]]*//' | sed 's/^"//' | sed 's/"$$//'); \
	if [ -z "$$PODFILE_PATH" ]; then \
		echo "$(RED)❌ podfile_path не указан в $(CONFIG_FILE)$(NC)"; \
		exit 1; \
	fi; \
	if [ ! -f "$$PODFILE_PATH" ]; then \
		echo "$(RED)❌ Файл не найден: $$PODFILE_PATH$(NC)"; \
		exit 1; \
	fi; \
	echo "   Источник: $$PODFILE_PATH"; \
	cp "$$PODFILE_PATH" $(PODFILE); \
	echo "$(GREEN)   ✓ Podfile обновлен$(NC)"; \
	echo "$(YELLOW)   Удаление устаревшего Podfile.lock...$(NC)"; \
	rm -f $(IOS_DIR)/Podfile.lock; \
	echo "$(YELLOW)   Запуск pod install...$(NC)"; \
	cd $(IOS_DIR) && pod install --repo-update; \
	echo "$(GREEN)✅ Настройка Podfile завершена!$(NC)"

# Notification Service Extension
NOTIFICATIONS_DIR := $(IOS_DIR)/notifications
NOTIFICATIONS_PLIST := $(NOTIFICATIONS_DIR)/Info.plist

.PHONY: setup-notifications
setup-notifications:
	@chmod +x scripts/setup_notifications.sh && NSE_BUNDLE_SUFFIX="$(NSE_BUNDLE_SUFFIX)" ./scripts/setup_notifications.sh

# Обновление файлов Notification Service Extension
.PHONY: update-notifications
update-notifications:
	@echo "$(YELLOW)🔄 Обновление файлов Notification Service Extension...$(NC)"
	@if [ ! -d "$(NOTIFICATIONS_DIR)" ]; then \
		echo "$(RED)❌ Notification Service Extension не найден. Сначала выполните make setup-notifications$(NC)"; \
		exit 1; \
	fi; \
	NSE_SWIFT_PATH=$$(grep "^nse_swift_path:" $(CONFIG_FILE) 2>/dev/null | sed 's/^nse_swift_path:[[:space:]]*//' | sed 's/^"//' | sed 's/"$$//'); \
	NSE_PLIST_PATH=$$(grep "^nse_plist_path:" $(CONFIG_FILE) 2>/dev/null | sed 's/^nse_plist_path:[[:space:]]*//' | sed 's/^"//' | sed 's/"$$//'); \
	if [ -n "$$NSE_SWIFT_PATH" ] && [ -f "$$NSE_SWIFT_PATH" ]; then \
		echo "   Копирование NotificationService.swift из: $$NSE_SWIFT_PATH"; \
		cp "$$NSE_SWIFT_PATH" $(NOTIFICATIONS_DIR)/NotificationService.swift; \
		echo "$(GREEN)   ✓ NotificationService.swift обновлен$(NC)"; \
	else \
		echo "$(YELLOW)   ⚠️  nse_swift_path не указан или файл не найден$(NC)"; \
	fi; \
	if [ -n "$$NSE_PLIST_PATH" ] && [ -f "$$NSE_PLIST_PATH" ]; then \
		echo "   Копирование Info.plist из: $$NSE_PLIST_PATH"; \
		cp "$$NSE_PLIST_PATH" $(NOTIFICATIONS_DIR)/Info.plist; \
		echo "$(GREEN)   ✓ Info.plist обновлен$(NC)"; \
	else \
		echo "$(YELLOW)   ⚠️  nse_plist_path не указан или файл не найден$(NC)"; \
	fi; \
	echo "$(GREEN)✅ Обновление завершено$(NC)"

# Удаление Notification Service Extension
.PHONY: remove-notifications
remove-notifications:
	@echo "$(YELLOW)🗑️  Удаление Notification Service Extension...$(NC)"
	@if [ -d "$(NOTIFICATIONS_DIR)" ]; then \
		rm -rf $(NOTIFICATIONS_DIR); \
		echo "$(GREEN)   ✓ Директория notifications удалена$(NC)"; \
	else \
		echo "$(YELLOW)   ⚠️  Директория notifications не найдена$(NC)"; \
	fi
	@echo "$(YELLOW)   ⚠️  Для полного удаления NSE из project.pbxproj рекомендуется восстановить резервную копию$(NC)"
	@echo "$(GREEN)✅ Удаление завершено$(NC)"

# Добавление фреймворков в notifications target (Do not Embed)
# Добавляет: FirebaseMessaging.framework, FirebaseCore.framework, UserNotifications.framework
.PHONY: setup-notifications-frameworks
setup-notifications-frameworks:
	@echo "$(YELLOW)🔗 Добавление фреймворков в notifications target...$(NC)"
	@chmod +x scripts/add_notifications_frameworks.rb && ruby scripts/add_notifications_frameworks.rb

# Настройка Push Notifications capability и Background Modes
# Добавляет:
# - Push Notifications capability для Runner и notifications targets
# - Background Modes (Remote Notifications и Background fetch) в Runner
.PHONY: setup-capabilities 
setup-capabilities:
	@echo "$(YELLOW)🔐 Настройка capabilities...$(NC)"
	@chmod +x scripts/setup_capabilities.rb && ruby scripts/setup_capabilities.rb

# Переключение aps-environment между development и production
.PHONY: set-aps-development
set-aps-development:
	@echo "$(YELLOW)🔧 Установка aps-environment = development...$(NC)"
	@if [ -f "$(RUNNER_DIR)/Runner.entitlements" ]; then \
		plutil -replace aps-environment -string "development" $(RUNNER_DIR)/Runner.entitlements; \
		echo "$(GREEN)   ✓ Runner.entitlements обновлен$(NC)"; \
	else \
		echo "$(RED)   ❌ Runner.entitlements не найден$(NC)"; \
	fi
	@if [ -f "$(IOS_DIR)/notifications/notifications.entitlements" ]; then \
		plutil -replace aps-environment -string "development" $(IOS_DIR)/notifications/notifications.entitlements; \
		echo "$(GREEN)   ✓ notifications.entitlements обновлен$(NC)"; \
	fi
	@echo "$(GREEN)✅ aps-environment установлен в development$(NC)"

.PHONY: set-aps-production
set-aps-production:
	@echo "$(YELLOW)🔧 Установка aps-environment = production...$(NC)"
	@if [ -f "$(RUNNER_DIR)/Runner.entitlements" ]; then \
		plutil -replace aps-environment -string "production" $(RUNNER_DIR)/Runner.entitlements; \
		echo "$(GREEN)   ✓ Runner.entitlements обновлен$(NC)"; \
	else \
		echo "$(RED)   ❌ Runner.entitlements не найден$(NC)"; \
	fi
	@if [ -f "$(IOS_DIR)/notifications/notifications.entitlements" ]; then \
		plutil -replace aps-environment -string "production" $(IOS_DIR)/notifications/notifications.entitlements; \
		echo "$(GREEN)   ✓ notifications.entitlements обновлен$(NC)"; \
	fi
	@echo "$(GREEN)✅ aps-environment установлен в production$(NC)"

# Настройка Privacy описаний и App Transport Security Settings
# Добавляет:
# - NSUserTrackingUsageDescription (Privacy - Tracking Usage Description)
# - NSPhotoLibraryUsageDescription (Privacy - Photo Library Usage Description)
# - NSMicrophoneUsageDescription (Privacy - Microphone Usage Description)
# - NSCameraUsageDescription (Privacy - Camera Usage Description)
# - NSSpeechRecognitionUsageDescription (Privacy - Speech Recognition Usage Description)
# - NSAppTransportSecurity (App Transport Security Settings)
.PHONY: setup-privacy 
setup-privacy:
	@echo "$(YELLOW)🔒 Настройка Privacy описаний и App Transport Security...$(NC)"
	@echo "   Добавление NSPhotoLibraryUsageDescription..."
	@plutil -replace NSPhotoLibraryUsageDescription -string "Allows photo library access." $(INFO_PLIST)
	@echo "$(GREEN)   ✓ Privacy - Photo Library Usage Description добавлен$(NC)"
	@echo "   Добавление NSMicrophoneUsageDescription..."
	@plutil -replace NSMicrophoneUsageDescription -string "Allows microphone access." $(INFO_PLIST)
	@echo "$(GREEN)   ✓ Privacy - Microphone Usage Description добавлен$(NC)"
	@echo "   Добавление NSCameraUsageDescription..."
	@plutil -replace NSCameraUsageDescription -string "Allows camera access." $(INFO_PLIST)
	@echo "$(GREEN)   ✓ Privacy - Camera Usage Description добавлен$(NC)"
	@echo "   Добавление NSSpeechRecognitionUsageDescription..."
	@plutil -replace NSSpeechRecognitionUsageDescription -string "Allows speech recognition." $(INFO_PLIST)
	@echo "$(GREEN)   ✓ Privacy - Speech Recognition Usage Description добавлен$(NC)"
	@echo "   Добавление NSAppTransportSecurity..."
	@plutil -replace NSAppTransportSecurity -json '{"NSAllowsArbitraryLoads":true,"NSAllowsLocalNetworking":true,"NSAllowsArbitraryLoadsInWebContent":true,"NSAllowsArbitraryLoadsForMedia":true}' $(INFO_PLIST)
	@echo "$(GREEN)   ✓ App Transport Security Settings добавлен$(NC)"
	@echo "$(GREEN)✅ Privacy настройки добавлены в Info.plist$(NC)"

# Помощь
.PHONY: help
help:
	@echo "$(GREEN)Доступные команды:$(NC)"
	@echo ""
	@echo "  $(YELLOW)make setup$(NC)          - Настроить название, bundle ID и иконку"
	@echo "  $(YELLOW)make setup-all$(NC)      - Полная настройка включая версию"
	@echo "  $(YELLOW)make setup-name$(NC)     - Настроить только название приложения"
	@echo "  $(YELLOW)make setup-bundle-id$(NC) - Настроить только Bundle ID"
	@echo "  $(YELLOW)make setup-icon$(NC)     - Настроить только иконку"
	@echo "  $(YELLOW)make setup-version$(NC)  - Настроить версию и номер сборки"
	@echo "  $(YELLOW)make setup-podfile$(NC)  - Заменить Podfile из шаблона"
	@echo ""
	@echo "  $(YELLOW)make setup-notifications$(NC)  - Добавить Notification Service Extension"
	@echo "  $(YELLOW)make setup-notifications-frameworks$(NC) - Добавить фреймворки в notifications target"
	@echo "  $(YELLOW)make update-notifications$(NC) - Обновить файлы NSE из путей в конфиге"
	@echo "  $(YELLOW)make remove-notifications$(NC) - Удалить Notification Service Extension"
	@echo ""
	@echo "  $(YELLOW)make setup-capabilities$(NC) - Добавить Push Notifications и Background Modes"
	@echo "  $(YELLOW)make set-aps-development$(NC) - Установить aps-environment = development"
	@echo "  $(YELLOW)make set-aps-production$(NC)  - Установить aps-environment = production"
	@echo "  $(YELLOW)make setup-privacy$(NC)     - Добавить Privacy описания и App Transport Security"
	@echo ""
	@echo "  $(YELLOW)make show-config$(NC)    - Показать текущую конфигурацию проекта"
	@echo "  $(YELLOW)make show-yaml-config$(NC) - Показать конфигурацию из YAML файла"
	@echo ""
	@echo "  $(YELLOW)make backup$(NC)         - Создать резервную копию"
	@echo "  $(YELLOW)make restore$(NC)        - Информация о восстановлении"
	@echo "  $(YELLOW)make clean-icons$(NC)    - Удалить сгенерированные иконки"
	@echo ""
	@echo "$(GREEN)Конфигурация:$(NC)"
	@echo "  Отредактируйте файл $(CONFIG_FILE) перед запуском"

.DEFAULT_GOAL := help
