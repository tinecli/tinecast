import Foundation

public struct Calculation: Equatable, Sendable {
    public struct Side: Equatable, Sendable {
        public let text: String
        public let name: String

        public init(text: String, name: String) {
            self.text = text
            self.name = name
        }
    }

    public let expression: String
    public let input: Side
    public let result: Side
    public let raw: String
    public let rateNote: String?
}

public func calculate(_ query: String, rates: ExchangeRates?, localCurrency: String?, locale: Locale) -> Calculation? {
    guard let tokens = try? tokenize(query), !tokens.isEmpty else { return nil }
    let allRates = (rates?.rates ?? [:]).merging(["EUR": 1]) { current, _ in current }
    var parser = Parser(tokens: tokens, rates: allRates)
    guard let (operand, conversion) = try? parser.query() else { return nil }
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
          let result = try? (conversion?.target ?? implicitTarget).map({ try parser.convert(value, to: $0) }) ?? value,
          result.magnitude.isFinite
    else { return nil }
    let (display, raw) = format(result, locale: locale)
    let suffix = conversion.map { " \($0.keyword) \($0.target.name)" } ?? implicitTarget.map { " in \($0.name)" } ?? ""
    return Calculation(
        expression: operand.text + suffix,
        input: Calculation.Side(text: operand.text, name: operand.isAmount ? name(of: value, locale: locale) : "Expression"),
        result: Calculation.Side(text: display, name: name(of: result, locale: locale)),
        raw: raw,
        rateNote: rates.flatMap { rateNote(for: result, from: parser.currencies, rates: allRates, date: $0.date, locale: locale) }
    )
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
    var isAmount = false
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
    private(set) var currencies: [String] = []

    init(tokens: [Token], rates: [String: Double]) {
        self.tokens = tokens
        self.rates = rates
    }

    mutating func query() throws(CalculationError) -> (Operand, (keyword: String, target: Target)?) {
        let operand = try expression()
        guard position < tokens.count else { return (operand, nil) }
        guard isConversion(at: position), case .word(let keyword) = tokens[position], let target = target(at: position + 1) else { throw CalculationError() }
        isBareLiteral = false
        return (operand, (keyword, target))
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

    private mutating func money(_ value: Double, currency code: String, text: String) -> Operand {
        if !currencies.contains(code) { currencies.append(code) }
        return Operand(quantity: .money(value, currency: code), text: "\(text) \(code)", isAmount: true)
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
            return Operand(quantity: operand.quantity.with(magnitude: -operand.quantity.magnitude), text: "-\(operand.text)", isAmount: operand.isAmount)
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
            return money(value, currency: code, text: text)
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
            return money(value, currency: code, text: text)
        }
        guard case .word = tokens[position], let target = target(at: position) else {
            return Operand(quantity: .number(value), text: text)
        }
        position += 1
        switch target {
        case .currency(let code):
            return money(value, currency: code, text: text)
        case .unit(let unit):
            return Operand(quantity: .measurement(Measurement(value: value, unit: unit)), text: "\(text) \(target.name)", isAmount: true)
        }
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
    let formatter = NumberFormatter()
    formatter.locale = locale
    if case .money = quantity {
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
    } else if abs(value) >= 1e15 {
        formatter.numberStyle = .scientific
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = 10
    } else {
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = max(0, 10 - integerDigits)
    }
    let suffix = switch quantity {
    case .money(_, let code): " \(code)"
    case .measurement(let measurement): " \(measurement.unit.symbol)"
    case .number, .percent: ""
    }
    let display = formatter.string(from: value as NSNumber) ?? ""
    formatter.usesGroupingSeparator = false
    return (display + suffix, formatter.string(from: value as NSNumber) ?? "")
}

private func name(of quantity: Quantity, locale: Locale) -> String {
    let name = switch quantity {
    case .money(_, let code):
        locale.localizedString(forCurrencyCode: code) ?? code
    case .measurement(let measurement):
        unitName(measurement.unit, locale: locale)
    case .number, .percent:
        "Answer"
    }
    return name.prefix(1).uppercased(with: locale) + name.dropFirst()
}

private func unitName(_ unit: Dimension, locale: Locale) -> String {
    let formatter = MeasurementFormatter()
    formatter.locale = locale
    formatter.unitStyle = .long
    formatter.unitOptions = .providedUnit
    let name = formatter.string(from: foundationTwins[unit.symbol] ?? unit)
    guard name == unit.symbol else { return name }
    return units.filter { $0.value === unit }.keys.max { $0.count < $1.count } ?? name
}

private func rateNote(for result: Quantity, from currencies: [String], rates: [String: Double], date: String, locale: Locale) -> String? {
    guard case .money(_, let target) = result else { return nil }
    let others = currencies.filter { $0 != target }
    guard !others.isEmpty else { return nil }
    let dateFormatter = DateFormatter()
    dateFormatter.locale = locale
    dateFormatter.timeZone = .gmt
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none
    let day = try? Date.ISO8601FormatStyle().year().month().day().parse(date)
    let source = day.map { ", \(dateFormatter.string(from: $0))" } ?? ""
    guard others.count == 1, let from = rates[others[0]], let to = rates[target] else { return "ECB reference rates\(source)" }
    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .decimal
    formatter.usesSignificantDigits = true
    formatter.maximumSignificantDigits = 4
    let rate = formatter.string(from: to / from as NSNumber) ?? ""
    return "1 \(others[0]) = \(rate) \(target) · ECB reference rate\(source)"
}
