#!/usr/bin/env ruby
# Скрипт для добавления фреймворков в notifications target (Do not Embed)
# Добавляет: FirebaseMessaging.framework, FirebaseCore.framework, UserNotifications.framework

require 'securerandom'

PBXPROJ_PATH = 'ios/Runner.xcodeproj/project.pbxproj'

# Генерация уникального ID в формате Xcode (24 символа hex)
def generate_id
  SecureRandom.hex(12).upcase
end

# Читаем файл
unless File.exist?(PBXPROJ_PATH)
  puts "\033[0;31m❌ Файл #{PBXPROJ_PATH} не найден\033[0m"
  exit 1
end

content = File.read(PBXPROJ_PATH)

# ID для notifications target и его Frameworks phase
NOTIF_FRAMEWORKS_PHASE = 'NOTIF008000000000000001'

# Проверяем что notifications target существует
unless content.include?(NOTIF_FRAMEWORKS_PHASE)
  puts "\033[0;31m❌ Notifications target не найден. Сначала выполните make setup-notifications\033[0m"
  exit 1
end

frameworks_to_add = []

# FirebaseMessaging.framework
unless content.include?('FirebaseMessaging.framework') && content.include?('FirebaseMessaging.framework in Frameworks')
  firebase_msg_file_ref = generate_id
  firebase_msg_build_file = generate_id
  frameworks_to_add << {
    name: 'FirebaseMessaging.framework',
    file_ref_id: firebase_msg_file_ref,
    build_file_id: firebase_msg_build_file,
    file_ref: "\t\t#{firebase_msg_file_ref} /* FirebaseMessaging.framework */ = {isa = PBXFileReference; explicitFileType = wrapper.framework; path = FirebaseMessaging.framework; sourceTree = BUILT_PRODUCTS_DIR; };",
    build_file: "\t\t#{firebase_msg_build_file} /* FirebaseMessaging.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = #{firebase_msg_file_ref} /* FirebaseMessaging.framework */; };",
    framework_group: "\t\t\t\t#{firebase_msg_file_ref} /* FirebaseMessaging.framework */,",
    frameworks_phase: "\t\t\t\t#{firebase_msg_build_file} /* FirebaseMessaging.framework in Frameworks */,"
  }
  puts "   Добавление FirebaseMessaging.framework..."
else
  puts "\033[0;33m   ⚠️  FirebaseMessaging.framework уже добавлен\033[0m"
end

# FirebaseCore.framework - проверим, добавлен ли он в notifications target
# Он может быть уже добавлен с Embed, нужно убрать embed
firebase_core_in_notif = content.match(/(\w{24}) \/\* FirebaseCore\.framework in Frameworks \*\/ = \{isa = PBXBuildFile.*?0D062EE42EE239F5009903F5.*?\}/)
if firebase_core_in_notif || content.include?('0D062EE52EE239F5009903F5 /* FirebaseCore.framework in Frameworks */')
  puts "   FirebaseCore.framework уже добавлен, проверка настроек embed..."
  # Убираем embed settings если есть
  content.gsub!(/0D062EE52EE239F5009903F5 \/\* FirebaseCore\.framework in Frameworks \*\/ = \{isa = PBXBuildFile; fileRef = 0D062EE42EE239F5009903F5 \/\* FirebaseCore\.framework \*\/; settings = \{ATTRIBUTES = \([^)]*\); \}; \};/) do
    '0D062EE52EE239F5009903F5 /* FirebaseCore.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = 0D062EE42EE239F5009903F5 /* FirebaseCore.framework */; };'
  end
  puts "\033[0;32m   ✓ FirebaseCore.framework настроен как Do not Embed\033[0m"
else
  # Нужно добавить FirebaseCore если его нет
  firebase_core_file_ref = generate_id
  firebase_core_build_file = generate_id
  frameworks_to_add << {
    name: 'FirebaseCore.framework',
    file_ref_id: firebase_core_file_ref,
    build_file_id: firebase_core_build_file,
    file_ref: "\t\t#{firebase_core_file_ref} /* FirebaseCore.framework */ = {isa = PBXFileReference; explicitFileType = wrapper.framework; path = FirebaseCore.framework; sourceTree = BUILT_PRODUCTS_DIR; };",
    build_file: "\t\t#{firebase_core_build_file} /* FirebaseCore.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = #{firebase_core_file_ref} /* FirebaseCore.framework */; };",
    framework_group: "\t\t\t\t#{firebase_core_file_ref} /* FirebaseCore.framework */,",
    frameworks_phase: "\t\t\t\t#{firebase_core_build_file} /* FirebaseCore.framework in Frameworks */,"
  }
  puts "   Добавление FirebaseCore.framework..."
end

# UserNotifications.framework
unless content.include?('UserNotifications.framework') && content =~ /UserNotifications\.framework in Frameworks/
  user_notif_file_ref = generate_id
  user_notif_build_file = generate_id
  frameworks_to_add << {
    name: 'UserNotifications.framework',
    file_ref_id: user_notif_file_ref,
    build_file_id: user_notif_build_file,
    file_ref: "\t\t#{user_notif_file_ref} /* UserNotifications.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = UserNotifications.framework; path = System/Library/Frameworks/UserNotifications.framework; sourceTree = SDKROOT; };",
    build_file: "\t\t#{user_notif_build_file} /* UserNotifications.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = #{user_notif_file_ref} /* UserNotifications.framework */; };",
    framework_group: "\t\t\t\t#{user_notif_file_ref} /* UserNotifications.framework */,",
    frameworks_phase: "\t\t\t\t#{user_notif_build_file} /* UserNotifications.framework in Frameworks */,"
  }
  puts "   Добавление UserNotifications.framework..."
else
  puts "\033[0;33m   ⚠️  UserNotifications.framework уже добавлен\033[0m"
end

# Удаляем Embed Frameworks фазу 0D062EE72EE239F5009903F5 для notifications если есть
if content.include?('0D062EE72EE239F5009903F5 /* Embed Frameworks */')
  puts "   Удаление Embed Frameworks фазы..."
  
  # Удаляем build file для embed (0D062EE62EE239F5009903F5)
  content.gsub!(/\t\t0D062EE62EE239F5009903F5 \/\* FirebaseCore\.framework in Embed Frameworks \*\/ = \{isa = PBXBuildFile;[^}]+\};\n/, '')
  
  # Удаляем саму фазу целиком
  content.gsub!(/\t\t0D062EE72EE239F5009903F5 \/\* Embed Frameworks \*\/ = \{\s*isa = PBXCopyFilesBuildPhase;[^}]*files = \([^)]*\);[^}]*\};\n/, '')
  
  # Удаляем ссылку на эту фазу из notifications target buildPhases
  content.gsub!(/\s*0D062EE72EE239F5009903F5 \/\* Embed Frameworks \*\/,/, '')
  
  puts "\033[0;32m   ✓ Embed Frameworks фаза удалена\033[0m"
end

# Добавляем фреймворки
frameworks_to_add.each do |fw|
  # 1. Добавляем PBXFileReference
  content.gsub!(/\/\* End PBXFileReference section \*\//) do
    "#{fw[:file_ref]}\n/* End PBXFileReference section */"
  end
  
  # 2. Добавляем PBXBuildFile
  content.gsub!(/\/\* End PBXBuildFile section \*\//) do
    "#{fw[:build_file]}\n/* End PBXBuildFile section */"
  end
  
  # 3. Добавляем в Frameworks группу (4F34940E5CC6E2EB6F5F0120)
  content.gsub!(/(4F34940E5CC6E2EB6F5F0120 \/\* Frameworks \*\/ = \{[^}]*children = \([^)]*)([\s\S]*?\);)/) do |match|
    # Находим место для вставки
    if match.include?(fw[:framework_group])
      match
    else
      match.sub(/(\);)$/) { "#{fw[:framework_group]}\n\t\t\t#{$1}" }
    end
  end
  
  # 4. Добавляем в Frameworks build phase для notifications (NOTIF008000000000000001)
  content.gsub!(/(#{NOTIF_FRAMEWORKS_PHASE} \/\* Frameworks \*\/ = \{[^}]*files = \()([^)]*\);)/) do
    prefix = $1
    files = $2
    if files.include?(fw[:frameworks_phase])
      "#{prefix}#{files}"
    else
      "#{prefix}\n#{fw[:frameworks_phase]}#{files}"
    end
  end
  
  puts "\033[0;32m   ✓ #{fw[:name]} добавлен\033[0m"
end

# Записываем файл
File.write(PBXPROJ_PATH, content)

puts "\033[0;32m✅ Фреймворки добавлены в notifications target (Do not Embed)\033[0m"
