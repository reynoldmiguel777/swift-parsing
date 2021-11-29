extension Parser where Input == Substring {
  /// Transforms the receiving parser on `Substring` into a parser on `Substring.UnicodeScalarView`.
  @inlinable
  public var unicodeScalars: Parsers.SubstringToUnicodeScalars<Self> {
    .init(upstream: self)
  }

  /// Transforms the receiving parser on `Substring` into a parser on `Substring.UTF8View`.
  @inlinable
  public var utf8: Parsers.SubstringToUTF8View<Self> {
    .init(upstream: self)
  }
}

extension Parser where Input == Substring.UnicodeScalarView {
  /// Transforms the receiving parser on `Substring.UnicodeScalarView` into a parser on
  /// `Substring.UTF8View`.
  @inlinable
  public var utf8: Parsers.UnicodeScalarViewToUTF8View<Self> {
    .init(upstream: self)
  }
}

extension Parsers {
  /// A parser that transforms a parser on `Substring` into a parser on
  /// `Substring.UnicodeScalarView`.
  ///
  /// You will not typically need to interact with this type directly. Instead you will usually use
  /// the ``Parser/unicodeScalars`` operation, which constructs this type.
  public struct SubstringToUnicodeScalars<Upstream>: Parser
  where
    Upstream: Parser,
    Upstream.Input == Substring
  {
    public let upstream: Upstream

    @inlinable
    public init(upstream: Upstream) {
      self.upstream = upstream
    }

    @inlinable
    public func parse(_ input: inout Substring.UnicodeScalarView) -> Upstream.Output? {
      var substring = Substring(input)
      defer { input = substring.unicodeScalars }
      return self.upstream.parse(&substring)
    }
  }

  /// A parser that transforms a parser on `Substring` into a parser on `Substring.UTF8View`.
  ///
  /// You will not typically need to interact with this type directly. Instead you will usually use
  /// the ``Parser/utf8-6e25a`` operation, which constructs this type.
  public struct SubstringToUTF8View<Upstream>: Parser
  where
    Upstream: Parser,
    Upstream.Input == Substring
  {
    public let upstream: Upstream

    @inlinable
    public init(upstream: Upstream) {
      self.upstream = upstream
    }

    @inlinable
    public func parse(_ input: inout Substring.UTF8View) -> Upstream.Output? {
      var substring = Substring(input)
      defer { input = substring.utf8 }
      return self.upstream.parse(&substring)
    }
  }

  /// A parser that transforms a parser on `Substring.UnicodeScalarView` into a parser on
  /// `Substring.UTF8View`.
  ///
  /// You will not typically need to interact with this type directly. Instead you will usually use
  /// the ``Parser/utf8-1tosc`` operation, which constructs this type.
  public struct UnicodeScalarViewToUTF8View<Upstream>: Parser
  where
    Upstream: Parser,
    Upstream.Input == Substring.UnicodeScalarView
  {
    public let upstream: Upstream

    @inlinable
    public init(upstream: Upstream) {
      self.upstream = upstream
    }

    @inlinable
    public func parse(_ input: inout Substring.UTF8View) -> Upstream.Output? {
      var unicodeScalars = Substring(input).unicodeScalars
      defer { input = Substring(unicodeScalars).utf8 }
      return self.upstream.parse(&unicodeScalars)
    }
  }

  public struct UTF8ViewToSubstring<UTF8ViewParser>: Parser
  where
    UTF8ViewParser: Parser,
    UTF8ViewParser.Input == Substring.UTF8View
  {
    public let utf8ViewParser: UTF8ViewParser

    @inlinable
    public init(_ utf8ViewParser: UTF8ViewParser) {
      self.utf8ViewParser = utf8ViewParser
    }

    @inlinable
    public func parse(_ input: inout Substring) -> UTF8ViewParser.Output? {
      self.utf8ViewParser.parse(&input.utf8)
    }
  }
}

extension Parsers.SubstringToUTF8View: Decodable where Upstream: Decodable {}
extension Parsers.SubstringToUTF8View: Encodable where Upstream: Encodable {}
extension Parsers.SubstringToUTF8View: Equatable where Upstream: Equatable {}
extension Parsers.SubstringToUTF8View: Hashable where Upstream: Hashable {}

extension Parsers.SubstringToUnicodeScalars: Decodable where Upstream: Decodable {}
extension Parsers.SubstringToUnicodeScalars: Encodable where Upstream: Encodable {}
extension Parsers.SubstringToUnicodeScalars: Equatable where Upstream: Equatable {}
extension Parsers.SubstringToUnicodeScalars: Hashable where Upstream: Hashable {}

extension Parsers.UnicodeScalarViewToUTF8View: Decodable where Upstream: Decodable {}
extension Parsers.UnicodeScalarViewToUTF8View: Encodable where Upstream: Encodable {}
extension Parsers.UnicodeScalarViewToUTF8View: Equatable where Upstream: Equatable {}
extension Parsers.UnicodeScalarViewToUTF8View: Hashable where Upstream: Hashable {}

extension Parsers.UTF8ViewToSubstring: Decodable where UTF8ViewParser: Decodable {}
extension Parsers.UTF8ViewToSubstring: Encodable where UTF8ViewParser: Encodable {}
extension Parsers.UTF8ViewToSubstring: Equatable where UTF8ViewParser: Equatable {}
extension Parsers.UTF8ViewToSubstring: Hashable where UTF8ViewParser: Hashable {}
