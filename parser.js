// parser.js
const axios = require('axios');
const fs = require('fs');
const readline = require('readline');

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

class RateParser {
    constructor(cacheTTL = 60) {
        this.apiURL = 'https://api.exchangerate.host/latest?base=USD';
        this.rates = {};
        this.lastUpdate = null;
        this.cacheTTL = cacheTTL;
        this.history = [];
        this.fetchRates();
    }

    async fetchRates() {
        try {
            const response = await axios.get(this.apiURL, { timeout: 5000 });
            if (response.data.success) {
                this.rates = response.data.rates;
                this.lastUpdate = new Date();
                this.history.push({
                    timestamp: this.lastUpdate.toISOString(),
                    rates: { ...this.rates }
                });
                if (this.history.length > 10) this.history.shift();
                return true;
            }
            return false;
        } catch (error) {
            console.error('Error fetching rates:', error.message);
            return false;
        }
    }

    getRates() {
        if (this.lastUpdate && (Date.now() - this.lastUpdate.getTime()) > this.cacheTTL * 1000) {
            this.fetchRates();
        }
        return this.rates;
    }

    filterRates(currencies) {
        const rates = this.getRates();
        const result = {};
        currencies.forEach(c => {
            if (rates[c] !== undefined) result[c] = rates[c];
        });
        return result;
    }

    searchCurrency(query) {
        const rates = this.getRates();
        const result = {};
        const q = query.toLowerCase();
        Object.keys(rates).forEach(k => {
            if (k.toLowerCase().includes(q)) result[k] = rates[k];
        });
        return result;
    }

    async refresh() {
        return await this.fetchRates();
    }

    exportJSON(filename = 'rates.json') {
        try {
            const data = {
                timestamp: this.lastUpdate ? this.lastUpdate.toISOString() : null,
                rates: this.getRates()
            };
            fs.writeFileSync(filename, JSON.stringify(data, null, 2));
            return true;
        } catch (error) {
            console.error('Export failed:', error.message);
            return false;
        }
    }

    exportCSV(filename = 'rates.csv') {
        try {
            const rates = this.getRates();
            const lines = ['Currency,Rate'];
            Object.keys(rates).sort().forEach(k => {
                lines.push(`${k},${rates[k].toFixed(4)}`);
            });
            fs.writeFileSync(filename, lines.join('\n'));
            return true;
        } catch (error) {
            console.error('Export failed:', error.message);
            return false;
        }
    }

    showHistory() {
        if (this.history.length === 0) {
            console.log('No history yet.');
            return;
        }
        this.history.forEach((entry, i) => {
            console.log(`[${i+1}] ${entry.timestamp} – ${Object.keys(entry.rates).length} currencies`);
        });
    }

    displayRates(rates) {
        if (!rates) rates = this.getRates();
        if (Object.keys(rates).length === 0) {
            console.log('No rates available.');
            return;
        }
        const keys = Object.keys(rates).sort();
        console.log(`\nRates (USD base) – updated: ${this.lastUpdate ? this.lastUpdate.toLocaleString() : 'unknown'}`);
        console.log('-'.repeat(40));
        keys.slice(0, 20).forEach(k => {
            console.log(`${k.padEnd(5)} : ${rates[k].toFixed(4)}`);
        });
        if (keys.length > 20) {
            console.log(`... and ${keys.length - 20} more`);
        }
    }
}

function ask(question) {
    return new Promise(resolve => rl.question(question, resolve));
}

async function main() {
    const parser = new RateParser();
    console.log('=== Exchange Rate Parser ===');
    while (true) {
        console.log('\n1. Show all rates');
        console.log('2. Filter by currency');
        console.log('3. Search currency');
        console.log('4. Export to JSON');
        console.log('5. Export to CSV');
        console.log('6. Refresh rates');
        console.log('7. Show history');
        console.log('8. Exit');
        const choice = await ask('Choose: ');
        switch (choice.trim()) {
            case '1':
                parser.displayRates();
                break;
            case '2': {
                const input = await ask('Enter currency codes (comma-separated): ');
                const currencies = input.toUpperCase().split(',').map(c => c.trim()).filter(c => c);
                if (currencies.length) {
                    const filtered = parser.filterRates(currencies);
                    parser.displayRates(filtered);
                } else {
                    console.log('No currencies specified.');
                }
                break;
            }
            case '3': {
                const query = await ask('Enter currency code or name: ');
                if (query.trim()) {
                    const found = parser.searchCurrency(query.trim());
                    parser.displayRates(found);
                } else {
                    console.log('Query cannot be empty.');
                }
                break;
            }
            case '4': {
                let fname = await ask('Filename (default: rates.json): ');
                fname = fname.trim() || 'rates.json';
                if (parser.exportJSON(fname)) {
                    console.log(`Exported to ${fname}`);
                }
                break;
            }
            case '5': {
                let fname = await ask('Filename (default: rates.csv): ');
                fname = fname.trim() || 'rates.csv';
                if (parser.exportCSV(fname)) {
                    console.log(`Exported to ${fname}`);
                }
                break;
            }
            case '6':
                if (await parser.refresh()) {
                    console.log('Rates refreshed.');
                } else {
                    console.log('Refresh failed.');
                }
                break;
            case '7':
                parser.showHistory();
                break;
            case '8':
                console.log('Goodbye!');
                rl.close();
                return;
            default:
                console.log('Invalid choice.');
        }
    }
}

main().catch(console.error);
