# frozen_string_literal: true

require 'rails/generators/migration'
require 'rails/generators/active_record'

module AsyncActiveJob
  class ActiveRecordGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    source_paths << File.join(__dir__, 'templates')

    def create_migration_file
      migration_template 'migration.rb.erb',
                         'db/migrate/create_async_active_jobs.rb',
                         migration_version: migration_version
    end

    def self.next_migration_number(dirname)
      ActiveRecord::Generators::Base.next_migration_number dirname
    end

    private

    def migration_version
      "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]" if ActiveRecord::VERSION::MAJOR >= 5
    end

    def next_migration_number(dirname)
      next_migration_number = current_migration_number(dirname) + 1
      if ActiveRecord::Base.timestamped_migrations
        [Time.now.utc.strftime('%Y%m%d%H%M%S'), format('%.14d', next_migration_number)].max
      else
        format('%.3d', next_migration_number)
      end
    end
  end
end
