# frozen_string_literal: true

module AsyncJob
  class Job < AsyncJob.configuration.active_record_base_class
    self.table_name = 'async_jobs'

    class_attribute :default_max_attempts, instance_accessor: false, default: 25
    class_attribute :default_next_run_at, instance_accessor: false, default: ->(now, options) {
                                                                               now + options[:attempts].minutes
                                                                             }

    validates :job_data, presence: true
    validates :priority, numericality: {
      only_integer: true,
      greater_than_or_equal_to: -32_768,
      less_than_or_equal_to: 32_767
    }
    validates :attempts, numericality: {
      only_integer: true,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 32_767
    }

    scope :not_locked, -> do
      # where('locked_at IS NULL OR locked_at < ?', now - timeout)
      where(locked_at: nil)
    end

    scope :ready, -> do
      where('run_at IS NOT NULL AND run_at <= ?', current_time_from_proper_timezone)
    end

    scope :order_by_priority, -> do
      order('priority ASC, run_at ASC')
    end

    class << self
      # @param job_wrapper [AsyncJob::Adapter::JobWrapper]
      # @param options [Hash] with keys:
      #   queue [String,nil]
      #   priority [Integer,nil]
      def enqueue(job_wrapper, options = {})
        record = new(job_wrapper: job_wrapper, **options)
        record.save!
        record
      end

      # UPDATE async_jobs
      # SET locked_at = ?. locked_pid = ?
      # WHERE id IN (
      #   SELECT id FROM async_jobs WHERE ... LIMIT 1 FOR UPDATE
      # )
      # @return [AsyncJob::Job,nil]
      def next_with_lock
        quoted_name = connection.quote_table_name(table_name)
        ready_scope = AsyncJob::Job.not_locked.ready.order_by_priority
        subquery = ready_scope.limit(1).lock(true).select(:id).to_sql
        sql = "UPDATE #{quoted_name} SET locked_at = ?, locked_pid = ? WHERE id IN (#{subquery}) RETURNING *"
        result = find_by_sql([sql, current_time_from_proper_timezone, Process.pid])
        result[0]
      end

      # @param async_job [AsyncJob::Job]
      def perform_job(async_job)
        async_job.perform
        async_job.destroy!
      rescue StandardError => e
        handle_failed_job(async_job, e)
      end

      def calculate_max_attempts(active_job_class)
        if active_job_class.respond_to?(:max_attempts)
          active_job_class.max_attempts
        else
          default_max_attempts
        end
      end

      def calculate_next_run_at(active_job_class, options)
        now = current_time_from_proper_timezone
        if active_job_class.respond_to?(:next_run_at)
          active_job_class.next_run_at(now, options)
        else
          default_next_run_at.call(now, options)
        end
      end

      # @param async_job [AsyncJob::Job]
      # @param error [Exception]
      def handle_failed_job(async_job, error)
        attempts = async_job.attempts + 1
        max_attempts = calculate_max_attempts(async_job.active_job_class)

        if attempts >= max_attempts
          next_run_at = nil
        else
          next_run_at = calculate_next_run_at(
                          async_job.active_job_class,
                          attempts: attempts,
                          max_attempts: max_attempts,
                          run_at: async_job.run_at
                        )
        end

        async_job.update!(
          job_wrapper: async_job.job_wrapper,
          attempts: attempts,
          last_error: format_error(error),
          run_at: next_run_at,
          locked_at: nil,
          locked_pid: nil
        )
      end

      def format_error(error, causes: [])
        lines = ["#{error.class} #{error.message}", error.backtrace&.join("\n")]
        if error.cause && error.cause != error && causes.exclude?(error.cause)
          new_causes = causes + [error]
          lines.push "Caused by:\n#{format_error(error.cause, causes: new_causes)}"
        end
        lines.compact.join("\n")
      end
    end

    delegate :perform, :active_job_class, to: :job_wrapper

    def active_job_id
      job_data['job_id']
    end

    # @return [AsyncJob::Adapter::JobWrapper] with job_data:
    #   "job_class"  => self.class.name,
    #   "job_id"     => job_id,
    #   "provider_job_id" => provider_job_id,
    #   "queue_name" => queue_name,
    #   "priority"   => priority,
    #   "arguments"  => serialize_arguments_if_needed(arguments),
    #   "executions" => executions,
    #   "exception_executions" => exception_executions,
    #   "locale"     => I18n.locale.to_s,
    #   "timezone"   => timezone,
    #   "enqueued_at" => Time.now.utc.iso8601
    def job_wrapper
      return if job_data.nil?

      data = job_data.merge('provider_job_id' => id)
      @job_wrapper ||= AsyncJob::Adapter::JobWrapper.new(data)
    end

    # @param job_wrapper [AsyncJob::Adapter::JobWrapper]
    def job_wrapper=(job_wrapper)
      self.job_data = job_wrapper.job_data.except('provider_job_id')
    end
  end
end
