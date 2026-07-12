// Parser.java
import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.file.*;
import java.time.Instant;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;
import com.google.gson.*;

public class Parser {
    private static final String API_URL = "https://api.exchangerate.host/latest?base=USD";
    private static final int CACHE_TTL = 60;
    private Map<String, Double> rates;
    private Instant lastUpdate;
    private List<HistoryEntry> history;
    private final Gson gson;

    private static class HistoryEntry {
        String timestamp;
        Map<String, Double> rates;
    }

    private static class RateResponse {
        boolean success;
        Map<String, Double> rates;
    }

    public Parser() {
        this.rates = new HashMap<>();
        this.history = new ArrayList<>();
        this.gson = new GsonBuilder().create();
        fetchRates();
    }

    private boolean fetchRates() {
        try {
            URL url = new URL(API_URL);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setConnectTimeout(5000);
            conn.setReadTimeout(5000);

            if (conn.getResponseCode() != 200) {
                System.out.println("HTTP error: " + conn.getResponseCode());
                return false;
            }

            try (BufferedReader br = new BufferedReader(new InputStreamReader(conn.getInputStream()))) {
                String json = br.lines().collect(Collectors.joining());
                RateResponse response = gson.fromJson(json, RateResponse.class);
                if (response.success && response.rates != null) {
                    rates = response.rates;
                    lastUpdate = Instant.now();
                    HistoryEntry entry = new HistoryEntry();
                    entry.timestamp = lastUpdate.toString();
                    entry.rates = new HashMap<>(rates);
                    history.add(entry);
                    if (history.size() > 10) history.remove(0);
                    return true;
                }
            }
            return false;
        } catch (Exception e) {
            System.out.println("Error fetching rates: " + e.getMessage());
            return false;
        }
    }

    public Map<String, Double> getRates() {
        if (lastUpdate != null && Instant.now().getEpochSecond() - lastUpdate.getEpochSecond() > CACHE_TTL) {
            fetchRates();
        }
        return rates;
    }

    public Map<String, Double> filterRates(List<String> currencies) {
        Map<String, Double> allRates = getRates();
        Map<String, Double> result = new HashMap<>();
        for (String c : currencies) {
            if (allRates.containsKey(c)) result.put(c, allRates.get(c));
        }
        return result;
    }

    public Map<String, Double> searchCurrency(String query) {
        Map<String, Double> allRates = getRates();
        Map<String, Double> result = new HashMap<>();
        String q = query.toLowerCase();
        for (Map.Entry<String, Double> entry : allRates.entrySet()) {
            if (entry.getKey().toLowerCase().contains(q)) {
                result.put(entry.getKey(), entry.getValue());
            }
        }
        return result;
    }

    public boolean refresh() {
        return fetchRates();
    }

    public boolean exportJSON(String filename) {
        try {
            Map<String, Object> data = new HashMap<>();
            data.put("timestamp", lastUpdate != null ? lastUpdate.toString() : null);
            data.put("rates", getRates());
            String json = gson.toJson(data);
            Files.write(Paths.get(filename), json.getBytes());
            return true;
        } catch (Exception e) {
            System.out.println("Export failed: " + e.getMessage());
            return false;
        }
    }

    public boolean exportCSV(String filename) {
        try {
            Map<String, Double> rates = getRates();
            List<String> lines = new ArrayList<>();
            lines.add("Currency,Rate");
            rates.entrySet().stream()
                .sorted(Map.Entry.comparingByKey())
                .forEach(e -> lines.add(e.getKey() + "," + String.format("%.4f", e.getValue())));
            Files.write(Paths.get(filename), lines);
            return true;
        } catch (Exception e) {
            System.out.println("Export failed: " + e.getMessage());
            return false;
        }
    }

    public void showHistory() {
        if (history.isEmpty()) {
            System.out.println("No history yet.");
            return;
        }
        for (int i = 0; i < history.size(); i++) {
            System.out.printf("[%d] %s – %d currencies%n", i+1, history.get(i).timestamp, history.get(i).rates.size());
        }
    }

    public void displayRates(Map<String, Double> rates) {
        if (rates == null) rates = getRates();
        if (rates.isEmpty()) {
            System.out.println("No rates available.");
            return;
        }
        System.out.printf("%nRates (USD base) – updated: %s%n", 
            lastUpdate != null ? lastUpdate.toString() : "unknown");
        System.out.println(new String(new char[40]).replace('\0', '-'));
        int count = 0;
        for (Map.Entry<String, Double> entry : rates.entrySet().stream()
                .sorted(Map.Entry.comparingByKey()).collect(Collectors.toList())) {
            if (count >= 20) break;
            System.out.printf("%-5s : %.4f%n", entry.getKey(), entry.getValue());
            count++;
        }
        if (rates.size() > 20) {
            System.out.printf("... and %d more%n", rates.size() - 20);
        }
    }

    public static void main(String[] args) throws IOException {
        Parser parser = new Parser();
        BufferedReader reader = new BufferedReader(new InputStreamReader(System.in));
        System.out.println("=== Exchange Rate Parser ===");
        while (true) {
            System.out.println("\n1. Show all rates");
            System.out.println("2. Filter by currency");
            System.out.println("3. Search currency");
            System.out.println("4. Export to JSON");
            System.out.println("5. Export to CSV");
            System.out.println("6. Refresh rates");
            System.out.println("7. Show history");
            System.out.println("8. Exit");
            System.out.print("Choose: ");
            String choice = reader.readLine().trim();
            switch (choice) {
                case "1":
                    parser.displayRates(null);
                    break;
                case "2":
                    System.out.print("Enter currency codes (comma-separated): ");
                    String input = reader.readLine().trim().toUpperCase();
                    List<String> currencies = Arrays.stream(input.split(","))
                        .map(String::trim).filter(s -> !s.isEmpty()).collect(Collectors.toList());
                    if (!currencies.isEmpty()) {
                        Map<String, Double> filtered = parser.filterRates(currencies);
                        parser.displayRates(filtered);
                    } else {
                        System.out.println("No currencies specified.");
                    }
                    break;
                case "3":
                    System.out.print("Enter currency code or name: ");
                    String query = reader.readLine().trim();
                    if (!query.isEmpty()) {
                        Map<String, Double> found = parser.searchCurrency(query);
                        parser.displayRates(found);
                    } else {
                        System.out.println("Query cannot be empty.");
                    }
                    break;
                case "4":
                    System.out.print("Filename (default: rates.json): ");
                    String fname = reader.readLine().trim();
                    if (fname.isEmpty()) fname = "rates.json";
                    if (parser.exportJSON(fname)) {
                        System.out.println("Exported to " + fname);
                    }
                    break;
                case "5":
                    System.out.print("Filename (default: rates.csv): ");
                    fname = reader.readLine().trim();
                    if (fname.isEmpty()) fname = "rates.csv";
                    if (parser.exportCSV(fname)) {
                        System.out.println("Exported to " + fname);
                    }
                    break;
                case "6":
                    if (parser.refresh()) {
                        System.out.println("Rates refreshed.");
                    } else {
                        System.out.println("Refresh failed.");
                    }
                    break;
                case "7":
                    parser.showHistory();
                    break;
                case "8":
                    System.out.println("Goodbye!");
                    return;
                default:
                    System.out.println("Invalid choice.");
            }
        }
    }
}
