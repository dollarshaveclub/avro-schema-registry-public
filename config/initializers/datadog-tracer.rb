if ENV.key?('DATADOG_APM_SERVICE_NAME')
  if defined?(Datadog)
    Datadog.configure do |c|
      c.use :rails, service_name: ENV['DATADOG_APM_SERVICE_NAME']
    end
  else
    puts 'DATADOG_APM_SERVICE_NAME specified, but ddtrace gem not loaded!'
  end
end
