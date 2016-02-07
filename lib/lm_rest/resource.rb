class LMRest
  class Resource < OpenStruct
    def create(type, properties)
      Object.const_get(type.to_s.capitalize).new(properties)
    end
  end
end
