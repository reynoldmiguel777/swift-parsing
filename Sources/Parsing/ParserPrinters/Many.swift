import Foundation

/// A parser that attempts to run another parser as many times as specified, accumulating the result
/// of the outputs.
///
/// For example, given a comma-separated string of numbers, one could parse out an array of
/// integers:
///
/// ```swift
/// var input = "1,2,3"[...]
/// let output = Many {
///   Int.parser()
/// } separator: {
///   ","
/// }.parse(&input)
/// precondition(input == "")
/// precondition(output == [1, 2, 3])
/// ```
///
/// The most general version of `Many` takes a closure that can customize how outputs accumulate,
/// much like `Sequence.reduce(into:_)`. We could, for example, sum the numbers as we parse them
/// instead of accumulating each value in an array:
///
/// ```
/// let sumParser = Many(into: 0, +=) {
///   Int.parser()
/// } separator: {
///   ","
/// }
/// var input = "1,2,3"[...]
/// let output = Many(Int.parser(), into: 0, separator: ",").parse(&input)
/// precondition(input == "")
/// precondition(output == 6)
/// ```
public struct Many<Element, Result, Separator>: Parser
where
  Element: Parser,
  Separator: Parser,
  Element.Input == Separator.Input
{
  public let element: Element
  public let initialResult: Result
  public let iterator: (Result) -> AnyIterator<Element.Output>
  public let maximum: Int
  public let minimum: Int
  public let separator: Separator
  public let updateAccumulatingResult: (inout Result, Element.Output) -> Void

  /// Initializes a parser that attempts to run the given parser at least and at most the given
  /// number of times, accumulating the outputs into a result with a given closure.
  ///
  /// - Parameters:
  ///   - initialResult: The value to use as the initial accumulating value.
  ///   - minimum: The minimum number of times to run this parser and consider parsing to be
  ///     successful.
  ///   - maximum: The maximum number of times to run this parser before returning the output.
  ///   - updateAccumulatingResult: A closure that updates the accumulating result with each output
  ///     of the element parser.
  ///   - iterator: An iterator that can iterate over the elements used to build up a result.
  ///   - element: A parser to run multiple times to accumulate into a result.
  ///   - separator: A parser that consumes input between each parsed output.
  @inlinable
  public init<Iterator>(
    into initialResult: Result,
    atLeast minimum: Int = 0,
    atMost maximum: Int = .max,
    _ updateAccumulatingResult: @escaping (inout Result, Element.Output) -> Void,
    iterator: @escaping (Result) -> Iterator,
    @ParserBuilder element: () -> Element,
    @ParserBuilder separator: () -> Separator
  ) where Iterator: IteratorProtocol, Iterator.Element == Element.Output {
    self.element = element()
    self.initialResult = initialResult
    self.iterator = { AnyIterator(iterator($0)) }
    self.maximum = maximum
    self.minimum = minimum
    self.separator = separator()
    self.updateAccumulatingResult = updateAccumulatingResult
  }

  /// Initializes a parser that attempts to run the given parser at least and at most the given
  /// number of times, accumulating the outputs into a result with a given closure.
  ///
  /// - Parameters:
  ///   - initialResult: The value to use as the initial accumulating value.
  ///   - minimum: The minimum number of times to run this parser and consider parsing to be
  ///     successful.
  ///   - maximum: The maximum number of times to run this parser before returning the output.
  ///   - updateAccumulatingResult: A closure that updates the accumulating result with each output
  ///     of the element parser.
  ///   - element: A parser to run multiple times to accumulate into a result.
  ///   - separator: A parser that consumes input between each parsed output.
  @inlinable
  public init(
    into initialResult: Result,
    atLeast minimum: Int = 0,
    atMost maximum: Int = .max,
    _ updateAccumulatingResult: @escaping (inout Result, Element.Output) -> Void,
    @ParserBuilder element: () -> Element,
    @ParserBuilder separator: () -> Separator
  ) {
    self.init(
      into: initialResult,
      atLeast: minimum,
      atMost: maximum,
      updateAccumulatingResult,
      iterator: { _ in AnyIterator { nil } },
      element: element,
      separator: separator
    )
  }

  @inlinable
  public func parse(_ input: inout Element.Input) throws -> Result {
    let original = input
    var rest = input
    #if DEBUG
      var previous = input
    #endif
    var result = self.initialResult
    var count = 0
    while count < self.maximum, let output = try? self.element.parse(&input) {
      #if DEBUG
        defer { previous = input }
      #endif
      count += 1
      self.updateAccumulatingResult(&result, output)
      rest = input
      do {
        _ = try self.separator.parse(&input)
      } catch {
        break
      }
      #if DEBUG
        if memcmp(&input, &previous, MemoryLayout<Element.Input>.size) == 0 {
          var description = ""
          debugPrint(output, terminator: "", to: &description)
          breakpoint(
            """
            ---
            A "Many" parser succeeded in parsing a value of "\(Element.Output.self)" \
            (\(description)), but no input was consumed.

            This is considered a logic error that leads to an infinite loop, and is typically \
            introduced by parsers that always succeed, even though they don't consume any input. \
            This includes "Prefix" and "CharacterSet" parsers, which return an empty string when \
            their predicate immediately fails.

            To work around the problem, require that some input is consumed (for example, use \
            "Prefix(minLength: 1)"), or introduce a "separator" parser to "Many".
            ---
            """
          )
        }
      #endif
    }
    guard count >= self.minimum else {
      input = original
      throw ParsingError()
    }
    input = rest
    return result
  }
}

extension Many: Printer
where
  Element: Printer,
  Separator: Printer,
  Separator.Output == Void
{
  @inlinable
  public func print(_ output: Result, to input: inout Input) throws {
    let original = input
    let iterator = self.iterator(output)
    guard let first = iterator.next() else { throw ParsingError() } // TODO: return self.minimum == 0 ? input : nil
    try self.element.print(first, to: &input)

    var count = 1

    while let element = iterator.next() {
      let rest = input

      try self.separator.print(to: &input)
      do {
        try self.element.print(element, to: &input)
      } catch {
        input = rest
        return
      }

      count += 1

      guard count <= self.maximum
      else {
        input = original
        throw ParsingError()
      }
    }

    guard count >= self.minimum
    else {
      input = original
      throw ParsingError()
    }
  }
}

extension Many where Separator == Always<Input, Void> {
  /// Initializes a parser that attempts to run the given parser at least and at most the given
  /// number of times, accumulating the outputs into a result with a given closure.
  ///
  /// - Parameters:
  ///   - initialResult: The value to use as the initial accumulating value.
  ///   - minimum: The minimum number of times to run this parser and consider parsing to be
  ///     successful.
  ///   - maximum: The maximum number of times to run this parser before returning the output.
  ///   - updateAccumulatingResult: A closure that updates the accumulating result with each output
  ///     of the element parser.
  ///   - iterator: An iterator that can iterate over the elements used to build up a result.
  ///   - element: A parser to run multiple times to accumulate into a result.
  @inlinable
  public init<Iterator>(
    into initialResult: Result,
    atLeast minimum: Int = 0,
    atMost maximum: Int = .max,
    _ updateAccumulatingResult: @escaping (inout Result, Element.Output) -> Void,
    iterator: @escaping (Result) -> Iterator,
    @ParserBuilder element: () -> Element
  ) where Iterator: IteratorProtocol, Iterator.Element == Element.Output {
    self.element = element()
    self.initialResult = initialResult
    self.iterator = { AnyIterator(iterator($0)) }
    self.maximum = maximum
    self.minimum = minimum
    self.separator = .init(())
    self.updateAccumulatingResult = updateAccumulatingResult
  }

  /// Initializes a parser that attempts to run the given parser at least and at most the given
  /// number of times, accumulating the outputs into a result with a given closure.
  ///
  /// - Parameters:
  ///   - initialResult: The value to use as the initial accumulating value.
  ///   - minimum: The minimum number of times to run this parser and consider parsing to be
  ///     successful.
  ///   - maximum: The maximum number of times to run this parser before returning the output.
  ///   - updateAccumulatingResult: A closure that updates the accumulating result with each output
  ///     of the element parser.
  ///   - element: A parser to run multiple times to accumulate into a result.
  @inlinable
  public init(
    into initialResult: Result,
    atLeast minimum: Int = 0,
    atMost maximum: Int = .max,
    _ updateAccumulatingResult: @escaping (inout Result, Element.Output) -> Void,
    @ParserBuilder element: () -> Element
  ) {
    self.init(
      into: initialResult,
      atLeast: minimum,
      atMost: maximum,
      updateAccumulatingResult,
      iterator: { _ in AnyIterator { nil } },
      element: element
    )
  }
}

extension Many where Result == [Element.Output] {
  /// Initializes a parser that attempts to run the given parser at least and at most the given
  /// number of times, accumulating the outputs in an array.
  ///
  /// - Parameters:
  ///   - minimum: The minimum number of times to run this parser and consider parsing to be
  ///     successful.
  ///   - maximum: The maximum number of times to run this parser before returning the output.
  ///   - element: A parser to run multiple times to accumulate into an array.
  ///   - separator: A parser that consumes input between each parsed output.
  @inlinable
  public init(
    atLeast minimum: Int = 0,
    atMost maximum: Int = .max,
    @ParserBuilder element: () -> Element,
    @ParserBuilder separator: () -> Separator
  ) {
    self.init(
      into: [],
      atLeast: minimum,
      atMost: maximum,
      { $0.append($1) },
      iterator: { $0.makeIterator() },
      element: element,
      separator: separator
    )
  }
}

extension Many where Result == [Element.Output], Separator == Always<Input, Void> {
  /// Initializes a parser that attempts to run the given parser at least and at most the given
  /// number of times, accumulating the outputs in an array.
  ///
  /// - Parameters:
  ///   - minimum: The minimum number of times to run this parser and consider parsing to be
  ///     successful.
  ///   - maximum: The maximum number of times to run this parser before returning the output.
  ///   - element: A parser to run multiple times to accumulate into an array.
  @inlinable
  public init(
    atLeast minimum: Int = 0,
    atMost maximum: Int = .max,
    @ParserBuilder element: () -> Element
  ) {
    self.init(
      into: [],
      atLeast: minimum,
      atMost: maximum,
      { $0.append($1) },
      iterator: { $0.makeIterator() },
      element: element
    )
  }
}

extension Parsers {
  public typealias Many = Parsing.Many  // NB: Convenience type alias for discovery
}
