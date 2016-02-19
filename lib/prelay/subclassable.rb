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
          if s = SCHEMAS.first
            s
          else
            raise "Tried to subclass #{to_s} (#{subclass}) without first instantiating a Prelay::Schema for it to belong to!"
          end
        else
          s = self.schema
          self.schema = nil
          s
        end
    end

    def prelay_class
      if @prelay_class
        self
      else
        superclass.prelay_class
      end
    end

    def prelay_class_name
      prelay_class.to_s.split('::').last
    end

    def underscored_prelay_class_name
      prelay_class_name.gsub(/(.)([A-Z])/,'\1_\2').downcase
    end

    def schema=(s)
      set = underscored_prelay_class_name + '_set'
      @schema.send(set).delete(self) if @schema
      s.send(set) << self if s
      @schema = s
    end
  end
end
