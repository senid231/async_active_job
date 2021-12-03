# AsyncActiveJob

Multi-fiber, Postgres-based, ActiveJob backend for Ruby on Rails.
Based on [async](https://github.com/socketry/async)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'async_active_job'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install async_active_job

## Usage

Add to `config/application.rb`:
```ruby
config.active_job.queue_adapter = :async_active_job
```

Generate `bin/async_active_job` file:
```shell
$ rails g async_active_job
```

Generate migration:
```shell
$ rails g async_active_job:active_record
```

Apply migration:
```shell
$ rails db:migrate
```

Create `config/initilizers/async_active_job.rb` to override configuration defaults:
```ruby
AsyncJob.configure do |config|
  # config.default_max_attempts = 25
  # config.default_next_run_at = ->(now, opts) { opts[:attempts].minutes.from_now(now) }
  # config.max_run_timeout = 1.hour
  # config.default_priority = 0
  # config.default_queue_name = nil
  # config.no_job_sleep_duration = 3
  # config.task_limit = nil
  # config.task_limit_sleep_duration = 3
  # config.active_record_base_class_name = 'ApplicationRecord'
end
```

Start `async_active_job` process:
```shell
$ bundle exec bin/async_active_job
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/senid231/async_active_job. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/senid231/async_active_job/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the AsyncActiveJob project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/senid231/async_active_job/blob/master/CODE_OF_CONDUCT.md).
