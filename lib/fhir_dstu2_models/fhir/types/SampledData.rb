module FHIR
  module DSTU2
    class SampledData < FHIR::DSTU2::Model
      include FHIR::DSTU2::Hashable
      include FHIR::DSTU2::Json
      include FHIR::DSTU2::Xml

      SEARCH_PARAMS = 
      METADATA = {
        'id' => {'type'=>'id', 'path'=>'SampledData.id', 'min'=>0, 'max'=>1},
        'extension' => {'type'=>'Extension', 'path'=>'SampledData.extension', 'min'=>0, 'max'=>Float::INFINITY},
        'origin' => {'type'=>'Quantity', 'path'=>'SampledData.origin', 'min'=>1, 'max'=>1},
        'period' => {'type'=>'decimal', 'path'=>'SampledData.period', 'min'=>1, 'max'=>1},
        'factor' => {'type'=>'decimal', 'path'=>'SampledData.factor', 'min'=>0, 'max'=>1},
        'lowerLimit' => {'type'=>'decimal', 'path'=>'SampledData.lowerLimit', 'min'=>0, 'max'=>1},
        'upperLimit' => {'type'=>'decimal', 'path'=>'SampledData.upperLimit', 'min'=>0, 'max'=>1},
        'dimensions' => {'type'=>'positiveInt', 'path'=>'SampledData.dimensions', 'min'=>1, 'max'=>1},
        'data' => {'type'=>'string', 'path'=>'SampledData.data', 'min'=>1, 'max'=>1}
      }

      attr_accessor :id         # 0-1 id
      attr_accessor :extension  # 0-* [ Extension ]
      attr_accessor :origin     # 1-1 Quantity
      attr_accessor :period     # 1-1 decimal
      attr_accessor :factor     # 0-1 decimal
      attr_accessor :lowerLimit # 0-1 decimal
      attr_accessor :upperLimit # 0-1 decimal
      attr_accessor :dimensions # 1-1 positiveInt
      attr_accessor :data       # 1-1 string
    end
  end
end