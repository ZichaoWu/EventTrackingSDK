//
//  AnyCodable.swift
//  Event Tracking SDK
//
//  Created by mac on 2026/3/18.
//

import Foundation

public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let int64Value = value as? Int64 {
            try container.encode(int64Value)
        } else if let floatValue = value as? Float {
            try container.encode(Double(floatValue))
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else if let dateValue = value as? Date {
            try container.encode(dateValue.timeIntervalSince1970)
        } else if let urlValue = value as? URL {
            try container.encode(urlValue.absoluteString)
        } else if let arrayValue = value as? [Any] {
            try container.encode(arrayValue.map { AnyCodable($0) })
        } else if let dictValue = value as? [String: Any] {
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        } else if value is NSNull {
            try container.encodeNil()
        } else if let dataValue = value as? Data {
            try container.encode(dataValue.base64EncodedString())
        } else {
            try container.encodeNil()
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let int64Value = try? container.decode(Int64.self) {
            value = int64Value
        } else if let floatValue = try? container.decode(Float.self) {
            value = floatValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            if let urlValue = URL(string: stringValue), stringValue.hasPrefix("http") {
                value = urlValue
            } else {
                value = stringValue
            }
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else if let dataValue = try? container.decode(Data.self) {
            value = dataValue
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            value = NSNull()
        }
    }
}
