# frozen_string_literal: true

module DefaultSpecSchema
  def self.included(base)
    base.extend ClassMethods
  end

  class SchemaMocker
    def initialize(schema)
      @schema = schema
    end

    def type(name, &block)
      superclass = Prelay::Type(schema: @schema)
      c = Class.new(superclass)
      c.name(name.to_s)
      c.model(Kernel.const_get("::#{name}", false))
      c.class_eval(&block)
    end

    def mutation(name, &block)
      superclass = Prelay::Mutation(schema: @schema)
      c = Class.new(superclass)
      c.name(name.to_s)
      c.class_eval(&block)
    end
  end

  module ClassMethods
    def mock_schema(&block)
      before do
        @schema = Prelay::Schema.new(temporary: true)
        SchemaMocker.new(@schema).instance_eval(&block)
      end
    end
  end

  def schema
    @schema || PrelaySpec::SCHEMA
  end

  def mock(thing, schema: Prelay::Schema.new(temporary: true), &block)
    superclass =
      case thing
      when :type      then Prelay::Type(schema: schema)
      when :interface then Prelay::Interface(schema: schema)
      when :query     then Prelay::Query(schema: schema)
      when :mutation  then Prelay::Mutation(schema: schema)
      else raise "Unmockable thing! #{thing.inspect}"
      end

    c = Class.new(superclass)
    c.class_eval(&block)
    c
  end
end
