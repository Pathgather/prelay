# frozen_string_literal: true

module SchemaMocking
  def schema
    @schema || PrelaySpec::SCHEMA
  end

  def self.included(base)
    base.extend Module.new {
      def mock_schema(&block)
        prepend Module.new {
          define_method :setup do
            @schema = Prelay::Schema.new(temporary: true)
            SchemaMocker.new(@schema).instance_eval(&block)
            super()
          end
        }
      end
    }
  end

  class SchemaMocker
    def initialize(schema)
      @schema = schema
    end

    def type(name, &block)
      mock(:Type, name, definition: block) do |c|
        c.model(Kernel.const_get("::#{name}", false))
      end
    end

    def interface(name, &block)
      mock(:Interface, name, definition: block)
    end

    def query(name, &block)
      mock(:Query, name, definition: block)
    end

    def mutation(name, &block)
      mock(:Mutation, name, definition: block)
    end

    private

    def mock(meth, name, definition:, &block)
      superclass = Prelay.method(meth).call(schema: @schema)
      c = Class.new(superclass)
      c.name(name.to_s)
      yield c if block_given?
      c.class_eval(&definition)
      c
    end
  end
end
