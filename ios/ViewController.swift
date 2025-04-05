import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var startTimePicker: UIDatePicker!
    @IBOutlet weak var endTimePicker: UIDatePicker!
    @IBOutlet weak var resultLabel: UILabel!

    let apiURL = URL(string: "http://your-api-address:5000/recommend-team-travel")! // Replace with your API URL
    let dateFormatter = DateFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // Format for API
    }

    @IBAction func getBestDepartureTimeTapped(_ sender: UIButton) {
        guard let fromAddress = "User's Home Address" as? String, // Replace with user input or stored location
              let toAddress = "Office Address" as? String else { // Replace with office location
            self.resultLabel.text = "Please provide valid addresses."
            return
        }

        let startTimeWindow = dateFormatter.string(from: startTimePicker.date)
        let endTimeWindow = dateFormatter.string(from: endTimePicker.date)

        let parameters: [String: Any] = [
            "startTimeWindow": startTimeWindow,
            "endTimeWindow": endTimeWindow,
            "fromAddresses": [fromAddress], // Send as a list, even for one user
            "toAddress": toAddress,
            "infrastructureCostFactor": 0.5 // Adjust as needed
            // Add other necessary parameters (e.g., weather, congestion) if you're not getting them from API
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters) else {
            self.resultLabel.text = "Error encoding data."
            return
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.resultLabel.text = "Error: \(error.localizedDescription)"
                }
                return
            }

            guard let data = data, let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    self.resultLabel.text = "Error: Invalid response from server."
                }
                return
            }

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let bestDepartureTime = jsonResponse["bestDepartureTime"] as? String {
                        DispatchQueue.main.async {
                            self.resultLabel.text = "Best Departure Time: \(bestDepartureTime)"
                        }
                    } else if let error = jsonResponse["error"] as? String {
                        DispatchQueue.main.async {
                            self.resultLabel.text = "Error from API: \(error)"
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.resultLabel.text = "Error: Unexpected response format."
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.resultLabel.text = "Error parsing JSON: \(error.localizedDescription)"
                }
            }
        }

        task.resume()
    }
}
