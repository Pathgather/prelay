puts "Populating Prelay Test DB..."

random_json_doc = random_json_value = nil

random_json_value = -> {
  case rand
  when 0.00..0.30 then rand 100000                                  # Integer
  when 0.30..0.60 then Faker::Lorem.sentence                        # String
  when 0.60..0.70 then rand > 0.5                                   # Boolean
  when 0.70..0.80 then rand * 10000                                 # Float
  when 0.80..0.90 then nil                                          # Null
  when 0.90..0.95 then rand(4).times.map { random_json_value.call } # Array (uncommon)
  when 0.95..1.00 then random_json_doc.call                         # Doc (uncommon)
  else raise "Oops!"
  end
}

random_json_doc = -> {
  output = {}
  Faker::Lorem.words(rand(6)).each do |word|
    output[word.downcase] = random_json_value.call
  end
  output
}

genre_ids = DB[:genres].multi_insert(
  Faker::Lorem.words(5).map { |word|
    {
      name: word
    }
  },
  return: :primary_key
)

artist_ids = DB[:artists].multi_insert(
  15.times.map {
    {
      genre_id:   (genre_ids.sample if rand > 0.5),
      first_name: Faker::Name.first_name,
      last_name:  Faker::Name.last_name,
      upvotes:    rand(10000),
      active:     rand > 0.5,
      popularity: rand,
      birth_date: Date.today - (7200 + rand(20000)),
      money_made: (rand * 1000000).round(2),
      other:      Sequel.pg_jsonb(random_json_doc.call),
      created_at: Time.now - (rand(1000) * 24 * 60 * 60),
    }
  },
  return: :primary_key
)

album_ids = DB[:albums].multi_insert(
  artist_ids.map { |artist_id|
    # We should be appending the pk of the table to the order by to ensure a
    # stable sort, but until we work that out, make sure our release dates are all
    # unique to avoid intermittently failing specs.
    release_dates = 20.times.map{Date.today - (7200 + rand(20000))}.uniq

    10.times.map { |i|
      {
        artist_id:    artist_id,
        name:         Faker::Lorem.sentence,
        upvotes:      rand(10000),
        high_quality: rand > 0.9,
        popularity:   rand,
        release_date: release_dates[i],
        money_made:   (rand * 100000).round(2),
        other:        Sequel.pg_jsonb(random_json_doc.call),
        created_at:   Time.now - (rand(1000) * 24 * 60 * 60),
      }
    }
  }.flatten(1),
  return: :primary_key
)

compilation_ids = DB[:compilations].multi_insert(
  artist_ids.map { |artist_id|
    # We should be appending the pk of the table to the order by to ensure a
    # stable sort, but until we work that out, make sure our release dates are all
    # unique to avoid intermittently failing specs.
    release_dates = 20.times.map{Date.today - (7200 + rand(20000))}.uniq

    5.times.map { |i|
      {
        artist_id:    artist_id,
        name:         Faker::Lorem.sentence,
        upvotes:      rand(10000),
        high_quality: rand > 0.9,
        popularity:   rand,
        release_date: release_dates[i],
        money_made:   (rand * 100000).round(2),
        other:        Sequel.pg_jsonb(random_json_doc.call),
        created_at:   Time.now - (rand(1000) * 24 * 60 * 60),
      }
    }
  }.flatten(1),
  return: :primary_key
)

release_ids = album_ids.map{|id| [:album, id]} + compilation_ids.map{|id| [:compilation, id]}

track_ids = DB[:tracks].multi_insert(
  release_ids.map { |type, id|
    10.times.map { |i|
      {
        release_id:     id,
        album_id:       (id if type == :album),
        compilation_id: (id if type == :compilation),
        name:           Faker::Lorem.sentence,
        number:         i + 1,
        high_quality:   rand > 0.9,
        popularity:     rand,
        single_date:    Date.today - rand(1000),
        money_made:     (rand * 10000).round(2),
        other:          Sequel.pg_jsonb(random_json_doc.call),
        created_at:     Time.now - (rand(1000) * 24 * 60 * 60),
      }
    }
  }.flatten(1),
  return: :primary_key
)

publisher_ids = DB[:publishers].multi_insert(
  album_ids.map { |album_id|
    {
      album_id: album_id,
      name:     Faker::Company.name
    }
  },
  return: :primary_key
)
