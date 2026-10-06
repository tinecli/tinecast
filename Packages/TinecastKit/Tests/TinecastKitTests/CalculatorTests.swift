import Foundation
import Testing
import TinecastKit

private let rates = ExchangeRates(date: "2026-09-30", fetchedAt: .distantPast, rates: ["EUR": 1, "SEK": 11, "USD": 1.1, "GBP": 0.8])
private let english = Locale(identifier: "en_US")

private func result(_ query: String, rates: ExchangeRates? = rates, local: String? = "SEK", locale: Locale = english) -> String? {
    calculate(query, rates: rates, localCurrency: local, locale: locale)?.result.text
}

@Test func evaluatesArithmeticWithPrecedence() {
    #expect(result("1 + 2 * 3") == "7")
    #expect(result("(1 + 2) * 3") == "9")
    #expect(result("10 - 4 - 3") == "3")
    #expect(result("100 / 4 / 5") == "5")
    #expect(result("7 / 2") == "3.5")
    #expect(result("6 × 7") == "42")
    #expect(result("84 ÷ 2") == "42")
    #expect(result("1+2*3") == "7")
}

@Test func powerIsRightAssociativeAndBindsTighterThanUnaryMinus() {
    #expect(result("2^3^2") == "512")
    #expect(result("-2^2") == "-4")
    #expect(result("(-2)^2") == "4")
    #expect(result("2^-1") == "0.5")
}

@Test func unaryMinusAndUnicodeMinus() {
    #expect(result("-3 + 5") == "2")
    #expect(result("5 - -3") == "8")
    #expect(result("5 − 3") == "2")
    #expect(result("-(2 + 3) * 2") == "-10")
}

@Test func percentages() {
    #expect(result("20% of 150") == "30")
    #expect(result("150 + 10%") == "165")
    #expect(result("150 - 10%") == "135")
    #expect(result("200 * 15%") == "30")
    #expect(result("50%") == "0.5")
    #expect(result("10% + 5%") == "0.15")
    #expect(result("10% of 300 EUR") == "30.00 EUR")
    #expect(result("2950 SEK + 25%") == "3,687.50 SEK")
}

@Test func constantsAndFunctions() {
    #expect(result("pi * 2") == "6.283185307")
    #expect(result("π + 0") == "3.141592654")
    #expect(result("e * 1") == "2.718281828")
    #expect(result("sqrt(16)") == "4")
    #expect(result("abs(-3)") == "3")
    #expect(result("round(2.5)") == "3")
    #expect(result("floor(2.7)") == "2")
    #expect(result("ceil(2.1)") == "3")
    #expect(result("log(1000)") == "3")
    #expect(result("ln(e)") == "1")
    #expect(result("sin(pi)") == "0")
    #expect(result("cos(0)") == "1")
    #expect(result("tan(0)") == "0")
    #expect(result("sqrt(9) + 2^2") == "7")
}

@Test func decimalsAcceptPointAndUnambiguousComma() {
    #expect(result("3,5 + 1") == "4.5")
    #expect(result("3.5 + 1") == "4.5")
    #expect(result(".5 * 2") == "1")
    #expect(result("1.000,5 + 1") == nil)
    #expect(result("1e3 + 1") == "1,001")
}

@Test func groupingFollowsTheLocale() {
    #expect(result("1,000 + 1") == "1,001")
    #expect(result("100*100,090") == "10,009,000")
    #expect(result("1,234,567.5 + 0.5") == "1,234,568")
    #expect(result("1,000 + 1", locale: Locale(identifier: "sv_SE")) == "2")
    #expect(result("1.000,5 + 1", locale: Locale(identifier: "de_DE")) == "1.001,5")
}

@Test func failuresGiveNoResult() {
    #expect(result("1 / 0") == nil)
    #expect(result("0 / 0") == nil)
    #expect(result("sqrt(-1)") == nil)
    #expect(result("log(0)") == nil)
    #expect(result("1 +") == nil)
    #expect(result("(1 + 2") == nil)
    #expect(result("1 + 2)") == nil)
    #expect(result("* 3") == nil)
    #expect(result("2 3") == nil)
    #expect(result("14 390 + 1") == nil)
    #expect(result("sqrt 16") == nil)
    #expect(result("foo(2)") == nil)
    #expect(result("2 + @") == nil)
    #expect(result("5 km + 3 kg") == nil)
    #expect(result("5 km * 3 km") == nil)
    #expect(result("10 of 20") == nil)
    #expect(result("") == nil)
}

@Test func plainTextAndBareValuesAreNotMath() {
    #expect(result("2026") == nil)
    #expect(result("chrome") == nil)
    #expect(result("e") == nil)
    #expect(result("pi") == nil)
    #expect(result("-5") == nil)
    #expect(result("(5)") == nil)
    #expect(result("5 min") == nil)
    #expect(result("1password") == nil)
    #expect(result("e-mail") == nil)
    #expect(result("visual studio code") == nil)
}

@Test func currencySumsConvertToTheFirstCurrency() {
    #expect(result("14390 SEK + 2950 SEK + 260 EUR") == "20,200.00 SEK")
    #expect(result("260 EUR + 1100 SEK") == "360.00 EUR")
    #expect(result("100 EUR - 50%") == "50.00 EUR")
    #expect(result("100 usd * 2") == "200.00 USD")
    #expect(result("3 * 100 usd") == "300.00 USD")
    #expect(result("100 EUR / 4") == "25.00 EUR")
    #expect(result("110 SEK / 10 EUR") == "1")
    #expect(result("5 + 10 EUR") == "15.00 EUR")
}

@Test func currencySyntaxVariants() {
    #expect(result("260eur") == "2,860.00 SEK")
    #expect(result("260 EUR") == "2,860.00 SEK")
    #expect(result("€260") == "2,860.00 SEK")
    #expect(result("$5") == "50.00 SEK")
    #expect(result("5$") == "50.00 SEK")
    #expect(result("£8 + 1") == "9.00 GBP")
    #expect(result("-$5") == "-50.00 SEK")
}

@Test func explicitCurrencyTargets() {
    #expect(result("100 usd to sek") == "1,000.00 SEK")
    #expect(result("100 usd in sek") == "1,000.00 SEK")
    #expect(result("100 USD as EUR") == "90.91 EUR")
    #expect(result("14390 SEK + 260 EUR to usd") == "1,725.00 USD")
    #expect(result("100 sek to €") == "9.09 EUR")
}

@Test func singleAmountsConvertToLocalCurrencyOrEuro() {
    #expect(result("260 SEK") == "23.64 EUR")
    #expect(result("260 SEK", local: "USD") == "26.00 USD")
    #expect(result("10 EUR", local: "EUR") == "11.00 USD")
    #expect(result("10 USD", local: nil) == "9.09 EUR")
}

@Test func missingRatesGiveNoResult() {
    #expect(result("100 usd to sek", rates: nil) == nil)
    #expect(result("100 usd", rates: nil) == nil)
    #expect(result("100 EUR + 5 CHF") == nil)
    #expect(result("100 EUR + 5 EUR", rates: nil) == "105.00 EUR")
    #expect(result("10 eur to xyz") == nil)
}

@Test func unitConversions() {
    #expect(result("5 km to mi") == "3.106855961 mi")
    #expect(result("100 f to c") == "37.77777778 °C")
    #expect(result("100 °F in °C") == "37.77777778 °C")
    #expect(result("0 celsius to fahrenheit") == "32 °F")
    #expect(result("3 kg in lb") == "6.613867866 lb")
    #expect(result("16 oz to lb") == "1 lb")
    #expect(result("90 min to h") == "1.5 hr")
    #expect(result("2 days to hours") == "48 hr")
    #expect(result("1 tb to gb") == "1,000 GB")
    #expect(result("1 gib to mib") == "1,024 MiB")
    #expect(result("8 bits to bytes") == "1 B")
    #expect(result("1 l to ml") == "1,000 mL")
    #expect(result("1 gallon to liters") == "3.785411784 L")
    #expect(result("1 ha to m2") == "10,000 m²")
    #expect(result("1 km² to m²") == "1,000,000 m²")
    #expect(result("100 km/h to mph") == "62.13711922 mph")
    #expect(result("10 m/s to km/h") == "36 km/h")
    #expect(result("1 knot to km/h") == "1.852 km/h")
    #expect(result("4 qt to gal") == "1 gal")
    #expect(result("12 INCHES TO CM") == "30.48 cm")
}

@Test func inchAbbreviationAndInKeywordCoexist() {
    #expect(result("12 in to cm") == "30.48 cm")
    #expect(result("30.48 cm in in") == "12 in")
    #expect(result("12 in in cm") == "30.48 cm")
    #expect(result("12 in") == "30.48 cm")
}

@Test func unitArithmeticConvertsToTheFirstUnit() {
    #expect(result("1 km + 500 m") == "1.5 km")
    #expect(result("1 km + 500 m to m") == "1,500 m")
    #expect(result("3 kg * 2") == "6 kg")
    #expect(result("1 km / 250 m") == "4")
    #expect(result("round(3.7 km)") == "4 km")
}

@Test func incompatibleConversionsGiveNoResult() {
    #expect(result("5 km to kg") == nil)
    #expect(result("5 to km") == nil)
    #expect(result("5 km to usd") == nil)
    #expect(result("5 usd to km") == nil)
    #expect(result("sin(5 km)") == nil)
    #expect(result("5 km to") == nil)
}

@Test func formattingTrimsZerosAndCapsPrecision() {
    #expect(result("0.1 + 0.2") == "0.3")
    #expect(result("1 / 3") == "0.3333333333")
    #expect(result("2 / 3 * 1000") == "666.6666667")
    #expect(result("1000000 * 1000") == "1,000,000,000")
    #expect(result("123456789 * 1000") == "123,456,789,000")
    #expect(result("10^20") == "1E20")
    #expect(result("0 * -1") == "0")
}

@Test func rawResultHasNoGroupingOrCurrencyCode() {
    #expect(calculate("1000000 * 1000", rates: rates, localCurrency: "SEK", locale: english)?.raw == "1000000000")
    #expect(calculate("14390 SEK + 2950 SEK", rates: rates, localCurrency: "SEK", locale: english)?.raw == "17340.00")
    #expect(calculate("1 tb to gb", rates: rates, localCurrency: "SEK", locale: english)?.raw == "1000")
    #expect(calculate("1 / 3", rates: rates, localCurrency: "SEK", locale: english)?.raw == "0.3333333333")
}

@Test func formattingFollowsTheGivenLocale() {
    let swedish = Locale(identifier: "sv_SE")
    let calculation = calculate("14390 SEK + 2950,5 SEK", rates: rates, localCurrency: "SEK", locale: swedish)

    #expect(calculation?.result.text == "17\u{A0}340,50 SEK")
    #expect(calculation?.raw == "17340,50")
    #expect(result("7 / 2", locale: swedish) == "3,5")
    #expect(result("7 / 2", locale: Locale(identifier: "de_DE")) == "3,5")
    #expect(result("1000 * 1000", locale: Locale(identifier: "de_DE")) == "1.000.000")
}

@Test func negativeNumbersAndGroupingFollowTheLocale() {
    let swedish = Locale(identifier: "sv_SE")

    #expect(result("1234.5 * 1", locale: english) == "1,234.5")
    #expect(result("1234.5 * 1", locale: swedish) == "1\u{A0}234,5")
    #expect(result("0 - 1234.5", locale: swedish) == "\u{2212}1\u{A0}234,5")
    #expect(calculate("0 - 1234.5", rates: rates, localCurrency: "SEK", locale: swedish)?.raw == "\u{2212}1234,5")
}

@Test func currencyConversionNamesBothSidesAndQuotesTheRate() throws {
    let calculation = try #require(calculate("100 SEK", rates: rates, localCurrency: "SEK", locale: english))

    #expect(calculation.input == Calculation.Side(text: "100 SEK", name: "Swedish Krona"))
    #expect(calculation.result == Calculation.Side(text: "9.09 EUR", name: "Euro"))
    #expect(calculation.note == "1 SEK = 0.09091 EUR · ECB reference rate, Sep 30, 2026")
}

@Test func explicitConversionKeepsTheKeywordOutOfTheInput() throws {
    let calculation = try #require(calculate("100 usd to sek", rates: rates, localCurrency: "SEK", locale: english))

    #expect(calculation.input == Calculation.Side(text: "100 USD", name: "US Dollar"))
    #expect(calculation.result.name == "Swedish Krona")
    #expect(calculation.note == "1 USD = 10 SEK · ECB reference rate, Sep 30, 2026")
}

@Test func mixedSumsAreExpressionsWithOneRateOrJustTheDate() throws {
    let oneOther = try #require(calculate("14390 SEK + 2950 SEK + 260 EUR", rates: rates, localCurrency: "SEK", locale: english))
    let twoOthers = try #require(calculate("100 SEK + 10 EUR + 5 USD", rates: rates, localCurrency: "SEK", locale: english))

    #expect(oneOther.input == Calculation.Side(text: "14390 SEK + 2950 SEK + 260 EUR", name: "Expression"))
    #expect(oneOther.result.name == "Swedish Krona")
    #expect(oneOther.note == "1 EUR = 11 SEK · ECB reference rate, Sep 30, 2026")
    #expect(twoOthers.note == "ECB reference rates, Sep 30, 2026")
    #expect(calculate("14390 SEK + 2950 SEK", rates: rates, localCurrency: "SEK", locale: english)?.note == nil)
}

@Test func rateNoteDateFollowsTheLocale() {
    let note = calculate("100 SEK", rates: rates, localCurrency: "SEK", locale: Locale(identifier: "sv_SE"))?.note

    #expect(note == "1 SEK = 0,09091 EUR · ECB reference rate, 30 sep. 2026")
}

@Test func unitConversionsUseLocalizedUnitNames() throws {
    let calculation = try #require(calculate("5 km to mi", rates: rates, localCurrency: "SEK", locale: english))
    let name = { (query: String, locale: Locale) in calculate(query, rates: rates, localCurrency: "SEK", locale: locale)?.result.name }

    #expect(calculation.input == Calculation.Side(text: "5 km", name: "Kilometers"))
    #expect(calculation.result.name == "Miles")
    #expect(calculation.note == nil)
    #expect(name("3 kg in lb", english) == "Pounds")
    #expect(name("1 l to floz", english) == "Fluid ounces")
    #expect(name("10 m/s to km/h", english) == "Kilometers per hour")
    #expect(name("2 days to hours", english) == "Hours")
    #expect(name("48 hours to days", english) == "Days")
    #expect(name("1 gib to mib", english) == "Mebibytes")
    #expect(name("5 km to mi", Locale(identifier: "de_DE")) == "Meilen")
}

@Test func plainMathIsAnExpressionWithAnAnswer() throws {
    let calculation = try #require(calculate("1+2*3", rates: rates, localCurrency: "SEK", locale: english))

    #expect(calculation.input == Calculation.Side(text: "1 + 2 × 3", name: "Expression"))
    #expect(calculation.result == Calculation.Side(text: "7", name: "Answer"))
    #expect(calculation.note == nil)
    #expect(calculate("1 km + 500 m", rates: rates, localCurrency: "SEK", locale: english)?.input.name == "Expression")
}

@Test func expressionIsNormalized() {
    let expression = { (query: String) in calculate(query, rates: rates, localCurrency: "SEK", locale: english)?.expression }

    #expect(expression("1+2*3") == "1 + 2 × 3")
    #expect(expression("  (1+2) /3 ") == "(1 + 2) ÷ 3")
    #expect(expression("-2^2") == "-2^2")
    #expect(expression("sqrt( 16 )") == "sqrt(16)")
    #expect(expression("20 % of 150") == "20% of 150")
    #expect(expression("260eur") == "260 EUR in SEK")
    #expect(expression("€260 + 3,5 eur") == "260 EUR + 3.5 EUR")
    #expect(expression("100 usd in sek") == "100 USD in SEK")
    #expect(expression("5 KM to MI") == "5 km to mi")
    #expect(expression("100 f to c") == "100 °F to °C")
}

@Test func arbitraryInputNeverCrashes() {
    let pieces = ["1", "0", "2.5", "3,5", "1,000", ".", ",", "+", "-", "*", "/", "^", "%", "(", ")", " ", "e", "pi", "sqrt", "log", "km", "in", "to", "of", "km/", "/h", "m²", "°", "€", "$", "sek", "usd", "1e", "e5", "-", "x", "@", "\u{0}", "é", "π"]
    var seed: UInt64 = 42
    for _ in 0..<20_000 {
        let query = (0..<Int(seed % 9)).map { _ in
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return pieces[Int(seed >> 33) % pieces.count]
        }.joined()
        _ = calculate(query, rates: rates, localCurrency: "SEK", locale: english)
        _ = calculate(query, rates: nil, localCurrency: nil, locale: english)
    }
}

@Test func bareMeasurementsConvertBetweenMetricAndImperial() {
    #expect(result("6 inch") == "15.24 cm")
    #expect(result("6 ft") == "1.8288 m")
    #expect(result("5 km") == "3.106855961 mi")
    #expect(result("3 kg") == "6.613867866 lb")
    #expect(result("100 °F") == "37.77777778 °C")
    #expect(result("1 cup") == "240 mL")
    #expect(result("100 km/h") == "62.13711922 mph")
    #expect(result("2 days") == nil)
    #expect(result("1 tb") == nil)
}

@Test func lengthsShowInchesInSixteenths() {
    #expect(result("180 cm") == "5 ft 10 7/8 in")
    #expect(result("15 cm") == "5 7/8 in")
    #expect(result("6 mm") == "1/4 in")
    #expect(result("30.48 cm in ft in") == "1 ft")
    #expect(result("180 cm to feet and inches") == "5 ft 10 7/8 in")
    #expect(result("2 m in inches") == "78 3/4 in")
    #expect(result("0 cm") == "0 in")
    #expect(result("0 - 3 cm in in") == "-1 3/16 in")
    #expect(result("0.5 mm in ft in") == "0 in")
}

@Test func fractionalInchesKeepTheDecimal() {
    let rounded = calculate("180 cm", rates: rates, localCurrency: "SEK", locale: english)
    #expect(rounded?.raw == "5 ft 10 7/8 in")
    #expect(rounded?.decimal == "70.86614173")
    #expect(rounded?.note == "= 70.86614173 in · nearest 1/16")
    let exact = calculate("12.7 mm", rates: rates, localCurrency: "SEK", locale: english)
    #expect(exact?.decimal == "0.5")
    #expect(exact?.note == "= 0.5 in")
    #expect(calculate("1 km", rates: rates, localCurrency: "SEK", locale: english)?.decimal == nil)
}

@Test func mixedLengthsAddUp() {
    #expect(result("5 ft 10 in") == "1.778 m")
    #expect(result("5'10\"") == "1.778 m")
    #expect(result("5′ 10″ to cm") == "177.8 cm")
    #expect(result("1 m 50 cm") == "4 ft 11 1/16 in")
    #expect(result("5 ft 10 in + 2 in to ft in") == "6 ft")
    #expect(result("5 km 3 kg") == nil)
}

@Test func fractionsReadAsAmounts() {
    #expect(result("3/8 in") == "0.9525 cm")
    #expect(result("2 1/2 in") == "6.35 cm")
    #expect(result("5 ft 10 1/2 in to cm") == "179.07 cm")
    #expect(result("2 1/2 + 1") == "3.5")
    #expect(result("3/8") == "0.375")
    #expect(result("2 1/2") == nil)
}

@Test func usCupsAreSeparateFromMetricCups() {
    #expect(result("1 uscup") == "236.5882365 mL")
    #expect(result("1 l to uscups") == "4.226752838 US cup")
}

@Test func settingsShapeTheResult() {
    func calculation(_ query: String, _ settings: Config.Calculator) -> Calculation? {
        calculate(query, rates: rates, localCurrency: "SEK", locale: english, settings: settings)
    }
    var settings = Config.Calculator()
    settings.autoConvertUnits = false
    #expect(calculation("6 inch", settings) == nil)
    #expect(calculation("6 inch to cm", settings)?.result.text == "15.24 cm")
    #expect(calculation("100 usd", settings)?.result.text == "1,000.00 SEK")

    settings = Config.Calculator()
    settings.inchFraction = 8
    #expect(calculation("180 cm", settings)?.result.text == "5 ft 10 7/8 in")
    #expect(calculation("1 cm", settings)?.result.text == "3/8 in")
    #expect(calculation("1 cm", settings)?.note == "= 0.3937007874 in · nearest 1/8")

    settings = Config.Calculator()
    settings.precision = .places(4)
    #expect(calculation("1 / 3", settings)?.result.text == "0.3333")
    #expect(calculation("180 cm", settings)?.note == "= 70.8661 in · nearest 1/16")
    #expect(calculation("180 cm", settings)?.decimal == "70.8661")
    #expect(calculation("10 usd to sek", settings)?.result.text == "100.00 SEK")

    settings.precision = .full
    #expect(calculation("1 / 3", settings)?.result.text == "0.333333333333333")
    #expect(calculation("0.1 + 0.2", settings)?.result.text == "0.3")
    #expect(calculation("0.1 * 3", settings)?.result.text == "0.3")
    #expect(calculation("1.1 * 1.1", settings)?.result.text == "1.21")
    #expect(calculation("sin(pi)", settings)?.result.text == "0")
    #expect(calculation("1234567.891 * 1", settings)?.result.text == "1,234,567.891")
    #expect(calculation("1234567.891 * 1", settings)?.raw == "1234567.891")
    #expect(calculation("10^20", settings)?.result.text == "100,000,000,000,000,000,000")
    #expect(calculation("180 cm", settings)?.decimal == "70.8661417322835")

    for places in 0...10 {
        settings.precision = .places(places)
        #expect(calculation("0.1 + 0.2", settings)?.result.text == (places == 0 ? "0" : "0.3"))
        #expect(calculation("1.1 * 1.1", settings)?.result.text == (places == 0 ? "1" : places == 1 ? "1.2" : "1.21"))
    }
}
