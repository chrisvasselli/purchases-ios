//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  Decoder+Extensions.swift
//
//  Created by Joshua Liebowitz on 10/25/21.

import Foundation

enum CodableError: Error, CustomStringConvertible, LocalizedError {

    case unexpectedValue(Any.Type, Any)
    case valueNotFound(value: Any.Type, context: DecodingError.Context)
    case invalidJSONObject(value: [String: Any])

    var description: String {
        switch self {
        case let .unexpectedValue(type, value):
            return Strings.codable.unexpectedValueError(type: type, value: value).description
        case let .valueNotFound(value, context):
            return Strings.codable.valueNotFoundError(value: value, context: context).description
        case let .invalidJSONObject(value):
            return Strings.codable.invalid_json_error(jsonData: value).description
        }
    }

    var errorDescription: String? { return self.description }

}

extension Decoder {

    func valueNotFoundError(expectedType: Any.Type, message: String) -> CodableError {
        let context = DecodingError.Context(codingPath: codingPath,
                                            debugDescription: message,
                                            underlyingError: nil)
        return CodableError.valueNotFound(value: expectedType, context: context)
    }

}

extension JSONDecoder {

    /// Decodes a top-level value of the given type from the given Data containing a JSON representation of `type`.
    ///
    /// - Parameters:
    ///   - type: The type of the value to decode. The default is `T.self`.
    ///   - data: The data to decode from.
    /// - Returns: A value of the requested type.
    /// - throws: `CodableError` or `DecodableError` if the data is invalid or can't be deserialized.
    func decode<T: Decodable>(
        _ type: T.Type = T.self,
        jsonData: Data,
        logErrors: Bool = true
    ) throws -> T {
        do {
            return try self.decode(type, from: jsonData)
        } catch {
            if logErrors {
                ErrorUtils.logDecodingError(error, type: type)
            }
            throw error
        }
    }

    /// Decodes a top-level value of the given type from the given Dictionary.
    ///
    /// - Parameters:
    ///   - type: The type of the value to decode. The default is `T.self`.
    ///   - dictionary: The dictionary to decode from.
    /// - Returns: A value of the requested type.
    /// - Throws: `CodableError` or `DecodableError` if the data is invalid or can't be deserialized.
    /// - Note: this method logs the error before throwing, so it's "safe" to use with `try?`
    func decode<T: Decodable>(
        _ type: T.Type = T.self,
        dictionary: [String: Any],
        logErrors: Bool = true
    ) throws -> T {
        if JSONSerialization.isValidJSONObject(dictionary) {
            return try self.decode(type,
                                   jsonData: try JSONSerialization.data(withJSONObject: dictionary),
                                   logErrors: logErrors)
        } else {
            throw CodableError.invalidJSONObject(value: dictionary)
        }
    }

}

extension JSONEncoder {

    /// Encodes a top-level value containing a JSON representation of `type`
    ///
    /// - Parameters:
    ///   - type: The type of the value to encode. The default is `T.self`.
    ///   - data: The data to encode.
    /// - Returns: The encoded `Data`
    /// - throws: `CodableError` or `EncodableError` if the data is invalid or can't be deserialized.
    func encode<T: Encodable>(
        _ type: T.Type = T.self,
        value: T,
        logErrors: Bool = true
    ) throws -> Data {
        do {
            return try self.encode(value)
        } catch {
            if logErrors {
                ErrorUtils.logEncodingError(error, type: type)
            }
            throw error
        }
    }

}

// MARK: Decoding Error handling

extension ErrorUtils {

    static func logDecodingError(_ error: Error, type: Any.Type) {
        guard let decodingError = error as? DecodingError else {
            Logger.error(Strings.codable.decoding_error(error))
            return
        }

        switch decodingError {
        case let .dataCorrupted(context):
            Logger.error(Strings.codable.corrupted_data_error(context: context))
        case let .keyNotFound(key, context):
            // This is expected to happen occasionally, the backend doesn't always populate all key/values.
            Logger.debug(Strings.codable.keyNotFoundError(type: type, key: key, context: context))
        case let .valueNotFound(value, context):
            Logger.debug(Strings.codable.valueNotFoundError(value: value, context: context))
        case let .typeMismatch(type, context):
            Logger.error(Strings.codable.typeMismatch(type: type, context: context))
        @unknown default:
            Logger.error("Unhandled DecodingError: \(decodingError)\n\(Strings.codable.decoding_error(decodingError))")
        }
    }

    static func logEncodingError(_ error: Error, type: Any.Type) {
        guard let encodingError = error as? EncodingError else {
            Logger.error(Strings.codable.encoding_error(error))
            return
        }

        switch encodingError {
        case .invalidValue:
            Logger.error(Strings.codable.encoding_error(encodingError))
        @unknown default:
            Logger.error("Unhandled EncodingError: \(encodingError)\n\(Strings.codable.encoding_error(encodingError))")
        }
    }

}

extension Encodable {

    func asDictionary() throws -> [String: Any] {
        return try JSONEncoder.default
            .encode(self)
            .asJSONDictionary()

    }

}

extension Data {

    func asJSONDictionary() throws -> [String: Any] {
        let result = try JSONSerialization.jsonObject(with: self, options: [])

        guard let result = result as? [String: Any] else {
            throw CodableError.unexpectedValue(type(of: result), result)
        }

        return result
    }

}
