require 'xcodeproj'

PROJECT_PATH      = ARGV[0] || 'build/iOS/iOS/Unity-iPhone.xcodeproj'
MAIN_TARGET_NAME  = ARGV[1] || 'Unity-iPhone'
EXT_TARGET_NAME   = ARGV[2] || 'notifications'

puts "Patch Xcodeproj: #{PROJECT_PATH}"

project = Xcodeproj::Project.open(PROJECT_PATH)

main_target = project.targets.find { |t| t.name == MAIN_TARGET_NAME }
raise "❌ Не найден основной target #{MAIN_TARGET_NAME}" unless main_target

ext_target = project.targets.find { |t| t.name == EXT_TARGET_NAME }
unless ext_target
  raise "❌ Не найден extension target '#{EXT_TARGET_NAME}'. Сначала собери проект с Unity PostProcess!"
end

# Найдём appex product reference (он обычно лежит в products group)
appex_ref = project.products_group.children.find { |f| f.path&.end_with?('.appex') }
unless appex_ref
  appex_name = "#{EXT_TARGET_NAME}.appex"
  appex_ref = project.products_group.new_file("$(BUILT_PRODUCTS_DIR)/#{appex_name}")
  puts "Добавлен продукт appex: #{appex_name}"
end

# Найдём (или создадим) Embed App Extensions phase
embed_phase = main_target.copy_files_build_phases.find { |ph| ph.name == 'Embed App Extensions' }
unless embed_phase
  embed_phase = main_target.new_copy_files_build_phase('Embed App Extensions')
  embed_phase.dst_subfolder_spec = '13' # <-- ВАЖНО!
  puts "Создан Embed App Extensions phase"
end

unless embed_phase.files_references.include?(appex_ref)
  embed_phase.add_file_reference(appex_ref)
  puts "Добавлен appex в Embed App Extensions phase"
end

# Чиним настройки
ext_target.build_configurations.each do |config|
  config.build_settings['SKIP_INSTALL'] = 'NO'
  config.build_settings['WRAPPER_EXTENSION'] = 'appex'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
end

project.save
puts "✅ Проект пропатчен успешно!"
