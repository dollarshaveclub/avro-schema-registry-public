if ENV.key?('DATADOG_APM_SERVICE_NAME')
  if defined?(Datadog)
    Datadog.configure do |c|
      c.tracer env: Rails.env, enabled: true,
               hostname: ENV['DATADOG_TRACER_HOSTNAME'] || 'localhost',
               port: ENV['DATADOG_TRACER_PORT'] || 8126
      c.use :rails, service_name: ENV['DATADOG_APM_SERVICE_NAME']
      c.use :grape, service_name: "#{ENV['DATADOG_APM_SERVICE_NAME']}"
    end
  else
    puts 'DATADOG_APM_SERVICE_NAME specified, but ddtrace gem not loaded!'
  end
end
