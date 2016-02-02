# frozen_string_literal: true

module Prelay
  module PostgresFullTextSearch
    def self.included(base)
      base.argument :text_search, :text, optional: true
    end
  end
end
