module Cards
  # Ownership is always scoped first; the caller supplies only query parameters.
  class ListQuery
    SORT_COLUMNS = {
      "activation_number" => [ "cards.activation_number" ],
      "product" => [ "LOWER(products.name)", "LOWER(brands.name)" ],
      "face_value" => [ "cards.face_value_snapshot", "cards.currency_snapshot" ],
      "payout" => [ "cards.payout_amount_snapshot", "cards.currency_snapshot" ],
      "status" => [ "cards.status" ],
      "has_pin" => [ "(cards.pin IS NOT NULL)" ]
    }.freeze

    def initialize(client:, filters:)
      @client = client
      @filters = filters
    end

    def call
      scope = @client.cards.includes(product: :brand)
      scope = apply_search(scope)
      scope = scope.where(status: @filters["status"]) if %w[issued cancelled].include?(@filters["status"])
      scope = apply_pin_filter(scope)
      apply_sort(scope)
    end

    private

    def apply_search(scope)
      return scope unless @filters.key?("q")
      query = @filters["q"]
      unless query.is_a?(String) && query.length <= 100
        raise Api::InvalidFilter, "Search must be a text value of up to 100 characters."
      end
      return scope if query.strip.empty?

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query.strip.downcase)}%"
      scope.joins(product: :brand).where(
        "LOWER(cards.activation_number) LIKE :pattern OR " \
        "LOWER(products.name) LIKE :pattern OR " \
        "LOWER(brands.name) LIKE :pattern", pattern: pattern)
    end

    def apply_pin_filter(scope)
      return scope unless @filters.key?("has_pin")
      case @filters["has_pin"]
      when "true" then scope.where.not(pin: nil)
      when "false" then scope.where(pin: nil)
      else
        raise Api::InvalidFilter, "has_pin must be true or false."
      end
    end

    def apply_sort(scope)
      sort_by = @filters["sort_by"]
      sort_dir = @filters["sort_dir"]
      return scope.order(id: :desc) if sort_by.nil? && sort_dir.nil?

      unless sort_by.is_a?(String) && SORT_COLUMNS.key?(sort_by) &&
          (sort_dir.nil? || %w[asc desc].include?(sort_dir))
        raise Api::InvalidFilter, "Unsupported Card sort column or direction."
      end
      scope = scope.joins(product: :brand) if sort_by == "product"
      direction = (sort_dir || "asc").upcase
      columns = SORT_COLUMNS.fetch(sort_by).map { |column| "#{column} #{direction}" }
      scope.reorder(Arel.sql((columns + [ "cards.id DESC" ]).join(", ")))
    end
  end
end
