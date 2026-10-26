module Reports
  class ActivitySummary
    # Report SQL never interpolates request values or dynamic column names.
    # Grouping and date filters are supplied as PostgreSQL bind parameters.
    QUERY = <<~SQL.freeze
      WITH ledger AS (
        SELECT client_id, product_id, currency_snapshot AS currency,
          issued_at AS occurred_at, 1 AS issued_count, 0 AS cancelled_count,
          face_value_snapshot AS issued_face_value, 0::numeric AS cancelled_face_value,
          payout_amount_snapshot AS issued_payout, 0::numeric AS cancelled_payout
        FROM cards
        UNION ALL
        SELECT client_id, product_id, currency_snapshot AS currency,
          cancelled_at AS occurred_at, 0 AS issued_count, 1 AS cancelled_count,
          0::numeric AS issued_face_value, face_value_snapshot AS cancelled_face_value,
          0::numeric AS issued_payout, payout_amount_snapshot AS cancelled_payout
        FROM cards WHERE cancelled_at IS NOT NULL
      )
      SELECT
        CASE
          WHEN $1::text = 'brand' THEN products.brand_id
          WHEN $1::text = 'client' THEN ledger.client_id
          ELSE NULL::bigint
        END AS group_id,
        ledger.currency,
        SUM(ledger.issued_count)::integer AS issued_count,
        SUM(ledger.cancelled_count)::integer AS cancelled_count,
        SUM(ledger.issued_face_value) AS issued_face_value,
        SUM(ledger.cancelled_face_value) AS cancelled_face_value,
        SUM(ledger.issued_face_value - ledger.cancelled_face_value) AS net_spending,
        SUM(ledger.issued_payout) AS issued_payout,
        SUM(ledger.cancelled_payout) AS cancelled_payout,
        SUM(ledger.issued_payout - ledger.cancelled_payout) AS net_payout_activity
      FROM ledger
      JOIN products ON products.id = ledger.product_id
      WHERE ($2::timestamp IS NULL OR ledger.occurred_at >= $2::timestamp)
        AND ($3::timestamp IS NULL OR ledger.occurred_at < $3::timestamp)
        AND ($4::bigint IS NULL OR ledger.client_id = $4::bigint)
        AND ($5::bigint IS NULL OR products.brand_id = $5::bigint)
      GROUP BY group_id, ledger.currency
      ORDER BY group_id, ledger.currency
    SQL

    def initialize(group:, date_range:, client_id: nil, brand_id: nil)
      raise ArgumentError, "unsupported group" unless %i[brand client personal].include?(group)
      @group = group
      @range = date_range
      @client_id = client_id
      @brand_id = brand_id
    end

    def call
      binds = [
        bind("report_group", @group.to_s, ActiveRecord::Type::String.new),
        bind("from_at", @range.from_at, ActiveRecord::Type::DateTime.new),
        bind("to_at", @range.to_at, ActiveRecord::Type::DateTime.new),
        bind("client_id", @client_id, ActiveRecord::Type::Integer.new),
        bind("brand_id", @brand_id, ActiveRecord::Type::Integer.new)
      ]
      key = { brand: "brand_id", client: "client_id", personal: nil }.fetch(@group)
      rows = ActiveRecord::Base.connection.exec_query(QUERY, "Activity summary", binds).to_a
      rows.each do |row|
        if key
          row[key] = row.delete("group_id")
        else
          row.delete("group_id")
        end
      end
      # Decorate group identifiers using one lookup per report; monetary SQL is unchanged.
      if @group == :brand
        names = Brand.where(id: rows.map { |row| row["brand_id"] }).pluck(:id, :name).to_h
        rows.each { |row| row["brand_name"] = names[row["brand_id"]] }
      elsif @group == :client
        names = User.where(id: rows.map { |row| row["client_id"] }).pluck(:id, :email).to_h
        rows.each { |row| row["client_email"] = names[row["client_id"]] }
      end
      rows
    end

    private

    def bind(name, value, type)
      ActiveRecord::Relation::QueryAttribute.new(name, value, type)
    end
  end
end
