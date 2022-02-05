public struct Route<RouteParser, Route>: Parser
where
  RouteParser: Parser,
  RouteParser.Input == URLRequestData
{
  // TODO: Generalize to any conversion.
  @usableFromInline
  let parser: Parsers.MapConversion<RouteParser, CasePath<Route, RouteParser.Output>>

  @inlinable
  public init(
    _ route: CasePath<Route, RouteParser.Output>,
    @ParserBuilder to parser: () -> RouteParser
  ) {
    self.parser = parser().map(route)
  }

  @inlinable
  public init(
    _ route: CasePath<Route, RouteParser.Output>
  ) where RouteParser == Always<URLRequestData, Void> {
    self.init(route) {
      Always<URLRequestData, Void>(())
    }
  }

  @inlinable
  public func parse(_ input: inout URLRequestData) throws -> Route {
    let output = try self.parser.parse(&input)
    if input.method != nil {
      try Method.get.parse(&input)
    }
    try End().parse(input.path)
    return output
  }
}

extension Route: Printer where RouteParser: Printer {
  @inlinable
  public func print(_ output: Route, to input: inout URLRequestData) rethrows {
    try self.parser.print(output, to: &input)
  }
}
