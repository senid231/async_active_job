# frozen_string_literal: true

require 'async_job/adapter'
require 'async_job/configuration'
require 'active_job/queue_adapters/async_job_adapter'
require 'async_job/engine'

module AsyncJob
  module_function

  # @return [AsyncJob::Configuration]
  def configuration
    AsyncJob::Configuration.instance
  end

  # @yield [config]
  # @yieldparam config [AsyncJob::Configuration]
  def configure
    yield configuration
  end
end
