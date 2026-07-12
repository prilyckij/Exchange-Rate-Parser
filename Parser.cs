// Parser.cs
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;

class RateResponse
{
    public bool Success { get; set; }
    public Dictionary<string, double> Rates { get; set; }
}

class HistoryEntry
{
    public string Timestamp { get; set; }
    public Dictionary<string, double> Rates { get; set; }
}

class RateParser
{
    private readonly string apiUrl = "https://api.exchangerate.host/latest?base=USD";
    private readonly int cacheTTL;
    private Dictionary<string, double> rates;
    private DateTime? lastUpdate;
    private List<HistoryEntry> history;
    private readonly HttpClient client;

    public RateParser(int cacheTTL = 60)
    {
        this.cacheTTL = cacheTTL;
        this.rates = new Dictionary<string, double>();
        this.history = new List<HistoryEntry>();
        this.client = new HttpClient();
        this.client.Timeout = TimeSpan.FromSeconds(5);
        _ = FetchRates();
    }

    private async Task<bool> FetchRates()
    {
        try
        {
            var response = await client.GetStringAsync(apiUrl);
            var data = JsonSerializer.Deserialize<RateResponse>(response);
            if (data != null && data.Success)
            {
                rates = data.Rates;
                lastUpdate = DateTime.Now;
                history.Add(new HistoryEntry
                {
                    Timestamp = lastUpdate.Value.ToString("o"),
                    Rates = new Dictionary<string, double>(rates)
                });
                if (history.Count > 10) history.RemoveAt(0);
                return true;
            }
            return false;
        }
        catch (Exception e)
        {
            Console.WriteLine($"Error fetching rates: {e.Message}");
            return false;
        }
    }

    public Dictionary<string, double> GetRates()
    {
        if (lastUpdate.HasValue && (DateTime.Now - lastUpdate.Value).TotalSeconds > cacheTTL)
        {
            _ = FetchRates();
        }
        return rates;
    }

    public Dictionary<string, double> FilterRates(List<string> currencies)
    {
        var allRates = GetRates();
        var result = new Dictionary<string, double>();
        foreach (var c in currencies)
        {
            if (allRates.TryGetValue(c, out var rate))
                result[c] = rate;
        }
        return result;
    }

    public Dictionary<string, double> SearchCurrency(string query)
    {
        var allRates = GetRates();
        var result = new Dictionary<string, double>();
        var q = query.ToLower();
        foreach (var kv in allRates)
        {
            if (kv.Key.ToLower().Contains(q))
                result[kv.Key] = kv.Value;
        }
        return result;
    }

    public async Task<bool> Refresh() => await FetchRates();

    public bool ExportJSON(string filename = "rates.json")
    {
        try
        {
            var data = new
            {
                timestamp = lastUpdate?.ToString("o"),
                rates = GetRates()
            };
            var json = JsonSerializer.Serialize(data, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(filename, json);
            return true;
        }
        catch (Exception e)
        {
            Console.WriteLine($"Export failed: {e.Message}");
            return false;
        }
    }

    public bool ExportCSV(string filename = "rates.csv")
    {
        try
        {
            var rates = GetRates();
            var lines = new List<string> { "Currency,Rate" };
            foreach (var kv in rates.OrderBy(k => k.Key))
                lines.Add($"{kv.Key},{kv.Value:F4}");
            File.WriteAllLines(filename, lines);
            return true;
        }
        catch (Exception e)
        {
            Console.WriteLine($"Export failed: {e.Message}");
            return false;
        }
    }

    public void ShowHistory()
    {
        if (history.Count == 0)
        {
            Console.WriteLine("No history yet.");
            return;
        }
        for (int i = 0; i < history.Count; i++)
        {
            Console.WriteLine($"[{i+1}] {history[i].Timestamp} – {history[i].Rates.Count} currencies");
        }
    }

    public void DisplayRates(Dictionary<string, double> rates = null)
    {
        if (rates == null) rates = GetRates();
        if (rates.Count == 0)
        {
            Console.WriteLine("No rates available.");
            return;
        }
        Console.WriteLine($"\nRates (USD base) – updated: {lastUpdate?.ToString("yyyy-MM-dd HH:mm:ss") ?? "unknown"}");
        Console.WriteLine(new string('-', 40));
        int count = 0;
        foreach (var kv in rates.OrderBy(k => k.Key))
        {
            if (count >= 20) break;
            Console.WriteLine($"{kv.Key,-5} : {kv.Value:F4}");
            count++;
        }
        if (rates.Count > 20)
            Console.WriteLine($"... and {rates.Count - 20} more");
    }

    static async Task Main()
    {
        var parser = new RateParser();
        Console.WriteLine("=== Exchange Rate Parser ===");
        while (true)
        {
            Console.WriteLine("\n1. Show all rates");
            Console.WriteLine("2. Filter by currency");
            Console.WriteLine("3. Search currency");
            Console.WriteLine("4. Export to JSON");
            Console.WriteLine("5. Export to CSV");
            Console.WriteLine("6. Refresh rates");
            Console.WriteLine("7. Show history");
            Console.WriteLine("8. Exit");
            Console.Write("Choose: ");
            var choice = Console.ReadLine()?.Trim() ?? "";
            switch (choice)
            {
                case "1":
                    parser.DisplayRates();
                    break;
                case "2":
                    Console.Write("Enter currency codes (comma-separated): ");
                    var input = Console.ReadLine()?.Trim().ToUpper() ?? "";
                    var currencies = input.Split(',').Select(c => c.Trim()).Where(c => !string.IsNullOrEmpty(c)).ToList();
                    if (currencies.Any())
                    {
                        var filtered = parser.FilterRates(currencies);
                        parser.DisplayRates(filtered);
                    }
                    else
                    {
                        Console.WriteLine("No currencies specified.");
                    }
                    break;
                case "3":
                    Console.Write("Enter currency code or name: ");
                    var query = Console.ReadLine()?.Trim() ?? "";
                    if (!string.IsNullOrEmpty(query))
                    {
                        var found = parser.SearchCurrency(query);
                        parser.DisplayRates(found);
                    }
                    else
                    {
                        Console.WriteLine("Query cannot be empty.");
                    }
                    break;
                case "4":
                    Console.Write("Filename (default: rates.json): ");
                    var fname = Console.ReadLine()?.Trim() ?? "rates.json";
                    if (string.IsNullOrEmpty(fname)) fname = "rates.json";
                    if (parser.ExportJSON(fname))
                        Console.WriteLine($"Exported to {fname}");
                    break;
                case "5":
                    Console.Write("Filename (default: rates.csv): ");
                    fname = Console.ReadLine()?.Trim() ?? "rates.csv";
                    if (string.IsNullOrEmpty(fname)) fname = "rates.csv";
                    if (parser.ExportCSV(fname))
                        Console.WriteLine($"Exported to {fname}");
                    break;
                case "6":
                    if (await parser.Refresh())
                        Console.WriteLine("Rates refreshed.");
                    else
                        Console.WriteLine("Refresh failed.");
                    break;
                case "7":
                    parser.ShowHistory();
                    break;
                case "8":
                    Console.WriteLine("Goodbye!");
                    return;
                default:
                    Console.WriteLine("Invalid choice.");
                    break;
            }
        }
    }
}
