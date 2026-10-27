module Cards
  # Consistent business rejection shape for card issuance and cancellation.
  class Refused < StandardError
    attr_reader :code, :http_status

    def initialize(code, http_status: :unprocessable_content)
      @code = code
      @http_status = http_status
      super(code.tr("_", " "))
    end
  end
end
