module LMRest
  class Resource
    attr_reader :attributes

    def initialize(properties)
      @attributes = {}

      properties.each do |key, value|
        @attributes[key.to_s] = value
      end
    end

    def [](key)
      @attributes[key.to_s]
    end

    def []=(key, value)
      @attributes[key.to_s] = value
    end

    def key?(key)
      @attributes.key?(key.to_s)
    end

    def to_h
      deep_copy(@attributes)
    end

    def method_missing(name, *args)
      attribute_name = name.to_s

      if attribute_name.end_with?('=')
        raise ArgumentError, "wrong number of arguments (#{args.count} for 1)" unless args.count == 1

        @attributes[attribute_name.delete_suffix('=')] = args.first
      elsif args.empty? && @attributes.key?(attribute_name)
        @attributes[attribute_name]
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      attribute_name = name.to_s

      attribute_name.end_with?('=') || @attributes.key?(attribute_name) || super
    end

    class << self

      def parse(body)
        case body
        when nil
          nil
        when Array
          parse_collection(body)
        when Hash
          if body.key?('items')
            parse_collection(body['items'] || [])
          else
            parse_object(body)
          end
        when String
          body
        else
          body
        end
      end

      def parse_collection(items)
        items.map do |item|
          item.is_a?(Hash) ? new(item) : item
        end
      end

      def parse_object(item)
        item.is_a?(Hash) ? new(item) : item
      end
    end

    private

    def deep_copy(value)
      case value
      when LMRest::Resource
        value.to_h
      when Hash
        value.each_with_object({}) do |(key, item), copied|
          copied[key] = deep_copy(item)
        end
      when Array
        value.map { |item| deep_copy(item) }
      else
        value
      end
    end
  end
end
