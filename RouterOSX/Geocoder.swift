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
    case error(GeocodingFailure)
    case ok(GeocodedPlace)
}

class Geocoder {
    let place: String
    let callback: ([GeocodingResult]) -> ()

    init(place: String, callback: @escaping ([GeocodingResult]) -> ()) {
        self.place = place
        self.callback = callback
    }

    func geocode() {
        let geocoders = [
            geocodeYandex,
            geocodeGoogle,
            geocodeOsm,
        ]

        for coder in geocoders {
            coder(self.place)
        }
    }

    func geocodeYandex(_ place: String) {
        let request = AF.request(
            "https://geocode-maps.yandex.ru/1.x/",
            parameters: ["geocode": place, "format": "json"]
        )

        let providerName = "yandex"

        let extractPoints = {
            (json: JSON) in json["response"]["GeoObjectCollection"]["featureMember"]
        }

        let convertPoint = {
            (point: JSON) -> GeocodedPlace? in

            guard
                let name = point["GeoObject"]["metaDataProperty"]["GeocoderMetaData"]["text"].string,
                let coordsStr = point["GeoObject"]["Point"]["pos"].string
            else {
                return nil
            }

            let coords = coordsStr.components(separatedBy: " ")
            return GeocodedPlace(
                name: name,
                provider: providerName,
                lat: Double(coords[1]) ?? 0.0,
                lon: Double(coords[0]) ?? 0.0
            )
        }

        genericGeocode(request, providerName, extractPoints, convertPoint)
    }

    func geocodeGoogle(_ place: String) {
        let request = AF.request(
            "https://maps.googleapis.com/maps/api/geocode/json",
            parameters: ["address": place]
        )

        let providerName = "google"

        let extractPoints = {
            (json: JSON) in json["results"]
        }

        let convertPoint = {
            (point: JSON) -> GeocodedPlace? in

            guard let name = point["formatted_address"].string else {
                return nil
            }
            let coords = point["geometry"]["location"]
            return GeocodedPlace(
                name: name,
                provider: providerName,
                lat: coords["lat"].double ?? 0.0,
                lon: coords["lng"].double ?? 0.0
            )
        }

        genericGeocode(request, providerName, extractPoints, convertPoint)
    }

    func geocodeOsm(_ place: String) {
        let request = AF.request(
            "https://nominatim.openstreetmap.org/search",
            parameters: ["q": place, "format": "json"]
        )

        let providerName = "osm"

        let extractPoints = {
            (json: JSON) in json
        }

        let convertPoint = {
            (point: JSON) -> GeocodedPlace? in

            guard
                let name = point["display_name"].string,
                let lat = point["lat"].string,
                let lon = point["lon"].string
            else {
                return nil
            }

            return GeocodedPlace(
                name: name,
                provider: providerName,
                lat: Double(lat) ?? 0.0,
                lon: Double(lon) ?? 0.0
            )
        }

        genericGeocode(request, providerName, extractPoints, convertPoint)
    }

    func genericGeocode(
            _ request: DataRequest,
            _ provider: String,
            _ extractPoints: @escaping (JSON) -> JSON,
            _ convertPoint: @escaping (JSON) -> GeocodedPlace?
    ) {
        request.responseJSON {
            response in

            switch response.result {
            case .success:
                if let value = response.value {
                    let points = extractPoints(JSON(value))
                    var results = [GeocodingResult]()
                    for (_, p) in points {
                        if let result = convertPoint(p) {
                            results.append(.ok(result))
                        }
                    }
                    self.callback(results)
                } else {
                    self.onFailure(provider, "Failed to decode JSON")
                }
            case .failure(let error):
                self.onFailure(provider, error.localizedDescription)
            }
        }
    }

    func onFailure(_ provider: String, _ error: String) {
        let failure = GeocodingFailure(provider: provider, error: error)
        self.callback([.error(failure)])
    }
}
