// parser.go
package main

import (
	"bufio"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"
)

type RateResponse struct {
	Success bool               `json:"success"`
	Rates   map[string]float64 `json:"rates"`
}

type RateParser struct {
	apiURL     string
	rates      map[string]float64
	lastUpdate time.Time
	cacheTTL   int
	history    []HistoryEntry
}

type HistoryEntry struct {
	Timestamp string             `json:"timestamp"`
	Rates     map[string]float64 `json:"rates"`
}

func NewRateParser() *RateParser {
	p := &RateParser{
		apiURL:   "https://api.exchangerate.host/latest?base=USD",
		cacheTTL: 60,
		history:  []HistoryEntry{},
	}
	p.fetchRates()
	return p
}

func (p *RateParser) fetchRates() bool {
	resp, err := http.Get(p.apiURL)
	if err != nil {
		fmt.Println("Error fetching rates:", err)
		return false
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		fmt.Println("Error reading response:", err)
		return false
	}
	var data RateResponse
	if err := json.Unmarshal(body, &data); err != nil {
		fmt.Println("Error parsing JSON:", err)
		return false
	}
	if !data.Success {
		fmt.Println("API returned success=false")
		return false
	}
	p.rates = data.Rates
	p.lastUpdate = time.Now()
	p.history = append(p.history, HistoryEntry{
		Timestamp: p.lastUpdate.Format(time.RFC3339),
		Rates:     copyMap(p.rates),
	})
	if len(p.history) > 10 {
		p.history = p.history[1:]
	}
	return true
}

func copyMap(src map[string]float64) map[string]float64 {
	dst := make(map[string]float64)
	for k, v := range src {
		dst[k] = v
	}
	return dst
}

func (p *RateParser) getRates() map[string]float64 {
	if p.rates != nil && !p.lastUpdate.IsZero() {
		if int(time.Since(p.lastUpdate).Seconds()) > p.cacheTTL {
			p.fetchRates()
		}
	}
	return p.rates
}

func (p *RateParser) filterRates(currencies []string) map[string]float64 {
	rates := p.getRates()
	result := make(map[string]float64)
	for _, c := range currencies {
		if val, ok := rates[c]; ok {
			result[c] = val
		}
	}
	return result
}

func (p *RateParser) searchCurrency(query string) map[string]float64 {
	rates := p.getRates()
	result := make(map[string]float64)
	q := strings.ToLower(query)
	for k, v := range rates {
		if strings.Contains(strings.ToLower(k), q) {
			result[k] = v
		}
	}
	return result
}

func (p *RateParser) refresh() bool {
	return p.fetchRates()
}

func (p *RateParser) exportJSON(filename string) bool {
	data := struct {
		Timestamp string             `json:"timestamp"`
		Rates     map[string]float64 `json:"rates"`
	}{
		Timestamp: p.lastUpdate.Format(time.RFC3339),
		Rates:     p.getRates(),
	}
	jsonData, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		fmt.Println("JSON marshal error:", err)
		return false
	}
	if err := ioutil.WriteFile(filename, jsonData, 0644); err != nil {
		fmt.Println("Write error:", err)
		return false
	}
	return true
}

func (p *RateParser) exportCSV(filename string) bool {
	rates := p.getRates()
	file, err := os.Create(filename)
	if err != nil {
		fmt.Println("Create error:", err)
		return false
	}
	defer file.Close()
	writer := csv.NewWriter(file)
	defer writer.Flush()
	writer.Write([]string{"Currency", "Rate"})
	for curr, rate := range rates {
		writer.Write([]string{curr, strconv.FormatFloat(rate, 'f', 4, 64)})
	}
	return true
}

func (p *RateParser) showHistory() {
	if len(p.history) == 0 {
		fmt.Println("No history yet.")
		return
	}
	for i, entry := range p.history {
		fmt.Printf("[%d] %s – %d currencies\n", i+1, entry.Timestamp, len(entry.Rates))
	}
}

func (p *RateParser) displayRates(rates map[string]float64) {
	if rates == nil {
		rates = p.getRates()
	}
	if len(rates) == 0 {
		fmt.Println("No rates available.")
		return
	}
	fmt.Printf("\nRates (USD base) – updated: %s\n", p.lastUpdate.Format("2006-01-02 15:04:05"))
	fmt.Println(strings.Repeat("-", 40))
	keys := make([]string, 0, len(rates))
	for k := range rates {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	count := 0
	for _, k := range keys {
		if count >= 20 {
			break
		}
		fmt.Printf("%-5s : %.4f\n", k, rates[k])
		count++
	}
	if len(keys) > 20 {
		fmt.Printf("... and %d more\n", len(keys)-20)
	}
}

func main() {
	parser := NewRateParser()
	scanner := bufio.NewScanner(os.Stdin)
	fmt.Println("=== Exchange Rate Parser ===")
	for {
		fmt.Println("\n1. Show all rates")
		fmt.Println("2. Filter by currency")
		fmt.Println("3. Search currency")
		fmt.Println("4. Export to JSON")
		fmt.Println("5. Export to CSV")
		fmt.Println("6. Refresh rates")
		fmt.Println("7. Show history")
		fmt.Println("8. Exit")
		fmt.Print("Choose: ")
		scanner.Scan()
		choice := strings.TrimSpace(scanner.Text())
		switch choice {
		case "1":
			parser.displayRates(nil)
		case "2":
			fmt.Print("Enter currency codes (comma-separated): ")
			scanner.Scan()
			parts := strings.Split(strings.ToUpper(scanner.Text()), ",")
			var currencies []string
			for _, c := range parts {
				c = strings.TrimSpace(c)
				if c != "" {
					currencies = append(currencies, c)
				}
			}
			if len(currencies) > 0 {
				filtered := parser.filterRates(currencies)
				parser.displayRates(filtered)
			} else {
				fmt.Println("No currencies specified.")
			}
		case "3":
			fmt.Print("Enter currency code or name: ")
			scanner.Scan()
			query := strings.TrimSpace(scanner.Text())
			if query != "" {
				found := parser.searchCurrency(query)
				parser.displayRates(found)
			} else {
				fmt.Println("Query cannot be empty.")
			}
		case "4":
			fmt.Print("Filename (default: rates.json): ")
			scanner.Scan()
			fname := strings.TrimSpace(scanner.Text())
			if fname == "" {
				fname = "rates.json"
			}
			if parser.exportJSON(fname) {
				fmt.Printf("Exported to %s\n", fname)
			}
		case "5":
			fmt.Print("Filename (default: rates.csv): ")
			scanner.Scan()
			fname := strings.TrimSpace(scanner.Text())
			if fname == "" {
				fname = "rates.csv"
			}
			if parser.exportCSV(fname) {
				fmt.Printf("Exported to %s\n", fname)
			}
		case "6":
			if parser.refresh() {
				fmt.Println("Rates refreshed.")
			} else {
				fmt.Println("Refresh failed.")
			}
		case "7":
			parser.showHistory()
		case "8":
			fmt.Println("Goodbye!")
			return
		default:
			fmt.Println("Invalid choice.")
		}
	}
}
