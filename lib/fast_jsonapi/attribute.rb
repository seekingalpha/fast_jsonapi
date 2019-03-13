# frozen_string_literal: true

module FastJsonapi
  class Attribute
    attr_reader :key, :method, :conditional_proc

    def initialize(key:, method:, options: ::FastJsonapi::Consts::EMPTY_HASH)
      @key = key
      @method = method
      @conditional_proc = options[:if]
    end

    def serialize(record, serialization_params, output_hash)
      if include_attribute?(record, serialization_params)
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

    def include_attribute?(record, serialization_params)
      if conditional_proc.present?
        conditional_proc.call(record, serialization_params)
      else
        true
      end
    end
  end
end
