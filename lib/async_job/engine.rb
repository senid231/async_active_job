# frozen_string_literal: true

module AsyncJob
  class Engine < ::Rails::Engine
    isolate_namespace AsyncJob
  end
end
