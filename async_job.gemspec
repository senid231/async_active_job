# frozen_string_literal: true

require_relative 'lib/async_job/version'

Gem::Specification.new do |spec|
  spec.name = 'async_job'
  spec.version = AsyncJob::VERSION
  spec.authors = ['Denis Talakevich']
  spec.email = ['senid231@gmail.com']

  spec.summary = 'Multi-fiber, Postgres-based, ActiveJob backend for Ruby on Rails'
  spec.homepage = 'https://github.com/didww/async_job'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.6.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = "#{spec.homepage}/tree/master"
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:spec)/|\.(?:git|github))})
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activejob'
  spec.add_dependency 'async', '~> 1.0'
  spec.metadata = {
    'rubygems_mfa_required' => 'true'
  }
end
