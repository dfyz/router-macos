import Alamofire
import Foundation
import SwiftyJSON

struct GeocodedPlace {
    let name: String
    let provider: String
    let lat: Float64
    let lon: Float64
}

struct GeocodingFailure {
    let provider: String
    let error: String
}

enum GeocodingResult {
    case Error(GeocodingFailure)
    case Ok(GeocodedPlace)
}

class Geocoder {
    let place: String
    let callback: [GeocodingResult] -> ()

    init(place: String, callback: [GeocodingResult] -> ()) {
        self.place = place
        self.callback = callback
    }

    func geocode() {
        let geocoders = [
            geocodeYandex,
            // geocodeGoogle,
            // geocodeOsm,
        ]

        for coder in geocoders {
            coder(self.place)
        }
    }

    func geocodeYandex(place: String) {
        let request = Alamofire.request(
            .GET,
            "https://geocode-maps.yandex.ru/1.x/",
            parameters: ["geocode": place, "format": "json"]
        )

        let providerName = "yandex"

        let extractPoints = {
            (json: JSON) in json["response"]["GeoObjectCollection"]["featureMember"]
        }

        let convertPoint = {
            (point: JSON) -> GeocodedPlace? in

            guard let name = point["GeoObject"]["metaDataProperty"]["GeocoderMetaData"]["text"].string else {
                return nil
            }
            guard let coordsStr = point["GeoObject"]["Point"]["pos"].string else {
                return nil
            }

            let coords = coordsStr.componentsSeparatedByString(" ");
            return GeocodedPlace(
                name: name,
                provider: providerName,
                lat: Double(coords[1]) ?? 0.0,
                lon: Double(coords[0]) ?? 0.0
            )
        }

        genericGeocode(request, providerName, extractPoints, convertPoint)
    }

    func genericGeocode(
            request: Request,
            _ provider: String,
            _ extractPoints: JSON -> JSON,
            _ convertPoint: JSON -> GeocodedPlace?
    ) {
        request.responseJSON {
            response in

            switch response.result {
            case .Success:
                if let value = response.result.value {
                    let points = extractPoints(JSON(value))
                    var results = [GeocodingResult]()
                    for (_, p) in points {
                        if let result = convertPoint(p) {
                            results.append(.Ok(result))
                        }
                    }
                    self.callback(results)
                } else {
                    self.onFailure(provider, "Failed to decode JSON")
                }
            case .Failure(let error):
                self.onFailure(provider, error.localizedDescription)
            }
        }
    }

    func onFailure(provider: String, _ error: String) {
        let failure = GeocodingFailure(provider: provider, error: error)
        self.callback([.Error(failure)])
    }
}
