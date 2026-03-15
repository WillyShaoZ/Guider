import Foundation
import CoreLocation

final class EmergencySMSService {
    private let locationManager = CLLocationManager()

    func sendEmergencySMS(
        to phoneNumber: String,
        userName: String,
        contactName: String,
        completion: @escaping (Bool) -> Void
    ) {
        // Get current location
        let location = locationManager.location
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)

        var message = "EMERGENCY ALERT from Guider App.\n\n"
        message += "\(userName.isEmpty ? "A Guider user" : userName) may have fallen and is not responding.\n\n"
        message += "Time: \(timestamp)\n"

        if let location {
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            message += "Location: \(String(format: "%.6f", lat)), \(String(format: "%.6f", lon))\n"
            message += "Map: https://maps.google.com/?q=\(lat),\(lon)\n"
        } else {
            message += "Location: unavailable\n"
        }

        message += "\nPlease try to call or check on them immediately."

        // Send via TextBelt (free SMS API)
        let cleaned = phoneNumber.filter { $0.isNumber || $0 == "+" }

        guard let url = URL(string: "https://textbelt.com/text") else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "phone": cleaned,
            "message": message,
            "key": "textbelt" // free tier: 1 SMS/day
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("[EmergencySMS] Failed to encode body: \(error)")
            completion(false)
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                print("[EmergencySMS] Request failed: \(error)")
                completion(false)
                return
            }

            if let data,
               let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = result["success"] as? Bool {
                print("[EmergencySMS] Result: \(result)")
                completion(success)
            } else {
                completion(false)
            }
        }.resume()
    }

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
}
