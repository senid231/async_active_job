# frozen_string_literal: true

module AsyncActiveJob
  class Job < AsyncActiveJob.configuration.active_record_base_class
    self.table_name = 'async_active_jobs'

    PRIORITY_MIN = -32_768
    PRIORITY_MAX = 32_767
    ATTEMPTS_MIN = 0
    ATTEMPTS_MAX = 32_767

    before_validation on: :create do
      self.queue_name = AsyncActiveJob.configuration.default_queue_name if queue_name.blank?
      self.priority ||= AsyncActiveJob.configuration.default_priority
    end

    validates :job_data, presence: true
    validates :priority, numericality: {
      only_integer: true,
      greater_than_or_equal_to: PRIORITY_MIN,
      less_than_or_equal_to: PRIORITY_MAX
    }
    validates :attempts, numericality: {
      only_integer: true,
      greater_than_or_equal_to: ATTEMPTS_MIN,
      less_than_or_equal_to: ATTEMPTS_MAX
    }

    before_save do
      self.queue_name = queue_name&.presence
    end

    scope :not_locked, -> do
      timeout = AsyncActiveJob.configuration.max_run_timeout
      where('locked_at IS NULL OR locked_at < ?', current_time_from_proper_timezone - timeout)
    end

    scope :ready, -> do
      where('run_at IS NOT NULL AND run_at <= ?', current_time_from_proper_timezone)
    end

    scope :order_by_priority, -> do
      order('priority ASC, run_at ASC')
    end

    scope :with_queues, ->(queue_names) do
      if queue_names.nil?
        all
      else
        where(queue_name: queue_names)
      end
    end

    class << self
      # @param job_wrapper [AsyncActiveJob::Adapter::JobWrapper]
      # @param options [Hash] with keys:
      #   queue_name [String,nil]
      #   priority [Integer,nil]
      #   run_at [Time]
      def enqueue(job_wrapper, options = {})
        options.assert_valid_keys(:queue_name, :priority, :run_at)
        record = new(job_wrapper: job_wrapper, **options)
        record.save!
        record
      end

      # UPDATE async_active_jobs
      # SET locked_at = ?, locked_by = ?
      # WHERE id IN (
      #   SELECT id FROM async_active_jobs WHERE ... ORDER BY ... LIMIT 1 FOR UPDATE
      # )
      # @param queue_names [Array,nil]
      # @return [AsyncActiveJob::Job,nil]
      def next_with_lock(queue_names)
        quoted_name = connection.quote_table_name(table_name)
        ready_scope = AsyncActiveJob::Job.not_locked.ready.with_queues(queue_names).order_by_priority
        subquery = ready_scope.limit(1).lock(true).select(:id).to_sql
        sql = "UPDATE #{quoted_name} SET locked_at = ?, locked_by = ? WHERE id IN (#{subquery}) RETURNING *"
        result = find_by_sql([sql, current_time_from_proper_timezone, Process.pid])
        result[0]
      end

      # @param async_active_job [AsyncActiveJob::Job]
      def perform_job(async_active_job)
        async_active_job.perform
        async_active_job.destroy!
      rescue StandardError => e
        handle_failed_job(async_active_job, e)
      end

      def calculate_max_attempts(active_job_class)
        if active_job_class.respond_to?(:max_attempts)
          active_job_class.max_attempts
        else
          AsyncActiveJob.configuration.default_max_attempts
        end
      end

      def calculate_next_run_at(active_job_class, options)
        now = current_time_from_proper_timezone
        if active_job_class.respond_to?(:next_run_at)
          active_job_class.next_run_at(now, options)
        else
          AsyncActiveJob.configuration.default_next_run_at.call(now, options)
        end
      end

      # @param async_active_job [AsyncActiveJob::Job]
      # @param error [Exception]
      def handle_failed_job(async_active_job, error)
        attempts = async_active_job.attempts + 1
        max_attempts = calculate_max_attempts(async_active_job.active_job_class)

        if attempts >= max_attempts
          next_run_at = nil
          failed_at = current_time_from_proper_timezone
        else
          next_run_at = calculate_next_run_at(
                          async_active_job.active_job_class,
                          attempts: attempts,
                          max_attempts: max_attempts,
                          run_at: async_active_job.run_at
                        )
          failed_at = nil
        end

        async_active_job.update!(
          job_wrapper: async_active_job.job_wrapper,
          attempts: attempts,
          last_error: format_error(error),
          run_at: next_run_at,
          locked_at: nil,
          locked_by: nil,
          failed_at: failed_at
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

    # @return [AsyncActiveJob::Adapter::JobWrapper] with job_data:
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
      @job_wrapper ||= AsyncActiveJob::Adapter::JobWrapper.new(data)
    end

    # @param job_wrapper [AsyncActiveJob::Adapter::JobWrapper]
    def job_wrapper=(job_wrapper)
      self.job_data = job_wrapper.job_data.except('provider_job_id')
    end
  end
end
