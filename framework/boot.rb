# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Constants set by the java boot process
#  KFRAMEWORK_ROOT - full pathname of the root of the framework dir
#  KFRAMEWORK_ENV  - name of the environment

require 'java'

# Add the framework root to the search path
$: << "#{KFRAMEWORK_ROOT}"

# Libraries used by the framework
require 'drb'
require 'erb'
require 'benchmark'
require 'logger'
require 'json'
require 'json/ext' # to make sure the Java version is loaded

# Gems used by the framework
require 'rubygems'

gem 'i18n', '= 0.5.0' # ActiveSupport dependency
gem 'activesupport', '= 3.0.20'
# Only load the bits of ActiveSupport used - some of the extensions break the application
require 'active_support/time'
require 'active_support/buffered_logger'
require 'active_support/core_ext/logger'
require 'active_support/log_subscriber'
ActiveSupport::JSON.backend = "JSONGem" # explicitly state that ActiveSupport should use the json gem

gem 'activerecord', '= 3.0.20' # need to specify exact version because part of the implementation is overridden (ConnectionPool and logger)
gem 'activerecord-jdbc-adapter', '= 1.2.9.1'
gem 'activerecord-jdbcpostgresql-adapter', '= 1.2.9' # patched below
require 'active_record'
require 'arjdbc'
require 'lib/common/activerecord_jdbc_adapter_fix' # for thread safety
gem 'builder', '= 2.1.2'
require 'builder'
gem 'tzinfo-data'
require 'tzinfo'

# TODO: Work out why $" doesn't include the fully qualified name of the postgresql adaptor on recent JRubys, and fix it.
# Avoid loading the pg adaptor file again when making the database connection, which breaks because the JDBC adaptor has messed with the internal at this point.
if $".include?("active_record/connection_adapters/postgresql_adapter.rb")
  postgresql_adapter_file = "#{ENV['JRUBY_HOME']}/lib/ruby/gems/shared/gems/activerecord-3.0.20/lib/active_record/connection_adapters/postgresql_adapter.rb"
  raise "Expected file doesn't exist: #{postgresql_adapter_file}" unless File.exist?(postgresql_adapter_file)
  $" << postgresql_adapter_file
end

# Get a binding for runner.rb, so scripts can be run in the context of main and so behave as expected.
KFRAMEWORK_RUNNER_BINDING = self.__send__(:binding)

# Include all framework code
require 'framework/kframework'

# Create a notification centre
KNotificationCentre = KFramework::NotificationCentre.new

# Load database connection details, and inform ActiveRecord
KFRAMEWORK_DATABASE_CONFIG = File.open("#{KFRAMEWORK_ROOT}/config/database.json") { |f| JSON.parse(f.read) }
raise "No database config for #{KFRAMEWORK_ENV} environment" unless KFRAMEWORK_DATABASE_CONFIG.has_key?(KFRAMEWORK_ENV)
ActiveRecord::Base.establish_connection(
  KFRAMEWORK_DATABASE_CONFIG[KFRAMEWORK_ENV].merge(
    "username" => java.lang.System.getProperty("user.name")
  )
)
KFRAMEWORK_DATABASE_NAME = KFRAMEWORK_DATABASE_CONFIG[KFRAMEWORK_ENV]["database"]

# Load environment, library code, and components
require "config/environments/#{KFRAMEWORK_ENV}"
require 'config/load'
KFRAMEWORK_COMPONENT_INFO = []
KFRAMEWORK_LOADED_COMPONENTS = []
PlatformComponentInfo = Struct.new(:path, :name, :display_name, :should_load)
component_configuration =JSON.parse(KInstallProperties.get(:component_configuration, '{}'))
load_all_components = (KFRAMEWORK_ENV != 'production') # 'testing' environments need everything loaded
Dir.glob("#{KFRAMEWORK_ROOT}/components/*/component.json").sort.each do |component_json|
  raise "Bad component filename" unless component_json =~ /\/components\/(.+?)\/component\.json\z/
  cname = $1
  cjson = JSON.parse(File.read(component_json))
  raise "Bad component.json: #{component_json}" unless cname == cjson['componentName']
  should_load = !(cjson['defaultDisable'])
  should_load = true if !should_load && (component_configuration['enable'] || []).include?(cname)
  should_load = false if should_load && (component_configuration['disable'] || []).include?(cname)
  should_load = true if load_all_components
  cinfo = PlatformComponentInfo.new(File.dirname(component_json), cname, cjson['displayName'], should_load)
  KFRAMEWORK_COMPONENT_INFO << cinfo
  KFRAMEWORK_LOADED_COMPONENTS << cinfo.name if cinfo.should_load
end
KFRAMEWORK_IS_MANAGED_SERVER = KFRAMEWORK_LOADED_COMPONENTS.include?('management')
KFRAMEWORK_COMPONENT_INFO.sort_by! { |i| [i.should_load ? 0 : 1, i.name] } # want sort by name, different to pathname of component.json
KFRAMEWORK_COMPONENT_INFO.each do |cinfo|
  require "#{cinfo.path}/load.rb" if cinfo.should_load
end
puts "Components:"
KFRAMEWORK_COMPONENT_INFO.each do |cinfo|
  puts sprintf("%08s %-20s %-50s", cinfo.should_load ? 'enable' : 'disable', cinfo.name, cinfo.display_name)
end

# Setup logging
KApp.logger_configure(KFRAMEWORK_LOG_FILE, 40, 4*1024*1024)
# Load a patch to turn off colorization from the built in logger
require 'framework/lib/activerecord_3_colorized_logging_off'

# Create framework object and return it to the java boot process
KFRAMEWORK__BOOT_OBJECT = begin
  framework = KFramework.new()

  framework.load_application

  require 'config/loaded'

  framework.set_static_files

  # Setup for dev mode?
  framework.devmode_setup if KFRAMEWORK_ENV == 'development'

  framework.load_namespace

  KNotificationCentre.finish_setup

  KApp.update_app_server_mappings

  framework
rescue => e
  puts %Q!Exception in boot.rb: #{e.inspect}\n#{e.backtrace.join("\n")}!
  nil
end
