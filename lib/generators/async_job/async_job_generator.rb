# frozen_string_literal: true

require 'rails/generators/base'

class AsyncJobGenerator < Rails::Generators::Base
  source_paths << File.join(__dir__, 'templates')

  def create_executable_file
    template 'script', 'bin/async_job'
    chmod 'bin/async_job', 0o755
  end
end
