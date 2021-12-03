# frozen_string_literal: true

require 'async_active_job/adapter'
require 'async_active_job/configuration'
require 'active_job/queue_adapters/async_active_job_adapter'
require 'async_active_job/engine'

module AsyncActiveJob
  module_function

  # @return [AsyncActiveJob::Configuration]
  def configuration
    AsyncActiveJob::Configuration.instance
  end

  # @yield [config]
  # @yieldparam config [AsyncActiveJob::Configuration]
  def configure
    yield configuration
  end
end
