# frozen_string_literal: true

class Genre < Sequel::Model
  one_to_many :artists
end

class Artist < Sequel::Model
  many_to_one :genre
  one_to_many :albums,       order: Sequel.desc(:release_date)
  one_to_many :compilations, order: Sequel.desc(:release_date)

  def releases
    (albums + compilations).sort_by(&:release_date).reverse
  end
end

class Album < Sequel::Model
  many_to_one :artist
  one_to_many :tracks, order: :number
  one_to_one :publisher

  one_to_one  :first_track,       class_name: :Track,                 &:is_first
  one_to_many :first_five_tracks, class_name: :Track, order: :number, &:in_first_five
end

class Compilation < Sequel::Model
  many_to_one :artist
  one_to_many :tracks, order: :number
  one_to_one :publisher

  one_to_one  :first_track,       class_name: :Track,                 &:is_first
  one_to_many :first_five_tracks, class_name: :Track, order: :number, &:in_first_five
end

class Track < Sequel::Model
  many_to_one :album
  many_to_one :compilation

  subset :is_first,      number: 1
  subset :in_first_five, number: 1..5

  def release
    album || compilation
  end
end

class Publisher < Sequel::Model
  many_to_one :album
end
