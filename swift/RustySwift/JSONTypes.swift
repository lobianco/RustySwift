//
//  JSONTypes.swift
//  RustySwift
//
//  Created by Anthony on 10/25/19.
//  Copyright © 2019 Planet 4. All rights reserved.
//

import Foundation

// These structs are Swift representations of the request and response objects that
// the Rust function expects as input. They will be JSON encoded before travelling
// the FFI boundary, and JSON decoded at each endpoint.
//
struct WeatherRequest: Codable, Equatable {
    // A zip code to use for weather request.
    let zipCode: String
}

struct WeatherResponse: Codable, Equatable {
    // The name of the city from the supplied zip code.
    let cityName: String

    /// General description of current weather.
    let weatherDescription: String

    /// Temperature in Fahrenheit.
    let temperature: String
}

public class JSONTypes {
    class func encodeJSONRequest<T>(request: T) throws -> String? where T: Encodable {
        let jsonData = try JSONEncoder().encode(request)
        let string = String(data: jsonData, encoding: .utf8)
        return string
    }

    class func decodeJSONResponse<T>(response: String, type: T.Type) throws -> T? where T: Decodable {
        guard let jsonData = response.data(using: .utf8) else {
            return nil
        }

        let message = try JSONDecoder().decode(type, from: jsonData)
        return message
    }
}
