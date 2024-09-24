# frozen_string_literal: true

if ENV.key?('DATADOG_APM_SERVICE_NAME')
  if defined?(Datadog)
    Datadog.configure do |c|
      c.env = Rails.env
      c.agent.host = ENV['DATADOG_TRACER_HOSTNAME'] || 'localhost'
      c.agent.port = ENV['DATADOG_TRACER_PORT'] || 8126
      c.tracing.enabled = true
      c.tracing.instrument :rails,
                           service_name: ENV['DATADOG_APM_SERVICE_NAME'],
                           database_service: "#{ENV['DATADOG_APM_SERVICE_NAME']}-db"
      c.tracing.instrument :grape, service_name: (ENV['DATADOG_APM_SERVICE_NAME']).to_s
    end
  else
    Rails.logger.debug 'DATADOG_APM_SERVICE_NAME specified, but ddtrace gem not loaded!'
  end
end
