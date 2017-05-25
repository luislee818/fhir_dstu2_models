module FHIR
  module DSTU2
    module Boot
      class Generator
        attr_accessor :lib
        attr_accessor :defn
        # templates keeps track of all the templates in context within a given StructureDefinition
        attr_accessor :templates
        attr_accessor :missing_expansions, :missing_required_expansion

        def initialize(auto_setup: true)
          # load the valueset expansions
          @defn = FHIR::DSTU2::Definitions
          # templates is an array
          @templates = []
          setup if auto_setup
        end

        def setup
          # make folders for generated content if they do not exist
          @lib = File.expand_path '..', File.dirname(File.absolute_path(__FILE__))
          Dir.mkdir(File.join(@lib, 'fhir')) unless Dir.exist?(File.join(@lib, 'fhir'))
          Dir.mkdir(File.join(@lib, 'fhir', 'types')) unless Dir.exist?(File.join(@lib, 'fhir', 'types'))
          Dir.mkdir(File.join(@lib, 'fhir', 'resources')) unless Dir.exist?(File.join(@lib, 'fhir', 'resources'))

          # delete previously generated folder contents
          Dir.glob(File.join(@lib, 'fhir', '*')).each { |f| File.delete(f) unless File.directory?(f) }
          Dir.glob(File.join(@lib, 'fhir', '**', '*')).each { |f| File.delete(f) unless File.directory?(f) }
        end

        def generate_metadata
          template = FHIR::DSTU2::Boot::Template.new([], true)

          primitives = @defn.primitive_types
          hash = {}
          primitives.each do |p|
            field = FHIR::DSTU2::Field.new
            field.name = nil

            # try to find the element that describes the value
            type = p['snapshot']['element'].select { |e| e['path'].end_with?('.value') }.first['type'].first

            # try to find the JSON data type
            ext = type['_code']['extension'].find { |e| e['url'] == 'http://hl7.org/fhir/StructureDefinition/structuredefinition-json-type' }
            field.type = ext ? ext['valueString'] : 'string'

            # try to find a regex
            if type['extension']
              ext = type['extension'].find { |e| e['url'] == 'http://hl7.org/fhir/StructureDefinition/structuredefinition-regex' }
              field.regex = ext['valueString'] if ext
            end

            hash[p['id']] = field.serialize
          end
          hash['xhtml'] = { 'type' => 'string' }
          template.constants['PRIMITIVES'] = hash

          template.constants['TYPES'] = @defn.complex_types.map { |t| t['id'] }.sort

          # resources
          template.constants['RESOURCES'] = @defn.resource_definitions.map { |r| r['id'] }.sort

          filename = File.join(@lib, 'fhir', 'metadata.rb')
          file = File.open(filename, 'w:UTF-8')
          file.write(template.to_s)
          file.close
        end

        def generate_types
          folder = File.join @lib, 'fhir', 'types'
          # complex data types start with an uppercase letter
          # and we'll filter out profiles on types (for example, Age is a profile on Quantity)
          complex_types = @defn.complex_types
          generate_class_files(folder, complex_types)
        end

        def generate_resources
          folder = File.join @lib, 'fhir', 'resources'
          generate_class_files(folder, @defn.resource_definitions)
        end

        def generate_class_files(folder = @lib, structure_defs = [])
          structure_defs.each do |structure_def|
            @templates.clear
            type_name = structure_def['id']
            template = generate_class([type_name], structure_def, true)
            params = @defn.search_parameters(type_name)
            template.constants['SEARCH_PARAMS'] = params unless params.nil?
            filename = File.join(folder, "#{type_name}.rb")
            file = File.open(filename, 'w:UTF-8')
            file.write(template.to_s)
            file.close
          end
        end

        def cap_first(string)
          t = String.new(string)
          t[0] = t[0].upcase
          t
        end

        def generate_class(hierarchy, structure_def, top_level = false)
          type_name = structure_def['id']
          constrained_type = structure_def['type']
          path_type = type_name
          path_type = constrained_type if constrained_type

          template = FHIR::DSTU2::Boot::Template.new([type_name], top_level)
          template.hierarchy = hierarchy
          template.kind = structure_def['kind']
          return template if structure_def['snapshot'].nil? || structure_def['snapshot']['element'].nil?

          multiple_data_types = {}

          # examine the snapshot.elements... move the Element and BackboneElements,
          # and their children, into separate StructureDefiniton hashes and process as
          # child templates.
          child_templates = []
          structure_def['snapshot']['element'].each do |element|
            # skip the first element
            next if element['path'] == path_type
            next unless element['type']
            unique_types = element['type'].map { |t| t['code'] }.uniq
            if unique_types.include?('Element') || unique_types.include?('BackboneElement')
              child_templates << element['path']
            end
          end
          # now build the child templates...
          child_templates.each do |child_name|
            child_fixed_name = cap_first(child_name.gsub("#{type_name}.", ''))
            next if child_fixed_name.include?('.')
            child_def = { 'id' => child_fixed_name, 'snapshot' => { 'element' => [] } }
            # Copy the element definitions for the child structure
            structure_def['snapshot']['element'].each do |element|
              child_def['snapshot']['element'] << element.clone if element['path'].start_with?("#{child_name}.")
            end
            # Remove the child elements
            child_paths = child_def['snapshot']['element'].map { |e| e['path'] }
            # child_paths = child_paths.drop(1)
            structure_def['snapshot']['element'].keep_if do |element|
              !child_paths.include?(element['path'])
            end
            # Rename the child paths
            child_def['snapshot']['element'].each do |element|
              element['path'] = element['path'].gsub(child_name, child_fixed_name)
            end
            # add the child
            child_hierarchy = hierarchy + [child_fixed_name]
            child_klass = generate_class(child_hierarchy, child_def)
            template.templates << child_klass
            @templates << child_klass
          end

          # Process the remaining attributes (none of which are Elements or BackboneElements)
          structure_def['snapshot']['element'].each do |element|
            # skip the first element
            next if element['path'] == path_type

            field_base_name = element['path'].gsub("#{path_type}.", '')
            # If the element has a type, treat it as a datatype or resource
            # If not, treat it as a reference to an already declared internal class
            if !element['type'].nil?
              # profiles contains a list of profiles if the datatype is Reference or Extension
              profiles = []
              element['type'].select { |t| t['code'] == 'Reference' || t['code'] == 'Extension' }.each do |data_type|
                profiles << data_type['targetProfile']
              end
              profiles.reject!(&:nil?)
              profiles.flatten!

              # Calculate fields that have multiple data types
              if element['type'].length > 1
                fieldname = field_base_name.gsub('[x]', '')
                unique_types = element['type'].map { |t| t['code'] }.uniq
                multiple_data_types[fieldname] = unique_types if unique_types.length > 1
              end

              # generate a field for each valid datatype... this is for things like Resource.attribute[x]
              element['type'].map { |t| t['code'] }.uniq.each do |data_type|
                capitalized = cap_first(data_type)
                fieldname = field_base_name.gsub('[x]', capitalized)
                field = FHIR::DSTU2::Field.new(fieldname)
                field.path = element['path'].gsub(path_type, type_name)
                field.type = data_type
                field.type = 'Extension' if field.path.end_with?('extension')
                field.type_profiles = profiles if %w[Reference Extension].include?(datatype)
                field.min = element['min']
                field.max = element['max']
                field.max = field.max.to_i
                field.max = '*' if element['max'] == '*'

                if %w[code Coding CodeableConcept].include?(data_type) && element['binding']
                  field.binding = element['binding']
                  field.binding['uri'] = field.binding['valueSetUri']
                  field.binding['uri'] = field.binding['valueSetReference'] if field.binding['uri'].nil?
                  field.binding['uri'] = field.binding['uri']['reference'] if field.binding['uri'].is_a?(Hash)
                  field.binding.delete('valueSetUri')
                  field.binding.delete('valueSetReference')
                  field.binding.delete('description')
                  field.binding.delete('extension')
                  # set the actual code list
                  codes = @defn.get_codes(field.binding['uri'])
                  field.valid_codes = codes unless codes.nil?
                  if field.valid_codes.empty? && field.binding['uri'] && !field.binding['uri'].end_with?('bcp47') && !field.binding['uri'].end_with?('bcp13.txt')
                    FHIR::DSTU2.logger.warn "  MISSING EXPANSION -- #{field.path} #{field.min}..#{field.max}: #{field.binding['uri']} (#{field.binding['strength']})"
                    @missing_expansions = true
                    @missing_required_expansion = (field.binding['strength'] == 'required') unless @missing_required_expansion
                  end
                elsif %w[Element BackboneElement].include?(data_type)
                  # This is a nested structure or class
                  field.type = "#{hierarchy.join('::')}::#{cap_first(field.name)}"
                end

                template.fields << field
              end
            else # If there is no data type, treat the type as a reference to an already declared internal class
              field = FHIR::DSTU2::Field.new(field_base_name)
              field.path = element['path'].gsub(path_type, type_name)
              field.type = element['nameReference']
              field.type = field.type[1..-1] if field.type[0] == '#'
              hindex = hierarchy.index { |x| x.casecmp(field.type).zero? }
              if hindex
                # reference to self
                field.type = hierarchy[0..hindex].join('::').to_s
              else
                # reference to contained template
                klass = @templates.select { |x| x.hierarchy.last == field.type }.first
                field.type = if !klass.nil?
                               # the template/child class was declared somewhere else in this class hierarchy
                               klass.hierarchy.join('::')
                             else
                               # the template/child is a direct ancester (it isn't in @templates yet because it is being defined now)
                               indirect = @templates.find { |x| x.name.first.casecmp(field.type).zero? }
                               if indirect
                                 indirect.hierarchy.join('::')
                               else
                                 field.type.split('.').map { |x| cap_first(x) }.join('::')
                               end
                             end
              end
              field.min = element['min']
              field.max = element['max']
              field.max = field.max.to_i
              field.max = '*' if element['max'] == '*'
              template.fields << field
            end
          end

          template.constants['MULTIPLE_TYPES'] = multiple_data_types unless multiple_data_types.empty?
          template
        end
      end
    end
  end
end
