# frozen_string_literal: true

require 'async'

module AsyncActiveJob
  class Runner
    class << self
      def start(queues: nil)
        new(queues: queues).start
      end
    end

    # @param queues [Array,nil]
    def initialize(queues: nil)
      @reactor = nil
      @logger = Rails.logger
      @interrupted = false
      @task_count = 0
      @queues = queues&.presence
    end

    def start
      trap('TERM') { interrupt! }
      trap('INT') { interrupt! }

      ::Async::Reactor.run do
        @reactor = Async::Task.current.reactor
        loop do
          if interrupted?
            logger.info { 'Exiting...' }
            break
          end
          run_once
        end
      end
    end

    def run_once
      task_limit = AsyncActiveJob.configuration.task_limit
      task_limit_sleep_duration = AsyncActiveJob.configuration.task_limit_sleep_duration
      if task_limit && task_count >= task_limit

        logger.debug { "Task limit #{task_limit} reached, sleeping for #{task_limit_sleep_duration} seconds" }
        reactor.sleep(task_limit_sleep_duration)
        return
      end

      async_active_job = AsyncActiveJob::Job.next_with_lock(queues)
      if async_active_job
        run_task do
          with_optional_timeout(AsyncActiveJob.configuration.max_run_timeout) do
            run_job(async_active_job)
          end
        end
        reactor.sleep(0)
      else
        no_job_sleep_duration = AsyncActiveJob.configuration.no_job_sleep_duration
        logger.debug { "No jobs, sleeping for #{no_job_sleep_duration} seconds" }
        reactor.sleep(no_job_sleep_duration)
      end
    end

    private

    attr_reader :reactor, :logger, :queues
    attr_accessor :task_count

    def with_optional_timeout(duration, &block)
      return yield if duration.nil?

      reactor.with_timeout(duration, &block)
    end

    def run_job(async_active_job)
      self.task_count += 1
      job_name = "AsyncActiveJob::Job##{async_active_job.id} (Job ID: #{async_active_job.active_job_id})"
      logger.debug { "Performing #{job_name}" }
      ms = Benchmark.ms { AsyncActiveJob::Job.perform_job(async_active_job) }
      logger.debug { format("#{job_name} performed in %.2fms", ms) }
      self.task_count -= 1
    end

    def run_task(&block)
      Async::Task.new(reactor, &block).run
    end

    def schedule_task(&block)
      reactor << Async::Task.new(reactor, &block).fiber
    end

    def interrupt!
      @interrupted = true
    end

    def interrupted?
      @interrupted
    end
  end
end
