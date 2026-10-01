import Foundation
import Testing
import TinecastKit

private let fixture = """
KEY,FREQ,CURRENCY,CURRENCY_DENOM,EXR_TYPE,EXR_SUFFIX,TIME_PERIOD,OBS_VALUE,OBS_STATUS,OBS_CONF,OBS_PRE_BREAK,OBS_COM,TIME_FORMAT,BREAKS,COLLECTION,COMPILING_ORG,DISS_ORG,DOM_SER_IDS,PUBL_ECB,PUBL_MU,PUBL_PUBLIC,UNIT_INDEX_BASE,COMPILATION,COVERAGE,DECIMALS,NAT_TITLE,SOURCE_AGENCY,SOURCE_PUB,TITLE,TITLE_COMPL,UNIT,UNIT_MULT
EXR.D.ARS.EUR.SP00.A,D,ARS,EUR,SP00,A,2020-10-30,91.5953,A,F,,Indicative rate,P1D,,A,,,,,,,99Q1=100,,,5,,4F0,,Argentine peso/Euro,"Indicative exchange rate, Euro/Argentine peso, 2:15 pm (C.E.T.)",ARS,0
EXR.D.BGN.EUR.SP00.A,D,BGN,EUR,SP00,A,2025-12-31,1.9558,A,F,,,P1D,,A,,,,,,,99Q1=100,,,4,,4F0,,Euro/Bulgarian lev,"ECB reference exchange rate, Euro/Bulgarian lev, 2:15 pm (C.E.T.)",BGN,0
EXR.D.SEK.EUR.SP00.A,D,SEK,EUR,SP00,A,2026-09-30,11.331,A,F,,,P1D,,A,,,,,,,99Q1=100,,,4,,4F0,,Swedish krona/Euro ECB reference exchange rate,"ECB reference exchange rate, Swedish krona/Euro, 2.15 pm (C.E.T.)",SEK,0
EXR.D.USD.EUR.SP00.A,D,USD,EUR,SP00,A,2026-09-30,1.1355,A,F,,,P1D,,A,,,,,,,99Q1=100,,,4,,4F0,,US dollar/Euro ECB reference exchange rate,"ECB reference exchange rate, US dollar/Euro, 2.15 pm (C.E.T.)",USD,0
EXR.D.JPY.EUR.SP00.A,D,JPY,EUR,SP00,A,2026-09-25,178.27,A,F,,,P1D,,A,,,,,,,99Q1=100,,,4,,4F0,,Japanese yen/Euro ECB reference exchange rate,"ECB reference exchange rate, Japanese yen/Euro, 2.15 pm (C.E.T.)",JPY,0

"""

private let fetchedAt = Date(timeIntervalSinceReferenceDate: 812_000_000)

@Test func parsesCurrentECBRatesAndAddsEuro() throws {
    let rates = try #require(ExchangeRates(ecbCSV: fixture, fetchedAt: fetchedAt))

    #expect(rates.date == "2026-09-30")
    #expect(rates.fetchedAt == fetchedAt)
    #expect(rates.rates == ["SEK": 11.331, "USD": 1.1355, "JPY": 178.27, "EUR": 1])
}

@Test func dropsDiscontinuedCurrenciesOlderThanAWeek() throws {
    let rates = try #require(ExchangeRates(ecbCSV: fixture, fetchedAt: fetchedAt))

    #expect(rates.rates["ARS"] == nil)
    #expect(rates.rates["BGN"] == nil)
}

@Test func findsColumnsByHeaderName() throws {
    let csv = "OBS_VALUE,TIME_PERIOD,CURRENCY\n1.5,2026-09-30,USD\r\nnot-a-number,2026-09-30,GBP\n2.0,garbage,CHF\n"
    let rates = try #require(ExchangeRates(ecbCSV: csv, fetchedAt: fetchedAt))

    #expect(rates.rates == ["USD": 1.5, "EUR": 1])
}

@Test func rejectsResponsesWithoutRates() {
    #expect(ExchangeRates(ecbCSV: "", fetchedAt: fetchedAt) == nil)
    #expect(ExchangeRates(ecbCSV: "<html>Service unavailable</html>", fetchedAt: fetchedAt) == nil)
    #expect(ExchangeRates(ecbCSV: "CURRENCY,TIME_PERIOD,OBS_VALUE\n", fetchedAt: fetchedAt) == nil)
}

@Test func exchangeRatesRoundTripThroughCodableWithTheStoredKeys() throws {
    let rates = ExchangeRates(date: "2026-09-30", fetchedAt: fetchedAt, rates: ["EUR": 1, "SEK": 11.331])
    let data = try JSONEncoder().encode(rates)
    let keys = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any]).keys

    #expect(Set(keys) == ["date", "fetchedAt", "rates"])
    #expect(try JSONDecoder().decode(ExchangeRates.self, from: data) == rates)
}
