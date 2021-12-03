# frozen_string_literal: true

module AsyncActiveJob
  class Engine < ::Rails::Engine
    isolate_namespace AsyncActiveJob
  end
end
