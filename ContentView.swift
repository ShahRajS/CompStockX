import SwiftUI

// MARK: - Alpha Vantage API Data Models

// Symbol Search data from the /query?function=SYMBOL_SEARCH endpoint.
struct AlphaVantageSymbolSearch: Decodable {
    let bestMatches: [SearchMatch]? // Made optional for safer decoding

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
    let freeCashFlow: String?
    
    private enum CodingKeys: String, CodingKey {
        case symbol = "Symbol"
        case name = "Name"
        case sector = "Sector"
        case peRatio = "PERatio"
        case revenuePerShareTTM = "RevenuePerShareTTM"
        case earningsPerShare = "EPS"
        case freeCashFlow = "FreeCashflow"
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

// Time Series Daily data from the /query?function=TIME_SERIES_DAILY endpoint.
struct AlphaVantageDailyTimeSeries: Decodable {
    let timeSeries: [String: TimeSeriesDailyData]?
    
    private enum CodingKeys: String, CodingKey {
        case timeSeries = "Time Series (Daily)"
    }
}

struct TimeSeriesDailyData: Decodable {
    let open: String?
    let close: String?
    let high: String?
    let low: String?
    
    private enum CodingKeys: String, CodingKey {
        case open = "1. open"
        case close = "4. close"
        case high = "2. high"
        case low = "3. low"
    }
}

// A generic error message struct to handle API responses.
struct AlphaVantageError: Decodable {
    let note: String?
    let errorMessage: String?
    
    private enum CodingKeys: String, CodingKey {
        case note = "Note"
        case errorMessage = "Error Message"
    }
}


// MARK: - Analysis Report Struct

// A custom struct to hold all the analysis data.
struct AnalysisReport {
    var peRatio: String = "N/A"
    var rps: String = "N/A"
    var pegRatio: String = "N/A"
    var freeCashFlow: String = "N/A"
    var oneMonthChange: String = "N/A"
    var currentPrice: String = "N/A"
    var recommendation: String = "No recommendation."
    var insiderTransactions: String = "No recent transactions found."
}


// MARK: - Main App View

struct ContentView: View {
    @State private var ticker: String = ""
    @State private var analysisResult: AnalysisReport? = nil
    @State private var isLoading: Bool = false
    @State private var searchResults: [SearchMatch] = []
    
    // This task will be used to cancel the previous search call.
    @State private var searchTask: Task<Void, Never>? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Stock Sector Analyzer")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.leading)
                
                Spacer()
                
                Button(action: resetApp) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .padding(.trailing)
            }
            .padding(.top)
            
            VStack {
                TextField("Enter ticker (e.g., AAPL)", text: $ticker)
                    .textFieldStyle(RoundedBorderApperance())
                    .autocapitalization(.allCharacters)
                    .onChange(of: ticker) { newValue in
                        // Cancel the previous search task if it exists.
                        searchTask?.cancel()
                        
                        if !newValue.isEmpty {
                            // Create a new task that will wait and then perform the search.
                            searchTask = Task {
                                // Wait for 1 second before making the call.
                                try? await Task.sleep(nanoseconds: 1_000_000_000)
                                // Check if the task was canceled before making the API call.
                                if !Task.isCancelled {
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
            
            // Conditional view to switch between the initial message and the analysis output
            if analysisResult == nil {
                Text("Enter a stock ticker to analyze.")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 16) {
                    // Grid for financial metrics, matching the provided design
                    HStack(spacing: 16) {
                        MetricCard(title: "P/E", value: analysisResult?.peRatio ?? "N/A")
                        MetricCard(title: "RPS", value: analysisResult?.rps ?? "N/A")
                        MetricCard(title: "PEG", value: analysisResult?.pegRatio ?? "N/A")
                    }
                    
                    HStack(spacing: 16) {
                        MetricCard(title: "FCF", value: analysisResult?.freeCashFlow ?? "N/A")
                        MetricCard(title: "1-Month Change", value: analysisResult?.oneMonthChange ?? "N/A")
                        MetricCard(title: "Current Price", value: analysisResult?.currentPrice ?? "N/A")
                    }
                    
                    // Box for the Gemini recommendation
                    VStack(alignment: .leading) {
                        Text("Recommendation")
                            .font(.headline)
                            .padding(.bottom, 4)
                        Text(analysisResult?.recommendation ?? "No recommendation available.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Helper Views
    
    // A reusable view for the metric cards
    struct MetricCard: View {
        let title: String
        let value: String
        
        var body: some View {
            VStack(alignment: .center) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
                    .fontWeight(.bold)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    // MARK: - App Logic
    
    private func resetApp() {
        ticker = ""
        analysisResult = nil
        searchResults = []
    }
    
    private func runAnalysis() {
        guard !ticker.isEmpty else {
            return
        }
        
        isLoading = true
        analysisResult = nil // Clear previous results
        
        Task {
            // Fetch all necessary data concurrently
            async let overview = fetchCompanyOverview(for: ticker)
            async let insiderTransactions = fetchInsiderTransactions(for: ticker)
            async let dailyTimeSeries = fetchDailyTimeSeries(for: ticker)
            
            let report = await self.createAnalysisReport(
                ticker: ticker,
                overview: await overview,
                insiderTransactions: await insiderTransactions,
                dailyTimeSeries: await dailyTimeSeries
            )

            // Feed the report to Gemini for a final recommendation
            let geminiResponse = await getGeminiAnalysis(
                ticker: ticker,
                analysisReport: """
                P/E: \(report.peRatio), RPS: \(report.rps), PEG: \(report.pegRatio), Free Cash Flow: \(report.freeCashFlow), 1-Month Change: \(report.oneMonthChange), Insider Transactions: \(report.insiderTransactions)
                """
            )
            
            DispatchQueue.main.async {
                var finalReport = report
                finalReport.recommendation = geminiResponse
                self.analysisResult = finalReport
                self.isLoading = false
            }
        }
    }
    
    private func createAnalysisReport(
        ticker: String, overview: AlphaVantageCompanyOverview?, insiderTransactions: AlphaVantageInsiderTransactions?,
        dailyTimeSeries: AlphaVantageDailyTimeSeries?
    ) async -> AnalysisReport {
        var report = AnalysisReport()

        // P/E Ratio
        if let pe = overview?.peRatio, let peValue = Double(pe) {
            report.peRatio = String(format: "%.2f", peValue)
        }

        // Revenue Per Share
        if let rps = overview?.revenuePerShareTTM, let rpsValue = Double(rps) {
            report.rps = String(format: "%.2f", rpsValue)
        }
        
        // Free Cash Flow
        if let fcf = overview?.freeCashFlow, let fcfValue = Double(fcf) {
            report.freeCashFlow = String(format: "%.2f", fcfValue)
        }
        
        // PEG Ratio (placeholder, as growth rate is hard to get for free)
        if let pe = overview?.peRatio, let eps = overview?.earningsPerShare,
           let peValue = Double(pe), let epsValue = Double(eps) {
            let fakeGrowthRate = 10.0 // Placeholder for growth rate
            let peg = peValue / fakeGrowthRate
            report.pegRatio = String(format: "%.2f", peg)
        }


        // 1-Month Change
        if let timeSeries = dailyTimeSeries?.timeSeries, !timeSeries.isEmpty {
            let sortedDates = timeSeries.keys.sorted()
            if let firstMonthDate = sortedDates.first, let lastMonthDate = sortedDates.last,
               let firstDayClose = Double(timeSeries[firstMonthDate]?.close ?? "0"),
               let lastDayClose = Double(timeSeries[lastMonthDate]?.close ?? "0") {
                if firstDayClose != 0 {
                    let change = ((lastDayClose - firstDayClose) / firstDayClose) * 100
                    report.oneMonthChange = String(format: "%.2f%%", change)
                    report.currentPrice = String(format: "%.2f", lastDayClose)
                }
            }
        }

        // Insider Transactions
        if let transactions = insiderTransactions?.latestTransactions, !transactions.isEmpty {
            var transactionsString = ""
            for transaction in transactions.prefix(3) {
                if let owner = transaction.ownerName, let code = transaction.transactionCode, let date = transaction.transactionDate {
                    let price = transaction.transactionPrice ?? "N/A"
                    let shares = transaction.transactionShares ?? "N/A"
                    transactionsString += "• \(date): \(owner) \(code == "buy" ? "bought" : "sold") \(shares) shares at $\(price).\n"
                }
            }
            report.insiderTransactions = transactionsString
        }

        return report
    }
    
    // MARK: - API Calls
    
    private func fetchCompanyOverview(for ticker: String) async -> AlphaVantageCompanyOverview? {
        let alphaVantageApiKey = alphaVantageApiKey
        let alphaVantageUrl = "https://www.alphavantage.co/query?function=OVERVIEW&symbol=\(ticker)&apikey=\(alphaVantageApiKey)"
        
        guard let url = URL(string: alphaVantageUrl) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // First, try to decode as an error message
            if let error = try? JSONDecoder().decode(AlphaVantageError.self, from: data) {
                print("Alpha Vantage API Error for \(ticker) Overview: \(error.note ?? error.errorMessage ?? "Unknown error")")
                return nil
            }
            
            let decoder = JSONDecoder()
            let overview = try decoder.decode(AlphaVantageCompanyOverview.self, from: data)
            return overview
        } catch {
            print("Error fetching or decoding Alpha Vantage overview for \(ticker): \(error)")
            return nil
        }
    }
    
    private func fetchSymbolSearch(for query: String) async -> [SearchMatch]? {
        let alphaVantageApiKey = alphaVantageApiKey
        let alphaVantageUrl = "https://www.alphavantage.co/query?function=SYMBOL_SEARCH&keywords=\(query)&apikey=\(alphaVantageApiKey)"
        
        guard let url = URL(string: alphaVantageUrl) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // First, try to decode as an error message
            if let error = try? JSONDecoder().decode(AlphaVantageError.self, from: data) {
                print("Alpha Vantage API Error for \(query) Search: \(error.note ?? error.errorMessage ?? "Unknown error")")
                return nil
            }
            
            let decoder = JSONDecoder()
            let searchResults = try decoder.decode(AlphaVantageSymbolSearch.self, from: data)
            
            // Safely unwrap the optional bestMatches array before filtering
            if let matches = searchResults.bestMatches {
                return matches.filter { $0.region == "United States" }
            } else {
                return []
            }
        } catch {
            print("Error fetching or decoding Alpha Vantage search results for \(query): \(error)")
            return nil
        }
    }
    
    private func fetchInsiderTransactions(for ticker: String) async -> AlphaVantageInsiderTransactions? {
        let alphaVantageApiKey = alphaVantageApiKey
        let alphaVantageUrl = "https://www.alphavantage.co/query?function=INSIDER_TRANSACTIONS&symbol=\(ticker)&apikey=\(alphaVantageApiKey)"
        
        guard let url = URL(string: alphaVantageUrl) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // First, try to decode as an error message
            if let error = try? JSONDecoder().decode(AlphaVantageError.self, from: data) {
                print("Alpha Vantage API Error for \(ticker) Insider Transactions: \(error.note ?? error.errorMessage ?? "Unknown error")")
                return nil
            }
            
            let decoder = JSONDecoder()
            let transactions = try decoder.decode(AlphaVantageInsiderTransactions.self, from: data)
            return transactions
        } catch {
            print("Error fetching or decoding Alpha Vantage insider transactions for \(ticker): \(error)")
            return nil
        }
    }
    
    private func fetchDailyTimeSeries(for ticker: String) async -> AlphaVantageDailyTimeSeries? {
        let alphaVantageApiKey = alphaVantageApiKey
        let alphaVantageUrl = "https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=\(ticker)&apikey=\(alphaVantageApiKey)"
        
        guard let url = URL(string: alphaVantageUrl) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // First, try to decode as an error message
            if let error = try? JSONDecoder().decode(AlphaVantageError.self, from: data) {
                print("Alpha Vantage API Error for \(ticker) Daily Time Series: \(error.note ?? error.errorMessage ?? "Unknown error")")
                return nil
            }
            
            let decoder = JSONDecoder()
            let timeSeries = try decoder.decode(AlphaVantageDailyTimeSeries.self, from: data)
            return timeSeries
        } catch {
            print("Error fetching or decoding Alpha Vantage daily time series for \(ticker): \(error)")
            return nil
        }
    }
    
    private func getGeminiAnalysis(ticker: String, analysisReport: String) async -> String {
        let apiKey = geminiApiKey
        
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
        
        guard let url = URL(string: apiUrl) else { return "Error: Invalid API URL." }
        
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
