desc 'Import schemas from another registry, preserving IDs, subjects, and versions'
task import_schemas: [:environment] do
  raise 'REGISTRY_URL must be specified' unless ENV['REGISTRY_URL']
  require 'avro_turf'
  require 'avro_turf/confluent_schema_registry'

  # Monkey-patch Schema model to allow for storing schemas that were
  # accepted by the Confluent schema registry, but cannot be parsed
  # with the Ruby version of the Avro library.
  class Schema
    private
    def generate_fingerprints
      self.fingerprint = Schemas::FingerprintGenerator.generate_v1(json)
  
      self.fingerprint2 = Schemas::FingerprintGenerator.generate_v2(json) if Schemas::FingerprintGenerator.include_v2?
    
    rescue SchemaRegistry::InvalidAvroSchemaError
      self.fingerprint = SecureRandom.uuid
  
      self.fingerprint2 = SecureRandom.uuid
    end
  end
  
  notes = []
  
  logger = Logger.new($stdout)
  logger.level = Logger::ERROR
  registry = AvroTurf::ConfluentSchemaRegistry.new(ENV['REGISTRY_URL'], logger: logger)

  registry.subjects.each do |subject|
    registry.subject_versions(subject).each do |version|
      response = registry.subject_version(subject, version)
      puts "#{response['subject']} Version: #{response['version']} Schema ID: #{response['id']}"
      
      # Create the schema at this specific ID unless it already exists
      schema = Schema.find_by_id(response['id'])
      real_schema = schema
      if schema.nil?
        schema = Schema.new(id: response['id'], json: response['schema'])
        begin
          schema.save!
          real_schema = schema
          puts "Registered schema ID: #{schema.id}"
        rescue ActiveRecord::RecordNotUnique => e
          # Official Confluent schema registry can have the same exact schema
          # registered under multiple different IDs. Salsify registry enforces
          # a unique constraint on the schema's fingerprint.
          # Let's save the duplicate schema with a bogus fingerprint so it's still
          # resolvable by its original ID, but link the SchemaVersion version for
          # this subject to the other schema instance saved with the proper
          # fingerprint.
          #
          # This allows us to import the same schema at multiple IDs, matching
          # the source schema registry and without failing to resolve a schema
          # by its given ID, but we won't be using the additional copies of the
          # schema in subject versions.

          real_schema = Schema.find_by_fingerprint2(schema.fingerprint2)
          if real_schema.nil?
            raise "Unable to find other copy of schema with fingerprint #{schema.fingerprint2}"
          end
          
          if real_schema.json != schema.json
            raise "Fingerprint2 matches another schema, but JSON text is different!"
          end
          
          notes << "Remapped [#{response['subject']}] version #{response['version']} from schema #{response['id']} to #{real_schema.id}"
          
          schema.fingerprint2 = schema.fingerprint2 + ' ' + SecureRandom.uuid
          Schema.skip_callback(:save, :before, :generate_fingerprints)
          schema.save!
          Schema.set_callback(:save, :before, :generate_fingerprints)
        end
      end
      
      # Create this subject unless it already exists
      sub = Subject.find_by_name(response['subject'])
      if sub.nil?
        sub = Subject.create!(name: response['subject'])
        puts "  - Registered new subject"
      end

      # Link up this subject version to the schema.
      if sub.versions.where(version: response['version']).none?
        ver = sub.versions.create!(version: response['version'], schema: real_schema)
        puts "  - Linked subject version #{ver.version} to schema ID #{real_schema.id}"
      end
      
      puts
      puts
    end
  end
  puts
  puts notes.join("\n")
  nil
end
