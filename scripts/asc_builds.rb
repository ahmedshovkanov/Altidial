# Lists the most recent App Store Connect builds for the app and their
# processing state, so a build that Apple rejected after upload (which never
# shows up in the TestFlight UI) can be spotted without the rejection email.
#
# Usage (run from the repo root, uses the same env vars as the CI workflow):
#   APPSTORE_KEY_ID=XXXX APPSTORE_ISSUER_ID=YYYY \
#   APP_STORE_CONNECT_API_KEY_PATH=$HOME/private_keys/AuthKey_XXXX.p8 \
#   IOS_BUNDLE_ID=com.greg.hopandpost \
#   ruby scripts/asc_builds.rb        (or: bundle exec ruby scripts/asc_builds.rb)
require 'spaceship'

%w[APPSTORE_KEY_ID APPSTORE_ISSUER_ID APP_STORE_CONNECT_API_KEY_PATH IOS_BUNDLE_ID].each do |var|
  abort("#{var} is not set") if ENV[var].to_s.empty?
end

Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
  key_id: ENV['APPSTORE_KEY_ID'],
  issuer_id: ENV['APPSTORE_ISSUER_ID'],
  filepath: ENV['APP_STORE_CONNECT_API_KEY_PATH']
)

app = Spaceship::ConnectAPI::App.find(ENV['IOS_BUNDLE_ID'])
abort("No app record for #{ENV['IOS_BUNDLE_ID']} in the team this API key belongs to") unless app

puts "App: #{app.name} (#{app.bundle_id}) id=#{app.id}"
builds = Spaceship::ConnectAPI::Build.all(app_id: app.id, sort: '-uploadedDate', limit: 20)
if builds.empty?
  puts 'No builds have ever reached App Store Connect for this app.'
  exit
end

puts format('%-12s %-12s %-12s %-26s %s', 'version', 'build', 'state', 'uploaded', 'expired')
builds.each do |b|
  puts format('%-12s %-12s %-12s %-26s %s',
              b.app_version, b.version, b.processing_state, b.uploaded_date, b.expired)
end
puts
puts 'INVALID = Apple rejected the build after upload (reason is only in the email to the account holder).'
puts 'PROCESSING = still being processed; VALID = should be visible in TestFlight.'
