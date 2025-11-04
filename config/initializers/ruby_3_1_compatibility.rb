# Compatibility patch for Ruby 3.1+ with Rails 5.2
# Ruby 3.1 introduced stricter keyword argument handling that causes issues
# with various Rails 5.2 methods

if Rails::VERSION::MAJOR == 5 && Rails::VERSION::MINOR == 2
  module ActionDispatch
    class Static
      alias_method :original_initialize, :initialize

      def initialize(app, path, deprecated_cache_control = nil, **options)
        # Handle the legacy 3-argument signature
        if deprecated_cache_control && options.empty? && deprecated_cache_control.is_a?(Hash)
          options = deprecated_cache_control
          deprecated_cache_control = nil
        end

        original_initialize(app, path, **options)
      end
    end
  end

  # Fix for Psych 4.0 (Ruby 3.1+) YAML alias handling
  require 'rails/application/configuration'

  module Rails
    class Application
      class Configuration
        def database_configuration
          path = paths["config/database"].existent.first
          yaml = Pathname.new(path) if path

          config = if yaml && yaml.exist?
            require "erb"
            loaded_yaml = ERB.new(yaml.read).result
            # Use unsafe_load for compatibility with YAML anchors/aliases
            if YAML.respond_to?(:unsafe_load)
              YAML.unsafe_load(loaded_yaml) || {}
            else
              YAML.load(loaded_yaml) || {}
            end
          elsif ENV['DATABASE_URL']
            # Value from ENV['DATABASE_URL'] is set to default database connection
            # by Active Record.
            {}
          else
            raise "Could not load database configuration. No such file - #{paths["config/database"].instance_variable_get(:@paths)}"
          end

          config
        rescue Psych::SyntaxError => e
          raise "YAML syntax error occurred while parsing #{path}. " \
                "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
                "Error: #{e.message}"
        end
      end
    end
  end

  # Fix for ActiveRecord keyword argument issues with Ruby 3.1
  # Prepend a module to intercept method calls and convert hash arguments to keyword arguments
  require 'active_record/connection_adapters/abstract/schema_statements'
  require 'active_record/connection_adapters/abstract/schema_definitions'

  Module.new do
    def add_index(table_name, column_name, options = {})
      super(table_name, column_name, **options)
    end
  end.tap do |mod|
    ActiveRecord::ConnectionAdapters::SchemaStatements.prepend(mod)
  end

end

# Note: Ruby 3.1 has deeper keyword argument incompatibilities with Rails 5.2.8
# For full compatibility, Ruby 3.0.x is recommended, or upgrade to Rails 6+.
