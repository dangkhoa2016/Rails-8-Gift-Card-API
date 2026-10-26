# Rails dispatches routing and unhandled API exceptions here, not through an
# authenticated controller. Never use the Rails development traceback response
# for API clients, including the public Cloudflare demo.
module Wogi
  class ApiExceptionsApp
    SAFE_MESSAGES = {
      400 => [ "bad_request", "The request could not be processed. Check the inputs and try again." ],
      404 => [ "route_not_found", "API endpoint not found. Check the request path and try again." ],
      405 => [ "method_not_allowed", "This API endpoint does not support that HTTP method." ],
      406 => [ "not_acceptable", "The requested response format is not supported." ],
      422 => [ "invalid_request", "Some request values could not be processed." ]
    }.freeze

    def call(env)
      request = ActionDispatch::Request.new(env)
      # ActionDispatch::ShowExceptions rewrites PATH_INFO to /404 or /500.
      original_path = env["action_dispatch.original_path"] || request.path
      unless original_path.start_with?("/api/v1/")
        return ActionDispatch::PublicExceptions.new(Rails.public_path).call(env)
      end

      exception = env["action_dispatch.exception"]
      status = exception ? ActionDispatch::ExceptionWrapper.status_code_for_exception(exception.class.name) : 500
      code, message = SAFE_MESSAGES.fetch(status, [ "internal_error", "Something went wrong. Please try again later." ])
      if status == 404 && exception && !exception.is_a?(ActionController::RoutingError)
        code = "not_found"
        message = "The requested record could not be found."
      end
      request_id = request.request_id
      body = { error: { code: code, message: message }, request_id: request_id }
      if debug_details_enabled? && exception
        body[:error][:details] = {
          exception_class: exception.class.name,
          exception_message: sanitize(exception.message).slice(0, 500),
          backtrace: Array(exception.backtrace).first(15).map { |line| sanitize(line).slice(0, 450) }
        }
      end
      [ status, { "content-type" => "application/json; charset=utf-8",
        "cache-control" => "no-store, private", "x-request-id" => request_id.to_s }, [ JSON.generate(body) ] ]
    end

    private

    def debug_details_enabled?
      !Rails.env.production? && ENV["WOGI_SHOW_EXCEPTION_DETAILS"] == "true"
    end

    def sanitize(text)
      text.to_s
        .gsub(/Bearer\s+[A-Za-z0-9._-]+/i, "Bearer [FILTERED]")
        .gsub(/((?:password|pin|access_token|jwt|secret|authorization)\s*[=:]\s*)[^\s&"']+/i, '\\1[FILTERED]')
    end
  end
end
