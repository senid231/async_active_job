# frozen_string_literal: true

module AsyncActiveJob
  class Adapter
    # @param active_job [ActiveJob::Base] the job to be enqueued from +#perform_later+
    # @return [AsyncActiveJob::Job]
    def enqueue(active_job)
      enqueue_at(active_job, nil)
    end

    # @param active_job [ActiveJob::Base] the job to be enqueued from +#perform_later+
    # @param timestamp [Integer, nil] the epoch time to perform the job
    # @return [AsyncActiveJob::Job]
    def enqueue_at(active_job, timestamp)
      scheduled_at = timestamp ? Time.zone.at(timestamp) : nil
      opts = { active_job: active_job, scheduled_at: scheduled_at }
      ActiveSupport::Notifications.instrument('enqueue_job.async_active_job', opts) do |instrument_payload|
        async_active_job = AsyncActiveJob::Job.enqueue(
                             JobWrapper.new(active_job.serialize),
                             queue_name: active_job.queue_name || AsyncActiveJob.configuration.default_queue_name,
                             priority: active_job.priority || AsyncActiveJob.configuration.default_priority,
                             run_at: scheduled_at || Time.zone.now
                           )
        instrument_payload[:async_active_job] = async_active_job
        active_job.provider_job_id = async_active_job.id
        async_active_job
      end
    end

    class JobWrapper # :nodoc:
      attr_accessor :job_data

      def initialize(job_data)
        @job_data = job_data
      end

      def active_job_class
        job_data['job_class'].constantize
      end

      def perform
        ActiveJob::Base.execute(job_data)
      end
    end
  end
end
