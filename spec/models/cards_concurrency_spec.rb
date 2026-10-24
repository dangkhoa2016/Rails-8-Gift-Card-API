require "rails_helper"

# Data is created outside the per-example transaction so every thread's
# independent PostgreSQL connection can see it. Cleanup is explicit.
RSpec.describe "Real concurrent card operations" do
  before(:context) do
    @client = User.create!(email: "race-#{SecureRandom.hex(8)}@example.test",
      password: "race-test-password", role: :client, payout_rate: 90)
    @brand = Brand.create!(name: "Race test")
    @product = Product.create!(brand: @brand, name: "Race gift",
      face_value: 100, currency: "USD")
    ProductAccess.create!(client: @client, product: @product)
    @request = Struct.new(:remote_ip, :user_agent).new("127.0.0.1", "RSpec concurrency")
  end

  after(:context) do
    AuditEvent.where(actor_id: @client.id).delete_all
    Card.where(client_id: @client.id).delete_all
    ProductAccess.where(client_id: @client.id).delete_all
    @product&.destroy!
    @brand&.destroy!
    @client&.destroy!
  end

  def concurrent_call(count = 2)
    ready = Queue.new
    go = Queue.new
    results = Queue.new
    workers = Array.new(count) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          begin
            results << yield
          rescue => error
            results << error
          end
        end
      end
    end
    count.times { ready.pop }
    count.times { go << true }
    workers.each(&:join)
    count.times.map { results.pop }
  end

  it "serializes two real issuance threads to one committed card and one success audit" do
    key = "race-#{SecureRandom.hex(8)}"
    results = concurrent_call do
      Cards::Issue.call(client: User.find(@client.id), product_id: @product.id,
        with_pin: false, idempotency_key: key, request: @request)
    end
    expect(results).to all(be_a(Cards::Issue::Result))
    expect(results.map(&:created).sort_by(&:to_s)).to eq([ false, true ])
    expect(results.map { |r| r.card.id }.uniq.size).to eq(1)
    expect(Card.where(client_id: @client.id, idempotency_key: key).count).to eq(1)
    card_id = results.first.card.id
    expect(AuditEvent.where(action: "card.issued", record_id: card_id).count).to eq(1)
  end

  it "allows only one concurrent cancellation" do
    key = "cancel-race-#{SecureRandom.hex(8)}"
    issued = Cards::Issue.call(client: @client, product_id: @product.id,
      with_pin: false, idempotency_key: key, request: @request).card
    results = concurrent_call do
      Cards::Cancel.call(client: User.find(@client.id), card_id: issued.id, request: @request)
    end
    expect(results.count { |result| result.is_a?(Card) }).to eq(1)
    expect(results.count { |result| result.is_a?(Cards::Cancel::Refused) &&
      result.code == "already_cancelled" }).to eq(1)
    expect(issued.reload).to be_cancelled
    expect(AuditEvent.where(action: "card.cancelled", record_id: issued.id).count).to eq(1)
    expect(AuditEvent.where(action: "card.cancel_refused", record_id: issued.id).count).to eq(1)
  end
end
