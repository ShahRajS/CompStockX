import SwiftUI

// MARK: - Alpha Vantage API Data Models

// Symbol Search data from the /query?function=SYMBOL_SEARCH endpoint.
struct AlphaVantageSymbolSearch: Decodable {
    let bestMatches: [SearchMatch]

    private enum CodingKeys: String, CodingKey {
        case bestMatches = "bestMatches"
    }
}

struct SearchMatch: Decodable, Identifiable {
    var id: String { symbol ?? UUID().uuidString }
    let symbol: String?
    let name: String?
    let type: String?
    let region: String?
    let marketOpen: String?
    let marketClose: String?
    let timezone: String?
    let currency: String?
    let matchScore: String?

    private enum CodingKeys: String, CodingKey {
        case symbol = "1. symbol"
        case name = "2. name"
        case type = "3. type"
        case region = "4. region"
        case marketOpen = "5. marketOpen"
        case marketClose = "6. marketClose"
        case timezone = "7. timezone"
        case currency = "8. currency"
        case matchScore = "9. matchScore"
    }
}

// Company Overview data from the /query?function=OVERVIEW endpoint.
struct AlphaVantageCompanyOverview: Decodable {
    let symbol: String?
    let name: String?
    let sector: String?
    let peRatio: String?
    let revenuePerShareTTM: String?
    let earningsPerShare: String?
    
    private enum CodingKeys: String, CodingKey {
        case symbol = "Symbol"
        case name = "Name"
        case sector = "Sector"
        case peRatio = "PERatio"
        case revenuePerShareTTM = "RevenuePerShareTTM"
        case earningsPerShare = "EPS"
    }
}

// Insider Transactions data from the /query?function=INSIDER_TRANSACTIONS endpoint.
struct AlphaVantageInsiderTransactions: Decodable {
    let symbol: String?
    let latestTransactions: [InsiderTransaction]?
    
    private enum CodingKeys: String, CodingKey {
        case symbol = "symbol"
        case latestTransactions = "latest_transactions"
    }
}

struct InsiderTransaction: Decodable, Identifiable {
    var id: String { filingDate ?? UUID().uuidString }
    let filingDate: String?
    let transactionDate: String?
    let transactionCode: String?
    let transactionPrice: String?
    let transactionShares: String?
    let ownerName: String?
    
    private enum CodingKeys: String, CodingKey {
        case filingDate = "filing_date"
        case transactionDate = "transaction_date"
        case transactionCode = "transaction_code"
        case transactionPrice = "transaction_price"
        case transactionShares = "transaction_shares"
        case ownerName = "owner_name"
    }
}

// MARK: - Main App View

struct ContentView: View {
    @State private var ticker: String = ""
    @State private var analysisResult: String = "Enter a stock ticker to analyze."
    @State private var isLoading: Bool = false
    @State private var searchResults: [SearchMatch] = []
    
    private let searchDebounceTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Stock Sector Analyzer")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            VStack {
                TextField("Enter ticker (e.g., AAPL)", text: $ticker)
                    .textFieldStyle(RoundedBorderApperance())
                    .autocapitalization(.allCharacters)
                    .onChange(of: ticker) { newValue in
                        if !newValue.isEmpty {
                            Task {
                                for await _ in searchDebounceTimer.values.prefix(1) {
                                    searchResults = await fetchSymbolSearch(for: newValue) ?? []
                                }
                            }
                        } else {
                            searchResults = []
                        }
                    }
                
                if !searchResults.isEmpty {
                    List(searchResults) { match in
                        if let symbol = match.symbol, let name = match.name {
                            Button(action: {
                                ticker = symbol
                                searchResults = []
                            }) {
                                Text("\(symbol) - \(name)")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(height: min(CGFloat(searchResults.count) * 44, 200))
                    .listStyle(.plain)
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            
            Button(action: runAnalysis) {
                Text(isLoading ? "Analyzing..." : "Analyze Stock")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .disabled(isLoading || ticker.isEmpty)
            
            ScrollView {
                Text(analysisResult)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: analysisResult == "Enter a stock ticker to analyze." ? .center : .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - App Logic
    
    private func runAnalysis() {
        guard !ticker.isEmpty else {
            analysisResult = "Please enter a ticker symbol."
            return
        }
        
        isLoading = true
        analysisResult = "Fetching data from Alpha Vantage and running sector analysis..."
        
        Task {
            async let overview = fetchCompanyOverview(for: ticker)
            async let insiderTransactions = fetchInsiderTransactions(for: ticker)
            async let sectorAverages = getSectorAverages()
            
            let analysisReport = runComparativeAnalysis(
                ticker: ticker,
                overview: await overview,
                insiderTransactions: await insiderTransactions,
                sectorAverages: await sectorAverages
            )
            
            let geminiResponse = await getGeminiAnalysis(
                ticker: ticker,
                analysisReport: analysisReport
            )
            
            DispatchQueue.main.async {
                self.analysisResult = """
                Local Analysis Report: \(analysisReport)
                
                ---
                
                Gemini's Take:
                \(geminiResponse)
                """
                
                self.isLoading = false
            }
        }
    }
    
    private func runComparativeAnalysis(
        ticker: String, overview: AlphaVantageCompanyOverview?, insiderTransactions: AlphaVantageInsiderTransactions?, sectorAverages: [String: Double]
    ) -> String {
        guard let stockOverview = overview else {
            return "Could not retrieve fundamental data for \(ticker). Please check the symbol or try again later due to API limits."
        }
        
        var analysis = "### Analysis for \(ticker)\n"
        var canCalculate = true
        
        let peRatio = Double(stockOverview.peRatio ?? "")
        let rps = Double(stockOverview.revenuePerShareTTM ?? "")
        
        if let pe = peRatio {
            analysis += "P/E Ratio: \(String(format: "%.2f", pe))\n"
        } else {
            analysis += "P/E Ratio: Data not available.\n"
            canCalculate = false
        }
        
        if let rpsValue = rps {
            analysis += "Revenue Per Share: \(String(format: "%.2f", rpsValue))\n"
        } else {
            analysis += "Revenue Per Share: Data not available.\n"
            canCalculate = false
        }
        
        analysis += "\n"
        
        if canCalculate {
            if let pe = peRatio, pe < sectorAverages["pe"] ?? Double.infinity {
                analysis += "The stock's P/E ratio is lower than the sector average, suggesting it may be **undervalued**.\n"
            } else {
                analysis += "The stock's P/E ratio is higher than the sector average, suggesting it may be **overvalued**.\n"
            }
            
            if let rpsValue = rps, rpsValue > sectorAverages["rps"] ?? Double.zero {
                analysis += "The stock's Revenue Per Share is higher than the sector average, indicating **strong revenue generation** per share.\n"
            } else {
                analysis += "The stock's Revenue Per Share is lower than the sector average, indicating **weaker revenue generation** per share.\n"
            }
        } else {
            analysis += "Cannot perform full sector comparison due to missing data."
        }

        // MARK: - Insider Transaction Analysis
        analysis += "\n---\n\n### Recent Insider Transactions\n"
        if let transactions = insiderTransactions?.latestTransactions, !transactions.isEmpty {
            for transaction in transactions.prefix(3) { // Show up to 3 most recent transactions
                if let owner = transaction.ownerName, let code = transaction.transactionCode, let date = transaction.transactionDate {
                    let price = transaction.transactionPrice ?? "N/A"
                    let shares = transaction.transactionShares ?? "N/A"
                    analysis += "• \(date): \(owner) \(code == "buy" ? "bought" : "sold") \(shares) shares at $\(price).\n"
                }
            }
        } else {
            analysis += "No recent insider transactions found."
        }

        return analysis
    }
    
    // MARK: - Placeholder for Sector Data
    
    private func getSectorAverages() async -> [String: Double] {
        return [
            "pe": 25.0, // Placeholder for sector average P/E
            "rps": 100.0 // Placeholder for sector average RPS
        ]
    }
    
    // MARK: - API Calls
    
    private func fetchCompanyOverview(for ticker: String) async -> AlphaVantageCompanyOverview? {
        let alphaVantageApiKey = "7VH70AFJ75RTIAX9"
        let alphaVantageUrl = "https://www.alphavantage.co/query?function=OVERVIEW&symbol=\(ticker)&apikey=\(alphaVantageApiKey)"
        
        guard let url = URL(string: alphaVantageUrl) else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let overview = try decoder.decode(AlphaVantageCompanyOverview.self, from: data)
            return overview
        } catch {
            print("Error fetching or decoding Alpha Vantage overview for \(ticker): \(error)")
            return nil
        }
    }
    
    private func fetchSymbolSearch(for query: String) async -> [SearchMatch]? {
        await Task.sleep(1_000_000_000)
        
        let alphaVantageApiKey = "7VH70AFJ75RTIAX9"
        let alphaVantageUrl = "https://www.alphavantage.co/query?function=SYMBOL_SEARCH&keywords=\(query)&apikey=\(alphaVantageApiKey)"
        
        guard let url = URL(string: alphaVantageUrl) else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let searchResults = try decoder.decode(AlphaVantageSymbolSearch.self, from: data)
            
            return searchResults.bestMatches.filter { $0.region == "United States" }
        } catch {
            print("Error fetching or decoding Alpha Vantage search results for \(query): \(error)")
            return nil
        }
    }
    
    private func fetchInsiderTransactions(for ticker: String) async -> AlphaVantageInsiderTransactions? {
        await Task.sleep(1_000_000_000)
        
        let alphaVantageApiKey = "7VH70AFJ75RTIAX9"
        let alphaVantageUrl = "https://www.alphavantage.co/query?function=INSIDER_TRANSACTIONS&symbol=\(ticker)&apikey=\(alphaVantageApiKey)"
        
        guard let url = URL(string: alphaVantageUrl) else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let transactions = try decoder.decode(AlphaVantageInsiderTransactions.self, from: data)
            return transactions
        } catch {
            print("Error fetching or decoding Alpha Vantage insider transactions for \(ticker): \(error)")
            return nil
        }
    }
    
    private func getGeminiAnalysis(ticker: String, analysisReport: String) async -> String {
        let apiKey = "AIzaSyBJw8gvfRb2D7i4nmBrByRaDdJdQn6TTPs"
        
        let prompt = """
        I've performed a fundamental analysis on the stock \(ticker) and compared it to its sector. My analysis report is: "\(analysisReport)".
        
        Based on live and historical financial data, does this conclusion make sense? If not, please provide a brief and concise reason why. Do not provide a long-winded response, just the key details.
        """
        
        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "topP": 0.95,
                "topK": 60
            ]
        ]
        
        let apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent?key=\(apiKey)"
        
        guard let url = URL(string: apiUrl) else {
            return "Error: Invalid API URL."
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            return "Error: Could not serialize JSON payload."
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return "Error: Bad network response."
            }
            
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let text = firstPart["text"] as? String {
                return text
            } else {
                return "Error: Failed to parse Gemini response."
            }
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}

// Preview provider for SwiftUI.
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// A custom text field style for a rounded border with a specific appearance
struct RoundedBorderApperance: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary, lineWidth: 1)
            )
    }
}
