# frozen_string_literal: true

module Prelay
  module PostgresFullTextSearch
    extend ActiveSupport::Concern

    included do
      argument :text_search, :text, optional: true
    end
  end
end
