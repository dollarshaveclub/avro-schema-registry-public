if ENV.key?('DATADOG_APM_SERVICE_NAME')
  if defined?(Datadog)
    Datadog.configure do |c|
      c.env = Rails.env
      c.use :rails, service_name: ENV['DATADOG_APM_SERVICE_NAME']
      c.use :grape, service_name: "#{ENV['DATADOG_APM_SERVICE_NAME']}-grape"
    end
  else
    puts 'DATADOG_APM_SERVICE_NAME specified, but ddtrace gem not loaded!'
  end
end
