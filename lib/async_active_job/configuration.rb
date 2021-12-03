# frozen_string_literal: true

require 'singleton'

module AsyncActiveJob
  class Configuration
    include Singleton

    class << self
      def attr_config(name, default:)
        ivar = :"@#{name}"
        attr_writer name

        define_method(name) { instance_variable_defined?(ivar) ? instance_variable_get(ivar) : default }
      end
    end

    # @!method default_max_attempts [Integer]
    #   @return [Integer]
    # @!method default_max_attempts=(value)
    #   @param value [Integer]
    attr_config :default_max_attempts, default: 25

    # @!method default_next_run_at
    #   @return [Proc]
    # @!method default_next_run_at=(value)
    #   @param value [Proc]
    attr_config :default_next_run_at, default: ->(now, opts) { opts[:attempts].minutes.from_now(now) }

    # @!method max_run_timeout [Integer]
    #   @return [Integer]
    # @!method max_run_timeout=(value)
    #   @param value [Integer]
    attr_config :max_run_timeout, default: 1.hour

    # @!method default_priority
    #   @return [Integer]
    # @!method default_priority=(value)
    #   @param value [Integer]
    attr_config :default_priority, default: 0

    # @!method default_queue_name
    #   @return [String,nil]
    # @!method default_queue_name=(value)
    #   @param value [String,nil]
    attr_config :default_queue_name, default: nil

    # @!method no_job_sleep_duration
    #   @return [Integer]
    # @!method no_job_sleep_duration=(value)
    #   @param value [Integer]
    attr_config :no_job_sleep_duration, default: 3

    # @!method task_limit
    #   @return [Integer,nil]
    # @!method task_limit=(value)
    #   @param value [Integer,nil]
    attr_config :task_limit, default: nil

    # @!method task_limit_sleep_duration
    #   @return [Integer]
    # @!method task_limit_sleep_duration=(value)
    #   @param value [Integer]
    attr_config :task_limit_sleep_duration, default: 3

    # @!method active_record_base_class_name
    #   @return [String]
    # @!method active_record_base_class_name=(value)
    #   @param value [String]
    attr_config :active_record_base_class_name, default: 'ApplicationRecord'

    # @return [Class<ActiveRecord::Base>]
    def active_record_base_class
      active_record_base_class_name.constantize
    end
  end
end
