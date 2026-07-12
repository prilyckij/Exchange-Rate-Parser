// parser.swift
import Foundation

struct RateResponse: Codable {
    let success: Bool
    let rates: [String: Double]
}

struct HistoryEntry: Codable {
    let timestamp: String
    let rates: [String: Double]
}

class RateParser {
    private let apiURL = "https://api.exchangerate.host/latest?base=USD"
    private let cacheTTL = 60
    private var rates: [String: Double] = [:]
    private var lastUpdate: Date?
    private var history: [HistoryEntry] = []

    init() {
        fetchRates()
    }

    @discardableResult
    func fetchRates() -> Bool {
        guard let url = URL(string: apiURL) else { return false }
        let semaphore = DispatchSemaphore(value: 0)
        var success = false

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            defer { semaphore.signal() }
            guard let data = data, error == nil else {
                print("Error fetching rates: \(error?.localizedDescription ?? "unknown")")
                return
            }
            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(RateResponse.self, from: data)
                if result.success {
                    self.rates = result.rates
                    self.lastUpdate = Date()
                    self.history.append(HistoryEntry(
                        timestamp: self.lastUpdate!.ISO8601Format(),
                        rates: result.rates
                    ))
                    if self.history.count > 10 {
                        self.history.removeFirst()
                    }
                    success = true
                }
            } catch {
                print("Error parsing JSON: \(error)")
            }
        }
        task.resume()
        semaphore.wait()
        return success
    }

    func getRates() -> [String: Double] {
        if let lastUpdate = lastUpdate {
            if Date().timeIntervalSince(lastUpdate) > TimeInterval(cacheTTL) {
                fetchRates()
            }
        }
        return rates
    }

    func filterRates(currencies: [String]) -> [String: Double] {
        let allRates = getRates()
        var result: [String: Double] = [:]
        for c in currencies {
            if let rate = allRates[c] {
                result[c] = rate
            }
        }
        return result
    }

    func searchCurrency(query: String) -> [String: Double] {
        let allRates = getRates()
        var result: [String: Double] = [:]
        let q = query.lowercased()
        for (k, v) in allRates {
            if k.lowercased().contains(q) {
                result[k] = v
            }
        }
        return result
    }

    @discardableResult
    func refresh() -> Bool {
        return fetchRates()
    }

    func exportJSON(filename: String = "rates.json") -> Bool {
        let data: [String: Any] = [
            "timestamp": lastUpdate?.ISO8601Format() ?? "unknown",
            "rates": getRates()
        ]
        do {
            let json = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            try json.write(to: URL(fileURLWithPath: filename))
            return true
        } catch {
            print("Export failed: \(error)")
            return false
        }
    }

    func exportCSV(filename: String = "rates.csv") -> Bool {
        let rates = getRates()
        var lines = ["Currency,Rate"]
        for (k, v) in rates.sorted(by: { $0.key < $1.key }) {
            lines.append("\(k),\(String(format: "%.4f", v))")
        }
        do {
            try lines.joined(separator: "\n").write(toFile: filename, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Export failed: \(error)")
            return false
        }
    }

    func showHistory() {
        if history.isEmpty {
            print("No history yet.")
            return
        }
        for (i, entry) in history.enumerated() {
            print("[\(i+1)] \(entry.timestamp) – \(entry.rates.count) currencies")
        }
    }

    func displayRates(rates: [String: Double]? = nil) {
        let displayRates = rates ?? getRates()
        if displayRates.isEmpty {
            print("No rates available.")
            return
        }
        let dateStr = lastUpdate?.formatted() ?? "unknown"
        print("\nRates (USD base) – updated: \(dateStr)")
        print(String(repeating: "-", count: 40))
        var count = 0
        for (k, v) in displayRates.sorted(by: { $0.key < $1.key }) {
            if count >= 20 { break }
            print("\(k.padding(toLength: 5, withPad: " ", startingAt: 0)) : \(String(format: "%.4f", v))")
            count += 1
        }
        if displayRates.count > 20 {
            print("... and \(displayRates.count - 20) more")
        }
    }
}

func main() {
    let parser = RateParser()
    print("=== Exchange Rate Parser ===")
    while true {
        print("\n1. Show all rates")
        print("2. Filter by currency")
        print("3. Search currency")
        print("4. Export to JSON")
        print("5. Export to CSV")
        print("6. Refresh rates")
        print("7. Show history")
        print("8. Exit")
        print("Choose: ", terminator: "")
        guard let choice = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else { continue }
        switch choice {
        case "1":
            parser.displayRates()
        case "2":
            print("Enter currency codes (comma-separated): ", terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else { break }
            let currencies = input.uppercased().split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if !currencies.isEmpty {
                let filtered = parser.filterRates(currencies: currencies)
                parser.displayRates(rates: filtered)
            } else {
                print("No currencies specified.")
            }
        case "3":
            print("Enter currency code or name: ", terminator: "")
            guard let query = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty else {
                print("Query cannot be empty.")
                break
            }
            let found = parser.searchCurrency(query: query)
            parser.displayRates(rates: found)
        case "4":
            print("Filename (default: rates.json): ", terminator: "")
            var fname = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "rates.json"
            if fname.isEmpty { fname = "rates.json" }
            if parser.exportJSON(filename: fname) {
                print("Exported to \(fname)")
            }
        case "5":
            print("Filename (default: rates.csv): ", terminator: "")
            var fname = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "rates.csv"
            if fname.isEmpty { fname = "rates.csv" }
            if parser.exportCSV(filename: fname) {
                print("Exported to \(fname)")
            }
        case "6":
            if parser.refresh() {
                print("Rates refreshed.")
            } else {
                print("Refresh failed.")
            }
        case "7":
            parser.showHistory()
        case "8":
            print("Goodbye!")
            return
        default:
            print("Invalid choice.")
        }
    }
}

main()
