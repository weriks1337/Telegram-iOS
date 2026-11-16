import Foundation

public enum FilterError: Error, Equatable {
    case patternTooLong
    case tooManyPatterns
    case invalidPattern(String)
}

/// Regex filtering for locally displayed text only. Patterns are user supplied and matching is disabled by default.
/// Input limits reduce, but cannot mathematically eliminate, pathological-regex CPU use in ICU.
public struct RegexFilterEngine: Sendable {
    public static let maximumPatternLength = 256
    public static let maximumPatternCount = 64
    public static let maximumTextLength = 8_192

    private let expressions: [NSRegularExpression]

    public init(patterns: [String], caseInsensitive: Bool = true) throws {
        guard patterns.count <= Self.maximumPatternCount else { throw FilterError.tooManyPatterns }
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive, .anchorsMatchLines] : [.anchorsMatchLines]
        var compiled: [NSRegularExpression] = []
        for pattern in patterns {
            guard pattern.count <= Self.maximumPatternLength else { throw FilterError.patternTooLong }
            do {
                compiled.append(try NSRegularExpression(pattern: pattern, options: options))
            } catch {
                throw FilterError.invalidPattern(pattern)
            }
        }
        expressions = compiled
    }

    public func matches(_ text: String) -> Bool {
        let bounded = String(text.prefix(Self.maximumTextLength))
        let range = NSRange(bounded.startIndex..<bounded.endIndex, in: bounded)
        return expressions.contains { $0.firstMatch(in: bounded, range: range) != nil }
    }
}
