# frozen_string_literal: true

module Prelay
  module Subclassable
    class << self
      def extended(klass)
        klass.instance_variable_set(:@prelay_class, true)
      end
    end

    attr_reader :schema

    def inherited(subclass)
      super

      subclass.schema ||=
        if @prelay_class
          Prelay.primary_schema { raise DefinitionError, "Tried to subclass #{to_s} (#{subclass}) without first instantiating a Prelay::Schema for it to belong to!" }
        else
          s = self.schema
          self.schema = nil
          s
        end
    end

    def prelay_class
      @prelay_class ? self : superclass.prelay_class
    end

    def prelay_class_name
      prelay_class.to_s.split('::').last
    end

    def underscored_prelay_class_name
      prelay_class_name.gsub(/(.)([A-Z])/,'\1_\2').downcase
    end

    def schema=(s)
      pc = prelay_class
      @schema.objects.fetch(pc).delete(self) if @schema
      s.objects.fetch(pc) << self if s
      @schema = s
    end
  end
end
