module ProgrammeSync
  module Errors
    Error = Class.new(StandardError)

    # The upstream API didnot answer within the timeout window
    TimeoutError = Class.new(Error)

    # Network failure reaching the upstream API.
    ConnectionError = Class.new(Error)

    # The upstream API answered but with a 5xx code
    ServerError = Class.new(Error)

    # The upstream API answered with something we dont know how to handle
    UnexpectedResponseError = Class.new(Error)
  end
end
