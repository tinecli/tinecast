import Foundation

let units: [String: Dimension] = {
    // Foundation rounds some US customary and speed coefficients to six digits, so exact ones are defined here.
    let day = UnitDuration(symbol: "d", converter: UnitConverterLinear(coefficient: 86_400))
    let week = UnitDuration(symbol: "wk", converter: UnitConverterLinear(coefficient: 604_800))
    let names: [(unit: Dimension, names: [String])] = [
        (UnitLength.millimeters, ["mm", "millimeter", "millimeters", "millimetre", "millimetres"]),
        (UnitLength.centimeters, ["cm", "centimeter", "centimeters", "centimetre", "centimetres"]),
        (UnitLength.meters, ["m", "meter", "meters", "metre", "metres"]),
        (UnitLength.kilometers, ["km", "kilometer", "kilometers", "kilometre", "kilometres"]),
        (UnitLength.inches, ["in", "inch", "inches"]),
        (UnitLength.feet, ["ft", "foot", "feet"]),
        (UnitLength.yards, ["yd", "yard", "yards"]),
        (UnitLength.miles, ["mi", "mile", "miles"]),
        (UnitLength.nauticalMiles, ["nmi"]),
        (feetAndInches, ["ft in", "ft and in", "feet inches", "feet and inches"]),
        (UnitMass.milligrams, ["mg", "milligram", "milligrams"]),
        (UnitMass.grams, ["g", "gram", "grams"]),
        (UnitMass.kilograms, ["kg", "kilo", "kilos", "kilogram", "kilograms"]),
        (UnitMass.metricTons, ["t", "tonne", "tonnes"]),
        (UnitMass(symbol: "oz", converter: UnitConverterLinear(coefficient: 0.028349523125)), ["oz", "ounce", "ounces"]),
        (UnitMass(symbol: "lb", converter: UnitConverterLinear(coefficient: 0.45359237)), ["lb", "lbs", "pound", "pounds"]),
        (UnitMass(symbol: "st", converter: UnitConverterLinear(coefficient: 6.35029318)), ["st", "stone", "stones"]),
        (UnitTemperature.celsius, ["c", "°c", "celsius"]),
        (UnitTemperature.fahrenheit, ["f", "°f", "fahrenheit"]),
        (UnitTemperature.kelvin, ["k", "kelvin"]),
        (UnitDuration.milliseconds, ["ms", "millisecond", "milliseconds"]),
        (UnitDuration.seconds, ["s", "sec", "secs", "second", "seconds"]),
        (UnitDuration.minutes, ["min", "mins", "minute", "minutes"]),
        (UnitDuration.hours, ["h", "hr", "hrs", "hour", "hours"]),
        (day, ["d", "day", "days"]),
        (week, ["wk", "week", "weeks"]),
        (UnitVolume.milliliters, ["ml", "milliliter", "milliliters", "millilitre", "millilitres"]),
        (UnitVolume.centiliters, ["cl", "centiliter", "centiliters", "centilitre", "centilitres"]),
        (UnitVolume.deciliters, ["dl", "deciliter", "deciliters", "decilitre", "decilitres"]),
        (UnitVolume.liters, ["l", "liter", "liters", "litre", "litres"]),
        (UnitVolume.cubicCentimeters, ["cm3", "cm³", "cc"]),
        (UnitVolume.cubicMeters, ["m3", "m³"]),
        (UnitVolume(symbol: "tsp", converter: UnitConverterLinear(coefficient: 0.00492892159375)), ["tsp", "teaspoon", "teaspoons"]),
        (UnitVolume(symbol: "tbsp", converter: UnitConverterLinear(coefficient: 0.01478676478125)), ["tbsp", "tablespoon", "tablespoons"]),
        (UnitVolume(symbol: "fl oz", converter: UnitConverterLinear(coefficient: 0.0295735295625)), ["floz"]),
        (UnitVolume.cups, ["cup", "cups"]),
        (UnitVolume(symbol: "US cup", converter: UnitConverterLinear(coefficient: 0.2365882365)), ["uscup", "uscups", "US cups"]),
        (UnitVolume(symbol: "pt", converter: UnitConverterLinear(coefficient: 0.473176473)), ["pt", "pint", "pints"]),
        (UnitVolume(symbol: "qt", converter: UnitConverterLinear(coefficient: 0.946352946)), ["qt", "quart", "quarts"]),
        (UnitVolume(symbol: "gal", converter: UnitConverterLinear(coefficient: 3.785411784)), ["gal", "gallon", "gallons"]),
        (UnitArea.squareCentimeters, ["cm2", "cm²"]),
        (UnitArea.squareMeters, ["m2", "m²", "sqm"]),
        (UnitArea.squareKilometers, ["km2", "km²", "sqkm"]),
        (UnitArea.squareFeet, ["ft2", "ft²", "sqft"]),
        (UnitArea.squareMiles, ["mi2", "mi²", "sqmi"]),
        (UnitArea.hectares, ["ha", "hectare", "hectares"]),
        (UnitArea.acres, ["ac", "acre", "acres"]),
        (UnitSpeed.metersPerSecond, ["m/s", "mps"]),
        (UnitSpeed(symbol: "km/h", converter: UnitConverterLinear(coefficient: 1 / 3.6)), ["km/h", "kmh", "kph"]),
        (UnitSpeed.milesPerHour, ["mph", "mi/h"]),
        (UnitSpeed(symbol: "kn", converter: UnitConverterLinear(coefficient: 1852.0 / 3600)), ["kn", "kt", "knot", "knots"]),
        (UnitInformationStorage.bits, ["bit", "bits"]),
        (UnitInformationStorage.bytes, ["b", "byte", "bytes"]),
        (UnitInformationStorage.kilobits, ["kbit", "kbits", "kilobit", "kilobits"]),
        (UnitInformationStorage.megabits, ["mbit", "mbits", "megabit", "megabits"]),
        (UnitInformationStorage.gigabits, ["gbit", "gbits", "gigabit", "gigabits"]),
        (UnitInformationStorage.kilobytes, ["kb", "kilobyte", "kilobytes"]),
        (UnitInformationStorage.megabytes, ["mb", "megabyte", "megabytes"]),
        (UnitInformationStorage.gigabytes, ["gb", "gigabyte", "gigabytes"]),
        (UnitInformationStorage.terabytes, ["tb", "terabyte", "terabytes"]),
        (UnitInformationStorage.petabytes, ["pb", "petabyte", "petabytes"]),
        (UnitInformationStorage.kibibytes, ["kib", "kibibyte", "kibibytes"]),
        (UnitInformationStorage.mebibytes, ["mib", "mebibyte", "mebibytes"]),
        (UnitInformationStorage.gibibytes, ["gib", "gibibyte", "gibibytes"]),
        (UnitInformationStorage.tebibytes, ["tib", "tebibyte", "tebibytes"]),
    ]
    return Dictionary(uniqueKeysWithValues: names.flatMap { entry in entry.names.map { ($0, entry.unit) } })
}()

let foundationTwins: [String: Dimension] = Dictionary(uniqueKeysWithValues: [
    UnitMass.ounces, UnitMass.pounds, UnitMass.stones,
    UnitVolume.teaspoons, UnitVolume.tablespoons, UnitVolume.fluidOunces, UnitVolume.pints, UnitVolume.quarts, UnitVolume.gallons,
    UnitSpeed.kilometersPerHour, UnitSpeed.knots,
].map { ($0.symbol, $0) })

let feetAndInches = UnitLength(symbol: "ft in", converter: UnitConverterLinear(coefficient: 0.0254))

let implicitTargets: [ObjectIdentifier: Dimension] = Dictionary(uniqueKeysWithValues: [
    ("mm", "in"), ("cm", "ft in"), ("m", "ft in"), ("km", "mi"),
    ("in", "cm"), ("ft", "m"), ("yd", "m"), ("mi", "km"), ("nmi", "km"),
    ("g", "oz"), ("kg", "lb"), ("oz", "g"), ("lb", "kg"), ("st", "kg"),
    ("c", "f"), ("f", "c"), ("k", "c"),
    ("ml", "floz"), ("cl", "floz"), ("dl", "cup"), ("l", "gal"),
    ("tsp", "ml"), ("tbsp", "ml"), ("floz", "ml"), ("cup", "ml"), ("uscup", "ml"), ("pt", "ml"), ("qt", "l"), ("gal", "l"),
    ("m2", "ft2"), ("km2", "mi2"), ("ft2", "m2"), ("mi2", "km2"), ("ha", "ac"), ("ac", "ha"),
    ("m/s", "km/h"), ("km/h", "mph"), ("mph", "km/h"), ("kn", "km/h"),
].map { (ObjectIdentifier(units[$0]!), units[$1]!) })
