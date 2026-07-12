# parser.py
import requests
import json
import csv
import time
from datetime import datetime
from typing import Dict, List, Optional

class RateParser:
    def __init__(self, cache_ttl: int = 60):
        self.api_url = "https://api.exchangerate.host/latest?base=USD"
        self.rates: Dict[str, float] = {}
        self.last_update: Optional[datetime] = None
        self.cache_ttl = cache_ttl
        self.history: List[Dict] = []
        self._fetch_rates()

    def _fetch_rates(self) -> bool:
        try:
            response = requests.get(self.api_url, timeout=5)
            if response.status_code == 200:
                data = response.json()
                if data.get("success"):
                    self.rates = data["rates"]
                    self.last_update = datetime.now()
                    self.history.append({
                        "timestamp": self.last_update.isoformat(),
                        "rates": self.rates.copy()
                    })
                    if len(self.history) > 10:
                        self.history.pop(0)
                    return True
            return False
        except Exception as e:
            print(f"Error fetching rates: {e}")
            return False

    def get_rates(self) -> Dict[str, float]:
        if self.rates and self.last_update:
            if (datetime.now() - self.last_update).seconds > self.cache_ttl:
                self._fetch_rates()
        return self.rates

    def filter_rates(self, currencies: List[str]) -> Dict[str, float]:
        rates = self.get_rates()
        return {k: v for k, v in rates.items() if k in currencies}

    def search_currency(self, query: str) -> Dict[str, float]:
        rates = self.get_rates()
        query_lower = query.lower()
        return {k: v for k, v in rates.items() if query_lower in k.lower()}

    def refresh(self) -> bool:
        return self._fetch_rates()

    def export_json(self, filename: str = "rates.json") -> bool:
        try:
            data = {
                "timestamp": self.last_update.isoformat() if self.last_update else None,
                "rates": self.get_rates()
            }
            with open(filename, 'w') as f:
                json.dump(data, f, indent=2)
            return True
        except Exception as e:
            print(f"Export failed: {e}")
            return False

    def export_csv(self, filename: str = "rates.csv") -> bool:
        try:
            rates = self.get_rates()
            with open(filename, 'w', newline='') as f:
                writer = csv.writer(f)
                writer.writerow(["Currency", "Rate"])
                for curr, rate in sorted(rates.items()):
                    writer.writerow([curr, rate])
            return True
        except Exception as e:
            print(f"Export failed: {e}")
            return False

    def show_history(self):
        if not self.history:
            print("No history yet.")
            return
        for i, entry in enumerate(self.history[-5:], 1):
            print(f"[{i}] {entry['timestamp']} – {len(entry['rates'])} currencies")

    def display_rates(self, rates: Dict[str, float] = None):
        if rates is None:
            rates = self.get_rates()
        if not rates:
            print("No rates available.")
            return
        print(f"\nRates (USD base) – updated: {self.last_update}")
        print("-" * 40)
        for curr, rate in sorted(rates.items())[:20]:
            print(f"{curr:5} : {rate:.4f}")
        if len(rates) > 20:
            print(f"... and {len(rates)-20} more")

def main():
    parser = RateParser()
    print("=== Exchange Rate Parser ===")
    while True:
        print("\n1. Show all rates")
        print("2. Filter by currency")
        print("3. Search currency")
        print("4. Export to JSON")
        print("5. Export to CSV")
        print("6. Refresh rates")
        print("7. Show history")
        print("8. Exit")
        choice = input("Choose: ").strip()
        if choice == "1":
            parser.display_rates()
        elif choice == "2":
            currencies = input("Enter currency codes (comma-separated): ").strip().upper().split(',')
            currencies = [c.strip() for c in currencies if c.strip()]
            if currencies:
                filtered = parser.filter_rates(currencies)
                parser.display_rates(filtered)
            else:
                print("No currencies specified.")
        elif choice == "3":
            query = input("Enter currency code or name: ").strip()
            if query:
                found = parser.search_currency(query)
                parser.display_rates(found)
            else:
                print("Query cannot be empty.")
        elif choice == "4":
            filename = input("Filename (default: rates.json): ").strip() or "rates.json"
            if parser.export_json(filename):
                print(f"Exported to {filename}")
        elif choice == "5":
            filename = input("Filename (default: rates.csv): ").strip() or "rates.csv"
            if parser.export_csv(filename):
                print(f"Exported to {filename}")
        elif choice == "6":
            if parser.refresh():
                print("Rates refreshed.")
            else:
                print("Refresh failed.")
        elif choice == "7":
            parser.show_history()
        elif choice == "8":
            print("Goodbye!")
            break
        else:
            print("Invalid choice.")

if __name__ == "__main__":
    main()
