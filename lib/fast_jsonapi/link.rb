# frozen_string_literal: true

module FastJsonapi
  class Link
    attr_reader :key, :method

    def initialize(key:, method:)
      @key = key
      @method = method
    end

    def serialize(record, serialization_params, output_hash)
      output_hash[key] = if method.is_a?(::Proc)
                           original_arity = method.arity
                           if original_arity < 0
                             # In case Lambda with optional params
                             full_args = [record, serialization_params, output_hash]
                             method.call(*full_args[0..(original_arity.abs-1)])
                           elsif original_arity.zero?
                             method.call
                           elsif original_arity == 1
                             method.call(record)
                           elsif original_arity == 2
                             method.call(record, serialization_params)
                           elsif original_arity == 3
                             method.call(record, serialization_params, output_hash)
                           else
                             fail(::RuntimeError.new("#{method.to_s} arity(=#{method.arity}) in #{method&.source_location} is > 3"))
                           end

                         else
                           record.public_send(method)
                         end
    end
  end
end
