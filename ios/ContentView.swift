import SwiftUI

struct ContentView: View {
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var resultText = ""

    let apiURL = URL(string: "http://your-api-address:5000/recommend-team-travel")! // Replace with your API URL
    let dateFormatter = DateFormatter()

    var body: some View {
        VStack {
            Text("Commute Advisor")
                .font(.title)
                .padding(.bottom)

            DatePicker("Start Time Window", selection: $startTime, displayedComponents: .hourAndMinute)
                .padding(.horizontal)

            DatePicker("End Time Window", selection: $endTime, displayedComponents: .hourAndMinute)
                .padding(.horizontal)

            Button("Get Best Departure Time") {
                getBestDepartureTime()
            }
            .padding()

            Text(resultText)
                .padding()

            Spacer()
        }
        .onAppear {
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }
    }

    func getBestDepartureTime() {
        guard let fromAddress = "User's Home Address" as? String, // Replace
              let toAddress = "Office Address" as? String else { // Replace
            resultText = "Please provide valid addresses."
            return
        }

        let startTimeWindow = dateFormatter.string(from: startTime)
        let endTimeWindow = dateFormatter.string(from: endTime)

        let parameters: [String: Any] = [
            "startTimeWindow": startTimeWindow,
            "endTimeWindow": endTimeWindow,
            "fromAddresses": [fromAddress],
            "toAddress": toAddress,
            "infrastructureCostFactor": 0.5
            // Add other parameters if needed
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters) else {
            resultText = "Error encoding data."
            return
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    resultText = "Error: \(error.localizedDescription)"
                }
                return
            }

            guard let data = data, let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    resultText = "Error: Invalid response from server."
                }
                return
            }

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let bestDepartureTime = jsonResponse["bestDepartureTime"] as? String {
                        DispatchQueue.main.async {
                            resultText = "Best Departure Time: \(bestDepartureTime)"
                        }
                    } else if let error = jsonResponse["error"] as? String {
                        DispatchQueue.main.async {
                            resultText = "Error from API: \(error)"
                        }
                    } else {
                        DispatchQueue.main.async {
                            resultText = "Error: Unexpected response format."
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    resultText = "Error parsing JSON: \(error.localizedDescription)"
                }
            }
        }
        .resume()
    }
}
