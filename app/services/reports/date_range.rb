require "date"
require "time"

module Reports
  class DateRange
    class Invalid < StandardError; end
    attr_reader :from_at, :to_at

    def initialize(from:, to:)
      @from_at = parse(from)
      @to_at = parse(to)
      raise Invalid, "The from timestamp must be earlier than to." if
        @from_at && @to_at && @from_at >= @to_at
    end

    def self.positive_id(value)
      return nil if value.nil? || value.to_s.empty?
      raise Invalid, "Invalid ID filter." unless value.to_s.match?(/\A[1-9][0-9]*\z/)
      value.to_i
    end

    private

    def parse(value)
      return nil if value.nil? || value.to_s.empty?
      string = value.to_s
      if string.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        day = Date.iso8601(string)
        Time.utc(day.year, day.month, day.day)
      elsif string.match?(/\A\d{4}-\d{2}-\d{2}T.+(?:Z|[+-]\d{2}:\d{2})\z/)
        Time.iso8601(string).utc
      else
        raise Invalid, "Use YYYY-MM-DD or an ISO8601 datetime with UTC offset."
      end
    rescue Date::Error, ArgumentError
      raise Invalid, "Invalid ISO8601 date."
    end
  end
end
