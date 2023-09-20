//
//  ViewController.swift
//  RustySwift
//
//  Created by Anthony on 10/25/19.
//  Copyright © 2019 Planet 4. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()

        fetchWeather(for: "11211")
    }
    
    private func fetchWeather(for zipCode: String) {
        print("Fetching weather for " + zipCode + "...")
        
        let request = WeatherRequest(
            zipCode: zipCode
        )
        
        guard let requestString = try? JSONTypes.encodeJSONRequest(request: request) else {
            print("failed to encode JSON request")
            return
        }
        
        RustySwift.rustyFetchWeather(with: requestString) { [weak self] (response) in
            guard let response = response,
                  let decodedResponse = try? JSONTypes.decodeJSONResponse(response: response, type: WeatherResponse.self) else {
                self?.view.backgroundColor = .red
                print("failed to decode JSON response")
                return
            }

            self?.view.backgroundColor = .green
            print("Done! Weather for " + decodedResponse.cityName + ": " + decodedResponse.weatherDescription + " and " + decodedResponse.temperature + "ºF")
        }
    }
    
}

