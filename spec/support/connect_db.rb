# frozen_string_literal: true

DB = Sequel.connect(ENV['DATABASE_URL'] || 'postgres:///prelay-test')

DB.extension :pg_json

# Check that we don't request the same column multiple times.
DB.extension :duplicate_columns_handler
DB.opts[:on_duplicate_columns] = :raise

# Simple way to spec what queries are being run.
logger = Object.new

def logger.info(sql)
  if Thread.current[:track_sqls] && q = sql[/\(\d\.[\d]{6}s\) (.+)/, 1]
    Thread.current[:sqls] << q
  end
end

def logger.error(msg)
  puts msg
end

DB.loggers << logger
