#![deny(warnings)]
#![forbid(unused_must_use)]

use hyper::{Body, Chunk, Uri, Response, Client};
use serde_derive::{Deserialize, Serialize};
use serde_json::Value;

pub type Result<T> = std::result::Result<T, Box<dyn std::error::Error + Send + Sync>>;

/// Input parameters for fetch_weather(). The input data should be a JSON list of key-value pairs,
/// wherein each key is a website address and the respective value is a unix timestamp associated
/// with that website in some arbitrary way (e.g. last time the home page was modified, last time
/// the server was compromised, etc).
///
#[derive(Default, Deserialize, Debug, PartialEq)]
pub struct WeatherRequest {
    /// A zip code to use for weather request.
    #[serde(rename = "zipCode")]
    pub zip_code: String,
}

/// Weather result.
#[derive(Default, Serialize, Debug, PartialEq)]
pub struct WeatherResponse {
    /// The name of the city from the supplied zip code.
    #[serde(rename = "cityName")]
    pub city_name: String,

    /// General description of current weather.
    #[serde(rename = "weatherDescription")]
    pub weather_description: String,

    /// Temperature in Fahrenheit.
    pub temperature: String,
}

/// Takes a WeatherRequest and returns a WeatherResponse.
pub async fn fetch_weather(request: WeatherRequest) -> Result<WeatherResponse> {
    // configure parameters
    let api_key: &str = "b0db7714de90e7adb08296d9c4eee1f6";
    let zip: String = request.zip_code;
    let url_string: String =
        format!("http://api.openweathermap.org/data/2.5/weather?zip={}&APPID={}&units=imperial", zip, api_key);

    // fire off the request
    let url: Uri = url_string.parse::<hyper::Uri>().unwrap();
    let client = Client::new();
    let response: Response<Body> = client.get(url).await?;

    // resolve the response
    let mut body: Body = response.into_body();
    let mut bytes: Vec<u8> = Vec::new();
    while let Some(next) = body.next().await {
        let chunk: Chunk = next?;
        bytes.extend(chunk);
    }

    // parse the json
    let json_body: &str = std::str::from_utf8(&bytes).expect("bad encoding");
    let json_value: Value = serde_json::from_str(json_body).unwrap();

    // retrieve the important values
    Ok(WeatherResponse{
        city_name: json_value["name"].to_string().replace("\"", ""),
        weather_description: json_value["weather"][0]["description"].to_string().replace("\"", ""),
        temperature: json_value["main"]["temp"].to_string()
    })
}
