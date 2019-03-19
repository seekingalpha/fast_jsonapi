# frozen_string_literal: true

module FastJsonapi
  class BaseField
    attr_reader :key, :method, :conditional_proc, :arity

    def initialize(key:, method:, options: ::FastJsonapi::Consts::EMPTY_HASH)
      @key              = key
      @method           = method
      @conditional_proc = options[:if]
      @arity            = if method.is_a?(::Proc)
                            method.arity
                          end
    end

    def serialize(record, serialization_params, output_hash)
      is_enabled = @conditional_proc == nil || @conditional_proc.call(record, serialization_params)

      if is_enabled
        output_hash[key] =
            if @method.is_a?(::Proc)
              if @arity < 0
                full_args = [record, serialization_params, output_hash]
                @method.call(*full_args[0..(@arity.abs - 1)])
              elsif @arity.zero?
                @method.call
              elsif @arity == 1
                @method.call(record)
              elsif @arity == 2
                @method.call(record, serialization_params)
              elsif @arity >= 3
                @method.call(record, serialization_params, output_hash)
              end
            else
              record.public_send(method)
            end
      end
    end
  end
end
