💱 Exchange Rate Parser – Multi‑Language Edition

A powerful **exchange rate parser** that fetches live currency rates from a public API, displays them in a formatted table, and supports caching, filtering, and export to JSON/CSV.  
Built in **7 programming languages** – perfect for learning web scraping, API integration, or building financial tools.

## ✨ Features
- **Live rates** – fetches current exchange rates from a public API (exchangerate.host).
- **Caching** – stores rates in memory with a TTL (60 seconds) to reduce API calls.
- **Filter by currency** – show only specific currencies (e.g., `USD`, `EUR`, `UAH`).
- **Search** – find a currency by name or code.
- **Export** – save rates to JSON or CSV file.
- **Rate history** – stores the last 10 fetched snapshots (optional).
- **Interactive CLI** – easy‑to‑use menu with options.

## 🗂 Languages & Files
| Language          | File               |
|-------------------|-------------------|
| Python            | `parser.py`       |
| Go                | `parser.go`       |
| JavaScript (Node) | `parser.js`       |
| C#                | `Parser.cs`       |
| Java              | `Parser.java`     |
| Ruby              | `parser.rb`       |
| Swift             | `parser.swift`    |

## 🚀 How to Run
Each file is standalone – run it with the appropriate interpreter/compiler.

| Language | Command |
|----------|---------|
| Python   | `python parser.py` |
| Go       | `go run parser.go` |
| JavaScript | `node parser.js` |
| C#       | `dotnet run` (or `csc Parser.cs && Parser.exe`) |
| Java     | `javac Parser.java && java Parser` |
| Ruby     | `ruby parser.rb` |
| Swift    | `swift parser.swift` |

## 📊 Example Session
=== Exchange Rate Parser ===
Fetching rates from exchangerate.host...
Rates updated at 2026-07-12 14:32:45

Available currencies:
USD: 1.0000
EUR: 0.9200
GBP: 0.7850
UAH: 41.2000
JPY: 149.5000
...

Choose an option:

Show all rates

Filter by currency

Search currency

Export to JSON

Export to CSV

Refresh rates

Show history

Exit

text

## 🔧 Commands
| Option | Description |
|--------|-------------|
| `1` | Show all rates in a formatted table |
| `2` | Filter rates by currency code (comma‑separated) |
| `3` | Search for a currency by name or code |
| `4` | Export rates to JSON file |
| `5` | Export rates to CSV file |
| `6` | Manually refresh rates from API |
| `7` | Show rate history (last 10 snapshots) |
| `8` | Exit |

## 📁 Export Formats
- **JSON** – structured data with timestamp.
- **CSV** – simple table format compatible with spreadsheets.

## 🤝 Contributing
Add more data sources, support for historical rates, or a web interface – PRs welcome!

## 📜 License
MIT – use freely.
