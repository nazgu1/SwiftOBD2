//
//  decoders.swift
//  SmartOBD2
//
//  Created by kemo konteh on 9/18/23.
//

import OSLog

public enum MeasurementUnits: String, Codable {
    case metric = "Metric"
    case imperial = "Imperial"

    static var allCases: [MeasurementUnits] {
        [.metric, .imperial]
    }
}

public struct Status: Codable, Hashable {
    var MIL: Bool = false
    public var dtcCount: UInt8 = 0
    var ignitionType: String = ""

    var misfireMonitoring = StatusTest()
    var fuelSystemMonitoring = StatusTest()
    var componentMonitoring = StatusTest()
}

struct StatusTest: Codable, Hashable {
    var name: String = ""
    var supported: Bool = false
    var ready: Bool = false

    init(_ name: String = "", _ supported: Bool = false, _ ready: Bool = false) {
        self.name = name
        self.supported = supported
        self.ready = ready
    }
}

struct BitArray {
    let data: Data
    var binaryArray: [Int] {
        // Convert Data to binary array representation
        var result = [Int]()
        for byte in data {
            for i in 0 ..< 8 {
                // Extract each bit of the byte
                let bit = (byte >> (7 - i)) & 1
                result.append(Int(bit))
            }
        }
        return result
    }

    func index(of value: Int) -> Int? {
        // Find the index of the given value (1 or 0)
        return binaryArray.firstIndex(of: value)
    }

    func value(at range: Range<Int>) -> UInt8 {
        var value: UInt8 = 0
        for bit in range {
            value = value << 1
            value = value | UInt8(binaryArray[bit])
        }
        return value
    }
}

struct UAS {
    let signed: Bool
    let scale: Double
    let unit: Unit
    let offset: Double

    init(signed: Bool, scale: Double, unit: Unit, offset: Double = 0.0) {
        self.signed = signed
        self.scale = scale
        self.unit = unit
        self.offset = offset
    }

    func decode(bytes: Data) -> MeasurementResult {
        var value = bytesToInt(bytes)

        if signed {
            value = twosComp(value, length: bytes.count * 8)
        }

        let scaledValue = Double(value) * scale + offset
        return MeasurementResult(value: scaledValue, unit: unit)
    }
}

func twosComp(_ value: Int, length: Int) -> Int {
    let mask = (1 << length) - 1
    return value & mask
}

extension Unit {
    static let percent = Unit(symbol: "%")
    static let count = Unit(symbol: "count")
    static let celsius = Unit(symbol: "°C")
    static let degrees = Unit(symbol: "°")
    static let gramsPerSecond = Unit(symbol: "g/s")
    static let none = Unit(symbol: "")
    static let rpm = Unit(symbol: "rpm")
    static let kph = Unit(symbol: "KP/H")
    static let mph = Unit(symbol: "MP/H")

    static let Pascal = Unit(symbol: "Pa")
    static let bar = Unit(symbol: "bar")
    static let ppm = Unit(symbol: "ppm")
    static let ratio = Unit(symbol: "ratio")
}

let uasIDS: [UInt8: UAS] = [
    // Unsigned
    0x01: UAS(signed: false, scale: 1.0, unit: Unit.count),
    0x02: UAS(signed: false, scale: 0.1, unit: Unit.count),
    0x03: UAS(signed: false, scale: 0.01, unit: Unit.count),
    0x04: UAS(signed: false, scale: 0.001, unit: Unit.count),
    0x05: UAS(signed: false, scale: 0.0000305, unit: Unit.count),
    0x06: UAS(signed: false, scale: 0.000305, unit: Unit.count),
    0x07: UAS(signed: false, scale: 0.25, unit: Unit.rpm),
    0x09: UAS(signed: false, scale: 1, unit: UnitSpeed.kilometersPerHour),

    0x0A: UAS(signed: false, scale: 0.122, unit: UnitElectricPotentialDifference.millivolts),
    0x0B: UAS(signed: false, scale: 0.001, unit: UnitElectricPotentialDifference.volts),

    0x10: UAS(signed: false, scale: 1, unit: UnitDuration.milliseconds),
    0x11: UAS(signed: false, scale: 100, unit: UnitDuration.milliseconds),
    0x12: UAS(signed: false, scale: 1, unit: UnitDuration.seconds),
    0x13: UAS(signed: false, scale: 1, unit: UnitElectricResistance.microohms),
    0x14: UAS(signed: false, scale: 1, unit: UnitElectricResistance.ohms),
    0x15: UAS(signed: false, scale: 1, unit: UnitElectricResistance.kiloohms),
    0x16: UAS(signed: false, scale: 0.1, unit: Unit.celsius, offset: -40.0),
    0x17: UAS(signed: false, scale: 0.01, unit: UnitPressure.kilopascals),
    0x18: UAS(signed: false, scale: 0.0117, unit: UnitPressure.kilopascals),
    0x19: UAS(signed: false, scale: 0.079, unit: UnitPressure.kilopascals),
    0x1A: UAS(signed: false, scale: 1, unit: UnitPressure.kilopascals),
    0x1B: UAS(signed: false, scale: 10, unit: UnitPressure.kilopascals),
    0x1C: UAS(signed: false, scale: 0.01, unit: UnitAngle.degrees),
    0x1D: UAS(signed: false, scale: 0.5, unit: UnitAngle.degrees),
    // unit ratio
    0x1E: UAS(signed: false, scale: 0.0000305, unit: Unit.ratio),
    0x1F: UAS(signed: false, scale: 0.05, unit: Unit.ratio),
    0x20: UAS(signed: false, scale: 0.00390625, unit: Unit.ratio),
    0x21: UAS(signed: false, scale: 1, unit: UnitFrequency.millihertz),
    0x22: UAS(signed: false, scale: 1, unit: UnitFrequency.hertz),
    0x23: UAS(signed: false, scale: 1, unit: UnitFrequency.kilohertz),
    0x24: UAS(signed: false, scale: 1, unit: Unit.count),
    0x25: UAS(signed: false, scale: 1, unit: UnitLength.kilometers),

    0x27: UAS(signed: false, scale: 0.01, unit: Unit.gramsPerSecond),

    // Signed
    0x81: UAS(signed: true, scale: 1.0, unit: Unit.count),
    0x82: UAS(signed: true, scale: 0.1, unit: Unit.count),

    0x83: UAS(signed: true, scale: 0.01, unit: Unit.count),
    0x84: UAS(signed: true, scale: 0.001, unit: Unit.count),
    0x85: UAS(signed: true, scale: 0.0000305, unit: Unit.count),
    0x86: UAS(signed: true, scale: 0.000305, unit: Unit.count),
    0x87: UAS(signed: true, scale: 1, unit: Unit.ppm),
    //
    0x8A: UAS(signed: true, scale: 0.122, unit: UnitElectricPotentialDifference.millivolts),
    0x8B: UAS(signed: true, scale: 0.001, unit: UnitElectricPotentialDifference.volts),
    0x8C: UAS(signed: true, scale: 0.01, unit: UnitElectricPotentialDifference.volts),
    0x8D: UAS(signed: true, scale: 0.00390625, unit: UnitElectricCurrent.milliamperes),
    0x8E: UAS(signed: true, scale: 0.001, unit: UnitElectricCurrent.amperes),
    //
    0x90: UAS(signed: true, scale: 1, unit: UnitDuration.milliseconds),
    //
    0x96: UAS(signed: true, scale: 0.1, unit: Unit.celsius),

    0x99: UAS(signed: true, scale: 0.1, unit: UnitPressure.kilopascals),

    0xFC: UAS(signed: true, scale: 0.01, unit: UnitPressure.kilopascals),
    0xFD: UAS(signed: true, scale: 0.001, unit: UnitPressure.kilopascals),
    0xFE: UAS(signed: true, scale: 0.25, unit: Unit.Pascal)
]

public enum Decoders: Codable {
    case pid
    case status
    case singleDTC
    case fuelStatus
    case percent
    case temp
    case percentCentered
    case fuelPressure
    case pressure
    case uas0x07
    case uas0x09
    case uas0x12
    case timingAdvance
    case uas0x27
    case airStatus
    case o2Sensors
    case sensorVoltage
    case obdCompliance
    case o2SensorsAlt
    case auxInputStatus
    case uas0x25
    case uas0x19
    case uas0x1B
    case uas0x01
    case uas0x16
    case uas0x0B
    case uas0x1E
    case evapPressure
    case sensorVoltageBig
    case currentCentered
    case absoluteLoad
    case uas0x34
    case maxMaf
    case fuelType
    case absEvapPressure
    case evapPressureAlt
    case injectTiming
    case dtc
    case fuelRate
    case monitor
    case count
    case cvn
    case encoded_string
    case none
}

func decodeSpeed(_ data: Data, _: MeasurementUnits) -> DecodeResult {
    let uas = UAS(signed: false, scale: 1, unit: UnitSpeed.kilometersPerHour)
    let measurement = uas.decode(bytes: data)
    return .measurementResult(measurement)
}

func KPHtoMPH(_ kph: Double) -> Double {
    return kph * 0.621371
}

func encoded_string(_ data: Data) -> String? {
    guard var string = String(bytes: data, encoding: .utf8) else {
        return nil
    }

    string = string
        .replacingOccurrences(of: "[^a-zA-Z0-9]",
                              with: "",
                              options: .regularExpression)

    return string
}

func decodeMonitor(_ data: Data) -> Monitor? {
    var databytes = Data(data)

    let mon = Monitor()

    // test that we got the right number of bytes
    let extra_bytes = databytes.count % 9

    if extra_bytes != 0 {
        Logger.elm327.error("Encountered monitor message with non-multiple of 9 bytes. Truncating...")
        databytes = databytes.dropLast(extra_bytes)
    }

    // look at data in blocks of 9 bytes (one test result)
    for i in stride(from: 0, to: databytes.count, by: 9) {
        let subdata = databytes.subdata(in: i ..< i + 9)
//        print("\nSubdata: ", subdata.compactMap {String(format: "%02x", $0)})
        let test = parse_monitor_test(subdata)
        if let test = test, let tid = test.tid {
//            print(test.name ?? "")
//            print(test.desc ?? "")
//            print("Value: ", test.value ?? "No value")
//            print("Min: ", test.min ?? "No value")
//            print("Max: ", test.max ?? "No value")
//            print(test.description)
            mon.tests[tid] = test
        }
    }
    return mon
}

func decodeUAS(_ data: Data, id: UInt8?) -> MeasurementResult? {
    guard let id = id else {
        return nil
    }
    return uasIDS[id]?.decode(bytes: data)
}

func fuelRate(_ data: Data) -> MeasurementResult? {
    let value = Double(bytesToInt(data)) * 0.05
    return MeasurementResult(value: value, unit: UnitFuelEfficiency.litersPer100Kilometers)
}

func injectTiming(_ data: Data) -> MeasurementResult? {
    let value = (Double(bytesToInt(data)) - 26880) / 128
    return MeasurementResult(value: value, unit: UnitPressure.degrees)
}

// -32767 to 32768 Pa
func evapPressureAlt(_ data: Data) -> MeasurementResult? {
    let value = Double(bytesToInt(data)) - 32767
    return MeasurementResult(value: value, unit: Unit.Pascal)
}

func absEvapPressure(_ data: Data) -> MeasurementResult? {
    let value = Double(bytesToInt(data)) / 200
    return MeasurementResult(value: value, unit: UnitPressure.kilopascals)
}

func fuelType(_ data: Data) -> String? {
    let i = data[0]
    var value: String?
    if i < FuelTypes.count {
        value = FuelTypes[Int(i)]
    }
    return value
}

func maxMaf(_ data: Data) -> MeasurementResult? {
    let value = data[0] * 10
    return MeasurementResult(value: Double(value), unit: Unit.gramsPerSecond)
}

func absoluteLoad(_ data: Data) -> MeasurementResult? {
    let value = (bytesToInt(data) * 100) / 255
    return MeasurementResult(value: Double(value), unit: Unit.percent)
}

func evapPressure(_ data: Data) -> MeasurementResult? {
    let a = twosComp(Int(data[0]), length: 8)
    let b = twosComp(Int(data[1]), length: 8)

    let value = ((Double(a) * 256.0) + Double(b)) / 4.0
    return MeasurementResult(value: value, unit: UnitPressure.kilopascals)
}

func auxInputStatus(_ data: Data) -> Bool? {
    return ((data[0] >> 7) & 1) == 1
}

func o2Sensors(_ data: Data) -> String? {
    let bits = BitArray(data: data)
    //        return (
    //                (),  # bank 0 is invalid
    //                tuple(bits[:2]),  # bank 1
    //                tuple(bits[2:4]),  # bank 2
    //                tuple(bits[4:6]),  # bank 3
    //                tuple(bits[6:]),  # bank 4
    //            )

    let bank1 = Array(bits.binaryArray[0 ..< 4])
    let bank2 = Array(bits.binaryArray[4 ..< 8])

    return "\(bank1), \(bank2)"
}

func o2SensorsAlt(_ data: Data) -> String? {
    let bits = BitArray(data: data)
    //        return (
    //                (),  # bank 0 is invalid
    //                tuple(bits[:2]),  # bank 1
    //                tuple(bits[2:4]),  # bank 2
    //                tuple(bits[4:6]),  # bank 3
    //                tuple(bits[6:]),  # bank 4
    //            )

    let bank1 = Array(bits.binaryArray[0 ..< 2])
    let bank2 = Array(bits.binaryArray[2 ..< 4])
    let bank3 = Array(bits.binaryArray[4 ..< 6])
    let bank4 = Array(bits.binaryArray[6 ..< 8])

    return "\(bank1), \(bank2), \(bank3), \(bank4)"
}

func obdCompliance(_ data: Data) -> String? {
    let i = data[1]

    if i < OBD_COMPLIANCE.count {
        return OBD_COMPLIANCE[Int(i)]
    } else {
        Logger.elm327.error("Invalid response for OBD compliance (no table entry)")
        return nil
    }
}

func fuelStatus(_ data: Data) -> String? {
    let bits = BitArray(data: data)
    var status_1: String?
    var status_2: String?

    let highBits = Array(bits.binaryArray[0 ..< 8])
    let lowBits = Array(bits.binaryArray[8 ..< 16])

    if highBits.filter({ $0 == 1 }).count == 1, let index = highBits.firstIndex(of: 1) {
        if 7 - index < FUEL_STATUS.count {
            status_1 = FUEL_STATUS[7 - index]
        } else {
            Logger.elm327.error("Invalid response for fuel status (high bits set)")
        }
    } else {
        Logger.elm327.error("Invalid response for fuel status (multiple/no bits set in high bits)")
    }

    if lowBits.filter({ $0 == 1 }).count == 1, let index = lowBits.firstIndex(of: 1) {
        if 7 - index < FUEL_STATUS.count {
            status_2 = FUEL_STATUS[7 - index]
        } else {
            Logger.elm327.error("Invalid response for fuel status (low bits set)")
        }
    } else {
        Logger.elm327.error("Invalid response for fuel status (multiple/no bits set in low bits)")
    }

    if let status_1 = status_1, let status_2 = status_2 {
        return "Status 1: \(status_1), Status 2: \(status_2)"
    } else if let status = status_1 ?? status_2 {
        return "Status: \(status)"
    } else {
        Logger.elm327.error("No valid status found.")
        return nil
    }
}

// 0 to 1.275 volts
func voltage(_ data: Data) -> MeasurementResult? {
    guard data.count == 2 else { return nil }
    let voltage = Double(data.first ?? 0) / 200
    return MeasurementResult(value: voltage, unit: UnitElectricPotentialDifference.volts)
}

func dtc(_ data: Data) -> [TroubleCode]? {
    // converts a frame of 2-byte DTCs into a list of DTCs
    let data = Data(data)
    var codes: [TroubleCode] = []
    // send data to parceDtc 2 byte at a time
    for n in stride(from: 0, to: data.count - 1, by: 2) {
        let endIndex = min(n + 1, data.count - 1)
        guard let dtc = parseDTC(data[n ... endIndex]) else {
            continue
        }
        codes.append(dtc)
    }
    return codes
}

func singleDtc(_ data: Data) -> TroubleCode? {
    return parseDTC(data)
}

func percent(_ data: Data) -> MeasurementResult? {
    var value = Double(data.first ?? 0)
    value = value * 100.0 / 255.0
    return MeasurementResult(value: value, unit: Unit.percent)
}

func percentCentered(_ data: Data) -> MeasurementResult? {
    var value = Double(data.first ?? 0)
    value = (value - 128) * 100.0 / 128.0
    return MeasurementResult(value: value, unit: Unit.percent)
}

// -128 to 128 mA
func currentCentered(_ data: Data) -> MeasurementResult? {
    var value = Double(bytesToInt(data[2 ... 3]))
    value = (value / 256.0) - 128.0
    return MeasurementResult(value: value, unit: UnitElectricCurrent.milliamperes)
}

// 0 to 1.275 volts
func sensorVoltage(_ data: Data) -> MeasurementResult? {
    let voltage = Double(data[0]) / 200
    return MeasurementResult(value: voltage, unit: UnitElectricPotentialDifference.volts)
}

func sensorVoltageBig(_ data: Data) -> MeasurementResult? {
    let value = bytesToInt(data[2 ..< 4])
    let voltage = (Double(value) * 8.0) / 65535
    return MeasurementResult(value: voltage, unit: UnitElectricPotentialDifference.volts)
}

// 0 to 765 kPa
func fuelPressure(_ data: Data) -> MeasurementResult? {
    var value = Double(data[0])
    value = value * 3
    return MeasurementResult(value: value, unit: UnitPressure.kilopascals)
}

// 0 to 255 kPa
func pressure(_ data: Data) -> MeasurementResult? {
    let value = data[0]
    return MeasurementResult(value: Double(value), unit: UnitPressure.kilopascals)
}

func airStatus(_ data: Data) -> MeasurementResult? {
    let bits = BitArray(data: data).binaryArray

    let numSet = bits.filter { $0 == 1 }.count
    if numSet == 1 {
        let index = 7 - bits.firstIndex(of: 1)!
        return MeasurementResult(value: Double(index), unit: UnitElectricCurrent.amperes)
    }
    return nil
}

func decodeTemp(_ data: Data, isMetric _: MeasurementUnits = .metric) -> MeasurementResult? {
    let value = Double(bytesToInt(data)) - 40.0
    return MeasurementResult(value: value, unit: UnitTemperature.celsius)
}

func timingAdvance(_ data: Data) -> MeasurementResult? {
    let value = Double(data.first ?? 0) / 2.0 - 64.0
    return MeasurementResult(value: value, unit: UnitAngle.degrees)
}

func decodeStatus(_ data: Data, isMetric _: MeasurementUnits = .metric) -> Status {
    let IGNITIONTYPE = ["Spark", "Compression"]
    //            ┌Components not ready
    //            |┌Fuel not ready
    //            ||┌Misfire not ready
    //            |||┌Spark vs. Compression
    //            ||||┌Components supported
    //            |||||┌Fuel supported
    //  ┌MIL      ||||||┌Misfire supported
    //  |         |||||||
    //  10000011 00000111 11111111 00000000
    //  00000000 00000111 11100101 00000000
    //  10111110 00011111 10101000 00010011
    //   [# DTC] X        [supprt] [~ready]

    // convert to binaryarray
    let bits = BitArray(data: data[1...])

    var output = Status()
    output.MIL = bits.binaryArray[0] == 1
    output.dtcCount = bits.value(at: 1 ..< 8)
    output.ignitionType = IGNITIONTYPE[bits.binaryArray[12]]

    // load the 3 base tests that are always present

    for (index, name) in baseTests.reversed().enumerated() {
        processBaseTest(name, index, bits, &output)
    }
    return output
}

func parse_monitor_test(_ data: Data) -> MonitorTest? {
    var test = MonitorTest()

    let tid = data[1]
    let cid = data[2]

    if let testInfo = TestIds[tid] {
        test.name = testInfo.0
        test.desc = testInfo.1
    } else {
        Logger.elm327.error("Encountered unknown Test ID: \(String(format: "%02x", tid))")
        test.name = "TID: $\(String(format: "%02x", tid)) CID: $\(String(format: "%02x", cid))"
        test.desc = "Unknown"
    }

    guard let uas = uasIDS[cid] else {
        Logger.elm327.error("Encountered Unknown Units and Scaling ID: \(String(format: "%02x", cid))")
        return nil
    }

    let valueRange = data[3 ... 4]
    let minRange = data[5 ... 6]
    let maxRange = data[7...]

    test.tid = tid
    test.value = uas.decode(bytes: valueRange)
    test.min = uas.decode(bytes: minRange).value
    test.max = uas.decode(bytes: maxRange).value
    return test
}

func parseDTC(_ data: Data) -> TroubleCode? {
    if (data.count != 2) || (data == Data([0x00, 0x00])) {
        return nil
    }
    guard let first = data.first, let second = data.last else { return nil }

    // BYTES: (16,      35      )
    // HEX:    4   1    2   3
    // BIN:    01000001 00100011
    //         [][][  in hex   ]
    //         | / /
    // DTC:    C0123
    var dtc = ["P", "C", "B", "U"][Int(first) >> 6] // the last 2 bits of the first byte
    dtc += String((first >> 4) & 0b0011) // the next pair of 2 bits. Mask off the bits we read above
    dtc += String(format: "%04X", (UInt16(first) & 0x3F) << 8 | UInt16(second)).dropFirst()
    // pull description from the DTCs array

    return TroubleCode(code: dtc, description: codes[dtc] ?? "No description available.")
}

func processBaseTest(_ testName: String, _ index: Int, _ bits: BitArray, _ output: inout Status) {
    let test = StatusTest(testName, bits.binaryArray[13 + index] != 0, bits.binaryArray[9 + index] == 0)
    switch testName {
    case "MISFIRE_MONITORING":
        output.misfireMonitoring = test
    case "FUEL_SYSTEM_MONITORING":
        output.fuelSystemMonitoring = test
    case "COMPONENT_MONITORING":
        output.componentMonitoring = test
    default:
        break
    }
}

public class Monitor {
    public var tests: [UInt8: MonitorTest] = [:]

//    init() {
//        for value in TestIds.allCases {
//            tests[value.rawValue] = MonitorTest(tid: value.rawValue, name: value.name, desc: value.desc, value: nil, min: nil, max: nil)
//        }
//    }
}

public struct MonitorTest {
    var tid: UInt8?
    var name: String?
    var desc: String?
    var value: MeasurementResult?
    var min: Double?
    var max: Double?

    var passed: Bool {
        guard let value = value, let min = min, let max = max else {
            return false
        }
        return value.value >= min && value.value <= max
    }

    var isNull: Bool {
        return tid == nil || value == nil || min == nil || max == nil
    }

    var description: String {
        return "\(desc ?? "") : \(value?.value ?? 0) [\(passed ? "PASSED" : "FAILED")]"
    }
}

let baseTests = [
    "MISFIRE_MONITORING",
    "FUEL_SYSTEM_MONITORING",
    "COMPONENT_MONITORING"
]

let sparkTests = [
    "CATALYST_MONITORING",
    "HEATED_CATALYST_MONITORING",
    "EVAPORATIVE_SYSTEM_MONITORING",
    "SECONDARY_AIR_SYSTEM_MONITORING",
    nil,
    "OXYGEN_SENSOR_MONITORING",
    "OXYGEN_SENSOR_HEATER_MONITORING",
    "EGR_VVT_SYSTEM_MONITORING"
]

let compressionTests = [
    "NMHC_CATALYST_MONITORING",
    "NOX_SCR_AFTERTREATMENT_MONITORING",
    nil,
    "BOOST_PRESSURE_MONITORING",
    nil,
    "EXHAUST_GAS_SENSOR_MONITORING",
    "PM_FILTER_MONITORING",
    "EGR_VVT_SYSTEM_MONITORING"
]

let FUEL_STATUS = [
    "Open loop due to insufficient engine temperature",
    "Closed loop, using oxygen sensor feedback to determine fuel mix",
    "Open loop due to engine load OR fuel cut due to deceleration",
    "Open loop due to system failure",
    "Closed loop, using at least one oxygen sensor but there is a fault in the feedback system"
]

let FuelTypes = [
    "Not available",
    "Gasoline",
    "Methanol",
    "Ethanol",
    "Diesel",
    "LPG",
    "CNG",
    "Propane",
    "Electric",
    "Bifuel running Gasoline",
    "Bifuel running Methanol",
    "Bifuel running Ethanol",
    "Bifuel running LPG",
    "Bifuel running CNG",
    "Bifuel running Propane",
    "Bifuel running Electricity",
    "Bifuel running electric and combustion engine",
    "Hybrid gasoline",
    "Hybrid Ethanol",
    "Hybrid Diesel",
    "Hybrid Electric",
    "Hybrid running electric and combustion engine",
    "Hybrid Regenerative",
    "Bifuel running diesel"
]

let OBD_COMPLIANCE = [
    "Undefined",
    "OBD-II as defined by the CARB",
    "OBD as defined by the EPA",
    "OBD and OBD-II",
    "OBD-I",
    "Not OBD compliant",
    "EOBD (Europe)",
    "EOBD and OBD-II",
    "EOBD and OBD",
    "EOBD, OBD and OBD II",
    "JOBD (Japan)",
    "JOBD and OBD II",
    "JOBD and EOBD",
    "JOBD, EOBD, and OBD II",
    "Reserved",
    "Reserved",
    "Reserved",
    "Engine Manufacturer Diagnostics (EMD)",
    "Engine Manufacturer Diagnostics Enhanced (EMD+)",
    "Heavy Duty On-Board Diagnostics (Child/Partial) (HD OBD-C)",
    "Heavy Duty On-Board Diagnostics (HD OBD)",
    "World Wide Harmonized OBD (WWH OBD)",
    "Reserved",
    "Heavy Duty Euro OBD Stage I without NOx control (HD EOBD-I)",
    "Heavy Duty Euro OBD Stage I with NOx control (HD EOBD-I N)",
    "Heavy Duty Euro OBD Stage II without NOx control (HD EOBD-II)",
    "Heavy Duty Euro OBD Stage II with NOx control (HD EOBD-II N)",
    "Reserved",
    "Brazil OBD Phase 1 (OBDBr-1)",
    "Brazil OBD Phase 2 (OBDBr-2)",
    "Korean OBD (KOBD)",
    "India OBD I (IOBD I)",
    "India OBD II (IOBD II)",
    "Heavy Duty Euro OBD Stage VI (HD EOBD-IV)"
]

let TestIds: [UInt8: (String, String)] = [
    0x01: ("RTLThresholdVoltage", "The voltage at which the sensor switches from rich to lean"),
    0x02: ("LTRThresholdVoltage", "The voltage at which the sensor switches from lean to rich"),
    0x03: ("LowVoltageSwitchTime", "The time it takes for the sensor to switch from rich to lean"),
    0x04: ("HighVoltageSwitchTime", "The time it takes for the sensor to switch from lean to rich"),
    0x05: ("RTLSwitchTime", "The time it takes for the sensor to switch from rich to lean"),
    0x06: ("LTRSwitchTime", "The time it takes for the sensor to switch from lean to rich"),
    0x07: ("MINVoltage", "The minimum voltage the sensor can output"),
    0x08: ("MAXVoltage", "The maximum voltage the sensor can output"),
    0x09: ("TransitionTime", "The time it takes for the sensor to transition from one voltage to another"),
    0x0A: ("SensorPeriod", "The time between sensor readings"),
    0x0B: ("MisFireAverage", "The average number of misfires per 1000 revolutions"),
    0x0C: ("MisFireCount", "The number of misfires since the last reset")
]
