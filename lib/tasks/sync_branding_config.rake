# Sync branding (logos + installation name) from config/installation_config.yml to the database and clear cache.
# Run after placing custom logos, or changing INSTALLATION_NAME/BRAND_NAME in the yml.
# Usage: bundle exec rake branding:sync_config
namespace :branding do
  BRANDING_KEYS = %w[LOGO LOGO_DARK LOGO_THUMBNAIL INSTALLATION_NAME BRAND_NAME].freeze

  desc 'Sync logo paths and INSTALLATION_NAME/BRAND_NAME from installation_config.yml to DB and clear cache'
  task sync_config: :environment do
    config_path = Rails.root.join('config', 'installation_config.yml')
    unless File.exist?(config_path)
      puts "Config not found: #{config_path}"
      next
    end

    configs = YAML.safe_load(File.read(config_path))
    configs.each do |entry|
      next unless BRANDING_KEYS.include?(entry['name'])

      name = entry['name']
      value = entry['value']
      config = InstallationConfig.find_or_initialize_by(name: name)
      config.value = value
      config.save!
      puts "Updated #{name} = #{value}"
    end

    GlobalConfig.clear_cache
    puts 'GlobalConfig cache cleared. Logo paths will apply on next request.'
  end
end
