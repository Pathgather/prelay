# frozen_string_literal: true

module DefaultSpecSchema
  def schema
    PrelaySpec::SCHEMA
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
