# frozen_string_literal: true

require 'async_job'
require 'async_job/runner'
require 'dry/cli'

module AsyncJob
  module CLI
    module Commands
      extend Dry::CLI::Registry

      class Version < Dry::CLI::Command
        desc 'Print version'

        def call(*)
          Rails.logger.debug AsyncJob::VERSION
        end
      end

      class Start < Dry::CLI::Command
        desc 'Start worker'

        option :queues, desc: 'comma separated list of queue names'

        def call(queues: nil, **)
          queues = queues&.split(',')
          AsyncJob::Runner.start(queues: queues)
        end
      end

      register 'version', Version, aliases: ['v', '-v', '--version']
      register 'start', Start
    end

    module_function

    def call(arguments)
      Dry::CLI.new(Commands).call(arguments: arguments)
    end
  end
end
