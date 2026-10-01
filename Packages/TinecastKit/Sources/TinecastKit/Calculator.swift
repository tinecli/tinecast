import Foundation

public struct Calculation: Equatable, Sendable {
    public let expression: String
    public let display: String
    public let raw: String
}

public func calculate(_ query: String, rates: [String: Double], localCurrency: String?, locale: Locale) -> Calculation? {
    guard let tokens = try? tokenize(query), !tokens.isEmpty else { return nil }
    var parser = Parser(tokens: tokens, rates: rates.merging(["EUR": 1]) { current, _ in current })
    guard let (operand, target) = try? parser.query() else { return nil }
    let value = operand.quantity.plain
    let local = localCurrency ?? "EUR"
    let implicitTarget: Target? = if !parser.isBareLiteral {
        nil
    } else if case .money(_, let code) = value, code != local {
        .currency(local)
    } else if case .money = value {
        .currency(local == "EUR" ? "USD" : "EUR")
    } else {
        nil
    }
    guard !parser.isBareLiteral || implicitTarget != nil,
          let result = try? (target ?? implicitTarget).map({ try parser.convert(value, to: $0) }) ?? value,
          result.magnitude.isFinite
    else { return nil }
    let (display, raw) = format(result, locale: locale)
    return Calculation(expression: operand.text + (implicitTarget.map { " in \($0.name)" } ?? ""), display: display, raw: raw)
}

private struct CalculationError: Error {}

private enum Token: Equatable {
    case number(Double, text: String)
    case word(String)
    case symbol(Character)
    case currencySign(String)
}

private enum Target {
    case currency(String)
    case unit(Dimension)

    var name: String {
        switch self {
        case .currency(let code): code
        case .unit(let unit): unit.symbol
        }
    }
}

private enum Quantity {
    case number(Double)
    case percent(Double)
    case money(Double, currency: String)
    case measurement(Measurement<Dimension>)

    var magnitude: Double {
        switch self {
        case .number(let value), .percent(let value), .money(let value, _): value
        case .measurement(let measurement): measurement.value
        }
    }

    var target: Target? {
        switch self {
        case .number, .percent: nil
        case .money(_, let code): .currency(code)
        case .measurement(let measurement): .unit(measurement.unit)
        }
    }

    var plain: Quantity {
        guard case .percent(let value) = self else { return self }
        return .number(value / 100)
    }

    func with(magnitude: Double) -> Quantity {
        switch self {
        case .number: .number(magnitude)
        case .percent: .percent(magnitude)
        case .money(_, let code): .money(magnitude, currency: code)
        case .measurement(let measurement): .measurement(Measurement(value: magnitude, unit: measurement.unit))
        }
    }
}

private struct Operand {
    let quantity: Quantity
    let text: String
}

private let currencySigns: [Character: String] = ["€": "EUR", "$": "USD", "£": "GBP", "¥": "JPY"]
private let symbols: Set<Character> = ["+", "-", "*", "/", "×", "÷", "^", "%", "(", ")"]
private let currencyCodes = Set(Locale.Currency.isoCurrencies.map(\.identifier))
private let constants: [String: Double] = ["pi": .pi, "π": .pi, "e": M_E]
private let conversionKeywords: Set<String> = ["to", "in", "as"]
private let unitPreservingFunctions: Set<String> = ["abs", "round", "floor", "ceil"]
private let functions: [String: @Sendable (Double) -> Double] = [
    "sqrt": { $0.squareRoot() },
    "abs": { abs($0) },
    "round": { $0.rounded() },
    "floor": { $0.rounded(.down) },
    "ceil": { $0.rounded(.up) },
    "log": { log10($0) },
    "ln": { log($0) },
    "sin": { sin($0) },
    "cos": { cos($0) },
    "tan": { tan($0) },
]

private func tokenize(_ text: String) throws(CalculationError) -> [Token] {
    let characters = Array(text.replacing("−", with: "-"))
    var tokens: [Token] = []
    var index = 0
    while index < characters.count {
        let character = characters[index]
        let start = index
        index += 1
        if character.isWhitespace { continue }
        if let code = currencySigns[character] {
            tokens.append(.currencySign(code))
        } else if symbols.contains(character) {
            tokens.append(.symbol(character == "×" ? "*" : character == "÷" ? "/" : character))
        } else if character.isASCII, character.isNumber || character == "." {
            while index < characters.count, characters[index].isASCII, characters[index].isNumber || ".,".contains(characters[index]) { index += 1 }
            let mantissa = String(characters[start..<index])
            let hasExponent = index + 1 < characters.count && "eE".contains(characters[index])
                && (characters[index + 1].isASCII && characters[index + 1].isNumber
                    || index + 2 < characters.count && "+-".contains(characters[index + 1]) && characters[index + 2].isASCII && characters[index + 2].isNumber)
            if hasExponent {
                index += 2
                while index < characters.count, characters[index].isASCII, characters[index].isNumber { index += 1 }
            }
            tokens.append(try number(mantissa, exponent: String(characters[(start + mantissa.count)..<index])))
        } else if character.isLetter || character == "°" {
            while index < characters.count, characters[index].isLetter || characters[index].isNumber || characters[index] == "°" { index += 1 }
            let word = String(characters[start..<index]).lowercased()
            let hasSlash = index < characters.count && characters[index] == "/"
            let denominator = hasSlash ? characters[(index + 1)...].prefix { $0.isLetter } : []
            let compound = "\(word)/\(String(denominator).lowercased())"
            if !denominator.isEmpty, units[compound] != nil {
                index += 1 + denominator.count
                tokens.append(.word(compound))
            } else {
                tokens.append(.word(word))
            }
        } else {
            throw CalculationError()
        }
    }
    return tokens
}

private func number(_ mantissa: String, exponent: String) throws(CalculationError) -> Token {
    let separators = mantissa.filter { $0 == "." || $0 == "," }
    guard separators.count <= 1 else { throw CalculationError() }
    if let comma = mantissa.firstIndex(of: ","), mantissa[mantissa.index(after: comma)...].count == 3 { throw CalculationError() }
    let text = mantissa.replacing(",", with: ".")
    guard let value = Double(text + exponent) else { throw CalculationError() }
    return .number(value, text: text + exponent)
}

private struct Parser {
    let tokens: [Token]
    let rates: [String: Double]
    private var position = 0
    private(set) var isBareLiteral = true

    init(tokens: [Token], rates: [String: Double]) {
        self.tokens = tokens
        self.rates = rates
    }

    mutating func query() throws(CalculationError) -> (Operand, Target?) {
        let operand = try expression()
        guard position < tokens.count else { return (operand, nil) }
        guard isConversion(at: position), case .word(let keyword) = tokens[position], let target = target(at: position + 1) else { throw CalculationError() }
        isBareLiteral = false
        return (Operand(quantity: operand.quantity, text: "\(operand.text) \(keyword) \(target.name)"), target)
    }

    func convert(_ quantity: Quantity, to target: Target) throws(CalculationError) -> Quantity {
        if case .money(let amount, let from) = quantity, case .currency(let to) = target {
            guard let fromRate = rates[from], let toRate = rates[to] else { throw CalculationError() }
            return .money(amount / fromRate * toRate, currency: to)
        }
        guard case .measurement(let measurement) = quantity, case .unit(let unit) = target,
              type(of: measurement.unit).baseUnit() == type(of: unit).baseUnit()
        else { throw CalculationError() }
        return .measurement(measurement.converted(to: unit))
    }

    private func isConversion(at index: Int) -> Bool {
        guard index + 2 == tokens.count, case .word(let keyword) = tokens[index] else { return false }
        return conversionKeywords.contains(keyword) && target(at: index + 1) != nil
    }

    private func target(at index: Int) -> Target? {
        guard index < tokens.count else { return nil }
        if case .currencySign(let code) = tokens[index] { return .currency(code) }
        guard case .word(let word) = tokens[index] else { return nil }
        if let unit = units[word] { return .unit(unit) }
        return currencyCodes.contains(word.uppercased()) ? .currency(word.uppercased()) : nil
    }

    private mutating func consume(_ token: Token) -> Bool {
        guard position < tokens.count, tokens[position] == token else { return false }
        position += 1
        return true
    }

    private mutating func expression() throws(CalculationError) -> Operand {
        var operand = try term()
        while true {
            if consume(.symbol("+")) {
                let rhs = try term()
                operand = Operand(quantity: try add(operand.quantity, rhs.quantity, sign: 1), text: "\(operand.text) + \(rhs.text)")
            } else if consume(.symbol("-")) {
                let rhs = try term()
                operand = Operand(quantity: try add(operand.quantity, rhs.quantity, sign: -1), text: "\(operand.text) - \(rhs.text)")
            } else {
                return operand
            }
        }
    }

    private mutating func term() throws(CalculationError) -> Operand {
        var operand = try unary()
        while true {
            if consume(.symbol("*")) {
                let rhs = try unary()
                operand = Operand(quantity: try multiply(operand.quantity, rhs.quantity), text: "\(operand.text) × \(rhs.text)")
            } else if consume(.symbol("/")) {
                let rhs = try unary()
                operand = Operand(quantity: try divide(operand.quantity, rhs.quantity), text: "\(operand.text) ÷ \(rhs.text)")
            } else if consume(.word("of")) {
                let rhs = try unary()
                guard case .percent(let percent) = operand.quantity else { throw CalculationError() }
                let base = rhs.quantity.plain
                operand = Operand(quantity: base.with(magnitude: base.magnitude * percent / 100), text: "\(operand.text) of \(rhs.text)")
            } else {
                return operand
            }
        }
    }

    private mutating func unary() throws(CalculationError) -> Operand {
        if consume(.symbol("-")) {
            let operand = try unary()
            return Operand(quantity: operand.quantity.with(magnitude: -operand.quantity.magnitude), text: "-\(operand.text)")
        }
        return try power()
    }

    private mutating func power() throws(CalculationError) -> Operand {
        let base = try percent()
        guard consume(.symbol("^")) else { return base }
        let exponent = try unary()
        guard base.quantity.plain.target == nil, exponent.quantity.plain.target == nil else { throw CalculationError() }
        isBareLiteral = false
        return Operand(quantity: .number(pow(base.quantity.plain.magnitude, exponent.quantity.plain.magnitude)), text: "\(base.text)^\(exponent.text)")
    }

    private mutating func percent() throws(CalculationError) -> Operand {
        let operand = try primary()
        guard consume(.symbol("%")) else { return operand }
        guard case .number(let value) = operand.quantity else { throw CalculationError() }
        isBareLiteral = false
        return Operand(quantity: .percent(value), text: "\(operand.text)%")
    }

    private mutating func primary() throws(CalculationError) -> Operand {
        guard position < tokens.count else { throw CalculationError() }
        let token = tokens[position]
        position += 1
        if case .number(let value, let text) = token { return amount(value, text: text) }
        if case .currencySign(let code) = token {
            guard position < tokens.count, case .number(let value, let text) = tokens[position] else { throw CalculationError() }
            position += 1
            return Operand(quantity: .money(value, currency: code), text: "\(text) \(code)")
        }
        if token == .symbol("(") {
            let inner = try expression()
            guard consume(.symbol(")")) else { throw CalculationError() }
            return Operand(quantity: inner.quantity, text: "(\(inner.text))")
        }
        guard case .word(let word) = token else { throw CalculationError() }
        if let constant = constants[word] { return Operand(quantity: .number(constant), text: word) }
        guard let function = functions[word], consume(.symbol("(")) else { throw CalculationError() }
        let argument = try expression()
        guard consume(.symbol(")")) else { throw CalculationError() }
        let input = argument.quantity.plain
        guard input.target == nil || unitPreservingFunctions.contains(word) else { throw CalculationError() }
        isBareLiteral = false
        return Operand(quantity: input.with(magnitude: function(input.magnitude)), text: "\(word)(\(argument.text))")
    }

    private mutating func amount(_ value: Double, text: String) -> Operand {
        guard position < tokens.count, !isConversion(at: position) else { return Operand(quantity: .number(value), text: text) }
        if case .currencySign(let code) = tokens[position] {
            position += 1
            return Operand(quantity: .money(value, currency: code), text: "\(text) \(code)")
        }
        guard case .word = tokens[position], let target = target(at: position) else {
            return Operand(quantity: .number(value), text: text)
        }
        position += 1
        let quantity: Quantity = switch target {
        case .currency(let code): .money(value, currency: code)
        case .unit(let unit): .measurement(Measurement(value: value, unit: unit))
        }
        return Operand(quantity: quantity, text: "\(text) \(target.name)")
    }

    private mutating func add(_ lhs: Quantity, _ rhs: Quantity, sign: Double) throws(CalculationError) -> Quantity {
        isBareLiteral = false
        switch (lhs, rhs) {
        case (.percent, _): break
        case (_, .percent(let percent)): return lhs.with(magnitude: lhs.magnitude * (1 + sign * percent / 100))
        default: break
        }
        let left = lhs.plain
        let right = rhs.plain
        guard let unit = left.target else { return right.with(magnitude: left.magnitude + sign * right.magnitude) }
        let converted = right.target == nil ? right : try convert(right, to: unit)
        return left.with(magnitude: left.magnitude + sign * converted.magnitude)
    }

    private mutating func multiply(_ lhs: Quantity, _ rhs: Quantity) throws(CalculationError) -> Quantity {
        isBareLiteral = false
        let left = lhs.plain
        let right = rhs.plain
        guard left.target == nil || right.target == nil else { throw CalculationError() }
        return (left.target == nil ? right : left).with(magnitude: left.magnitude * right.magnitude)
    }

    private mutating func divide(_ lhs: Quantity, _ rhs: Quantity) throws(CalculationError) -> Quantity {
        isBareLiteral = false
        let left = lhs.plain
        let right = rhs.plain
        guard right.magnitude != 0 else { throw CalculationError() }
        if right.target == nil { return left.with(magnitude: left.magnitude / right.magnitude) }
        guard let unit = left.target else { throw CalculationError() }
        let converted = try convert(right, to: unit)
        guard converted.magnitude != 0 else { throw CalculationError() }
        return .number(left.magnitude / converted.magnitude)
    }
}

private func format(_ quantity: Quantity, locale: Locale) -> (display: String, raw: String) {
    let value = abs(quantity.magnitude) < 5e-11 ? 0 : quantity.magnitude
    let integerDigits = abs(value) < 1 ? 0 : Int(log10(abs(value))) + 1
    let base = FloatingPointFormatStyle<Double>(locale: locale)
    let style = if case .money = quantity {
        base.precision(.fractionLength(2))
    } else if abs(value) >= 1e15 {
        base.notation(.scientific).precision(.significantDigits(1...10))
    } else {
        base.precision(.fractionLength(0...max(0, 10 - integerDigits)))
    }
    let suffix = switch quantity {
    case .money(_, let code): " \(code)"
    case .measurement(let measurement): " \(measurement.unit.symbol)"
    case .number, .percent: ""
    }
    return (style.format(value) + suffix, style.grouping(.never).format(value))
}
