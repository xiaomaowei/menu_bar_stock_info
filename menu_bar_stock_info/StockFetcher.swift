//
//  StockFetcher.swift
//  menu_bar_stock_info
//
//  Created by Denis Wei on 2025/4/2.
//

import Foundation
import Combine
import OSLog
import SwiftYFinance
import Network

// 自定義圖表數據點結構體
struct ChartDataPoint {
    var date: Date?
    var volume: Int?
    var open: Float?
    var close: Float?
    var adjclose: Float?
    var low: Float?
    var high: Float?
    
    // 直接轉換為HistoricalDataPoint
    func toHistoricalDataPoint() -> HistoricalDataPoint? {
        guard let date = date, let close = close else {
            return nil
        }
        return HistoricalDataPoint(date: date, price: Double(close))
    }
}

class StockFetcher {
    private let logger = Logger(subsystem: "com.menu-bar-stock-info", category: "StockFetcher")
    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable = true
    
    init() {
        // 設置網絡監控
        setupNetworkMonitoring()
    }
    
    // 設置網絡連接狀態監控
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            self.isNetworkAvailable = path.status == .satisfied
            self.logger.info("網絡狀態變更: \(self.isNetworkAvailable ? "可用" : "不可用")")
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // 從 API 獲取股票數據
    func fetchStockData(for symbol: String) -> AnyPublisher<StockModel, Error> {
        logger.info("Fetching stock data for \(symbol)")
        
        // 檢查網絡是否可用
        guard isNetworkAvailable else {
            logger.warning("網絡不可用，使用模擬數據")
            return mockFetchStockData(for: symbol)
        }
        
        // 使用 SwiftYFinance 獲取實際數據
        return fetchRealStockData(for: symbol)
            .catch { error -> AnyPublisher<StockModel, Error> in
                // 如果獲取失敗，使用模擬數據
                self.logger.error("Failed to fetch data for \(symbol): \(error.localizedDescription)")
                return self.mockFetchStockData(for: symbol)
            }
            .eraseToAnyPublisher()
    }
    
    // 驗證股票代碼是否有效（不使用模擬數據）
    func validateStockSymbol(_ symbol: String) -> AnyPublisher<Bool, Error> {
        logger.info("驗證股票代碼: \(symbol)")
        
        // 檢查網絡是否可用
        guard isNetworkAvailable else {
            logger.warning("網絡不可用，無法驗證股票代碼")
            return Just(false)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // 處理台灣股票代碼
        let processedSymbol = processTaiwanStockSymbol(symbol)
        logger.info("處理後的股票代碼用於驗證: \(processedSymbol)")
        
        // 檢查是否為台灣股票
        if symbol.hasSuffix(".TW") || symbol.hasSuffix(".TWO") {
            // 使用台灣股票驗證方法
            return validateTaiwanStock(processedSymbol)
        } else {
            // 使用直接API請求驗證一般股票
            return validateGeneralStock(processedSymbol)
        }
    }
    
    // 驗證台灣股票
    private func validateTaiwanStock(_ symbol: String) -> AnyPublisher<Bool, Error> {
        // 檢查是否為已知的台灣股票代碼
        let knownTaiwanStocks = ["2330.TW", "2454.TW", "2317.TW", "2412.TW", "2308.TW", 
                                "2303.TW", "2881.TW", "2882.TW", "2886.TW", "2891.TW"]
        if knownTaiwanStocks.contains(symbol) {
            self.logger.info("驗證知名台灣股票代碼: \(symbol)")
        }
        
        return Future<Bool, Error> { promise in
            // 構建用於驗證的URL
            let baseURL = "https://query1.finance.yahoo.com"
            guard var urlComponents = URLComponents(string: "\(baseURL)/v8/finance/chart/\(symbol)") else {
                self.logger.error("無法構造驗證URL")
                promise(.success(false))
                return
            }
            
            // 只需要簡單查詢參數
            let currentTimestamp = Int(Date().timeIntervalSince1970)
            let oneDayAgoTimestamp = currentTimestamp - 86400 // 一天前
            
            // 添加查詢參數
            var queryItems = [
                URLQueryItem(name: "period1", value: String(oneDayAgoTimestamp)),
                URLQueryItem(name: "period2", value: String(currentTimestamp)),
                URLQueryItem(name: "interval", value: "1d")
            ]
            
            // 如果是TWO結尾的股票，添加額外參數
            if symbol.hasSuffix(".TWO") {
                queryItems.append(contentsOf: [
                    URLQueryItem(name: "region", value: "TW"),
                    URLQueryItem(name: "lang", value: "zh-TW")
                ])
            }
            
            urlComponents.queryItems = queryItems
            
            guard let url = urlComponents.url else {
                self.logger.error("無法構造驗證URL")
                promise(.success(false))
                return
            }
            
            self.logger.info("驗證台灣股票URL: \(url)")
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                // 檢查錯誤
                if let error = error {
                    self.logger.error("驗證股票代碼失敗: \(error.localizedDescription)")
                    promise(.success(false))
                    return
                }
                
                // 檢查HTTP狀態碼
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    self.logger.error("驗證股票代碼HTTP錯誤: \(httpResponse.statusCode)")
                    promise(.success(false))
                    return
                }
                
                // 確保有數據
                guard let data = data else {
                    self.logger.error("驗證股票代碼無數據返回")
                    promise(.success(false))
                    return
                }
                
                // 驗證JSON數據
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let chart = json["chart"] as? [String: Any] else {
                        self.logger.error("驗證股票代碼JSON無效")
                        promise(.success(false))
                        return
                    }
                    
                    // 判斷是否有錯誤
                    if let error = chart["error"] as? [String: Any] {
                        self.logger.error("驗證股票代碼API錯誤: \(error)")
                        promise(.success(false))
                        return
                    }
                    
                    // 確認是否有結果
                    if let result = chart["result"] as? [[String: Any]], !result.isEmpty {
                        self.logger.info("股票代碼 \(symbol) 驗證成功")
                        promise(.success(true))
                    } else {
                        self.logger.error("股票代碼 \(symbol) 驗證失敗：沒有結果數據")
                        promise(.success(false))
                    }
                } catch {
                    self.logger.error("解析JSON出錯: \(error.localizedDescription)")
                    promise(.success(false))
                }
            }
            
            task.resume()
        }
        .eraseToAnyPublisher()
    }
    
    // 驗證一般股票
    private func validateGeneralStock(_ symbol: String) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            // 構建直接API請求URL
            let baseURL = "https://query1.finance.yahoo.com"
            guard var urlComponents = URLComponents(string: "\(baseURL)/v8/finance/chart/\(symbol)") else {
                self.logger.error("無法構造驗證URL")
                promise(.success(false))
                return
            }
            
            // 設置查詢參數
            let currentTimestamp = Int(Date().timeIntervalSince1970)
            let oneDayAgoTimestamp = currentTimestamp - 86400 // 一天前
            
            urlComponents.queryItems = [
                URLQueryItem(name: "period1", value: String(oneDayAgoTimestamp)),
                URLQueryItem(name: "period2", value: String(currentTimestamp)),
                URLQueryItem(name: "interval", value: "1d"),
                URLQueryItem(name: "includePrePost", value: "true"),
                URLQueryItem(name: "region", value: "US"),
                URLQueryItem(name: "lang", value: "en-US")
            ]
            
            guard let url = urlComponents.url else {
                self.logger.error("無法構造驗證URL")
                promise(.success(false))
                return
            }
            
            self.logger.info("驗證一般股票URL: \(url)")
            
            var request = URLRequest(url: url)
            request.addValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3.1 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            request.addValue("https://finance.yahoo.com", forHTTPHeaderField: "Referer")
            request.addValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            request.timeoutInterval = 15
            
            // 配置URLSession
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 30
            config.waitsForConnectivity = true
            
            let session = URLSession(configuration: config)
            
            let task = session.dataTask(with: request) { (data, response, error) in
                // 處理錯誤
                if let error = error {
                    self.logger.error("驗證股票代碼失敗: \(error.localizedDescription)")
                    // 對於網絡錯誤，我們嘗試通過靜態列表進行驗證
                    let commonStocks = ["AAPL", "MSFT", "GOOG", "GOOGL", "AMZN", "META", "TSLA", "NVDA", "NFLX", "INTC", "AMD", "IBM"]
                    if commonStocks.contains(symbol.uppercased()) {
                        self.logger.info("通過靜態列表驗證股票 \(symbol)")
                        promise(.success(true))
                    } else {
                        promise(.success(false))
                    }
                    return
                }
                
                // 檢查HTTP狀態碼
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    self.logger.error("驗證股票代碼HTTP錯誤: \(httpResponse.statusCode)")
                    // 檢查是否為常見的美股
                    let commonStocks = ["AAPL", "MSFT", "GOOG", "GOOGL", "AMZN", "META", "TSLA", "NVDA", "NFLX", "INTC", "AMD", "IBM"]
                    if commonStocks.contains(symbol.uppercased()) {
                        self.logger.info("通過靜態列表驗證股票 \(symbol)")
                        promise(.success(true))
                    } else {
                        promise(.success(false))
                    }
                    return
                }
                
                // 確保有數據
                guard let data = data else {
                    self.logger.error("驗證股票代碼無數據返回")
                    promise(.success(false))
                    return
                }
                
                // 解析JSON
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let chart = json["chart"] as? [String: Any] else {
                        self.logger.error("驗證股票代碼JSON無效")
                        promise(.success(false))
                        return
                    }
                    
                    // 檢查API錯誤
                    if let error = chart["error"] as? [String: Any] {
                        self.logger.error("驗證股票代碼API錯誤: \(error)")
                        // 檢查是否為常見的美股
                        let commonStocks = ["AAPL", "MSFT", "GOOG", "GOOGL", "AMZN", "META", "TSLA", "NVDA", "NFLX", "INTC", "AMD", "IBM"]
                        if commonStocks.contains(symbol.uppercased()) {
                            self.logger.info("通過靜態列表驗證股票 \(symbol)")
                            promise(.success(true))
                        } else {
                            promise(.success(false))
                        }
                        return
                    }
                    
                    // 檢查結果
                    if let result = chart["result"] as? [[String: Any]], !result.isEmpty {
                        self.logger.info("股票代碼 \(symbol) 驗證成功")
                        promise(.success(true))
                    } else {
                        self.logger.error("股票代碼 \(symbol) 驗證失敗：沒有結果數據")
                        promise(.success(false))
                    }
                    
                } catch {
                    self.logger.error("解析JSON出錯: \(error.localizedDescription)")
                    promise(.success(false))
                }
            }
            
            task.resume()
        }
        .eraseToAnyPublisher()
    }
    
    // 獲取多支股票數據
    func fetchMultipleStocks(symbols: [String]) -> AnyPublisher<[StockModel], Error> {
        let publishers = symbols.map { fetchStockData(for: $0) }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .eraseToAnyPublisher()
    }
    
    // 使用 SwiftYFinance 獲取實際股票數據
    private func fetchRealStockData(for symbol: String) -> AnyPublisher<StockModel, Error> {
        return Future<StockModel, Error> { promise in
            // 處理股票代碼
            let processedSymbol = self.processTaiwanStockSymbol(symbol)
            self.logger.info("處理後的股票代碼: \(processedSymbol)")
            
            // 檢查是否為台灣股票（包括.TW和.TWO）
            let isTaiwanStock = symbol.hasSuffix(".TW") || symbol.hasSuffix(".TWO")
            
            if isTaiwanStock {
                // 對台灣股票使用直接API請求
                self.fetchTaiwanStockData(symbol: processedSymbol, originalSymbol: symbol) { result in
                    switch result {
                    case .success(let stock):
                        promise(.success(stock))
                    case .failure(let error):
                        self.logger.error("獲取台灣股票數據失敗: \(error.localizedDescription)")
                        
                        // 嘗試修正常見的代碼錯誤
                        if symbol == "2230.TWO" {
                            self.logger.info("嘗試使用修正的代碼: 2230.TW 代替 2230.TWO")
                            // 嘗試使用正確的代碼格式重新獲取
                            let correctedSymbol = "2230.TW"
                            self.fetchTaiwanStockData(symbol: correctedSymbol, originalSymbol: symbol) { correctedResult in
                                switch correctedResult {
                                case .success(let stock):
                                    promise(.success(stock))
                                case .failure(_):
                                    // 如果修正後仍失敗，則使用模擬數據
                                    let mockStock = self.createMockStockData(for: symbol)
                                    promise(.success(mockStock))
                                }
                            }
                        } else {
                            // 失敗時使用模擬數據
                            let mockStock = self.createMockStockData(for: symbol)
                            promise(.success(mockStock))
                        }
                    }
                }
            } else {
                // 非台灣股票使用原有方法
                // 使用更可靠的API端點獲取美股和其他股票數據
                self.fetchGeneralStockData(symbol: symbol) { result in
                    switch result {
                    case .success(let stock):
                        promise(.success(stock))
                    case .failure(let error):
                        self.logger.error("通過API獲取股票數據失敗: \(error.localizedDescription)")
                        
                        // 嘗試使用SwiftYFinance庫作為後備方案
                        self.fetchSummaryWithRetry(symbol: symbol, retryCount: 3) { summary, error in
                            if let error = error {
                                self.logger.error("SwiftYFinance獲取股票摘要失敗: \(error.localizedDescription)")
                                // 最終使用模擬數據
                                let mockStock = self.createMockStockData(for: symbol)
                                promise(.success(mockStock))
                                return
                            }
                            
                            guard let summary = summary else {
                                self.logger.error("SwiftYFinance返回空數據")
                                let mockStock = self.createMockStockData(for: symbol)
                                promise(.success(mockStock))
                                return
                            }
                            
                            // 獲取實時股價數據
                            self.fetchRecentDataWithRetry(symbol: symbol, retryCount: 3) { recentData, error in
                                if let error = error {
                                    self.logger.error("SwiftYFinance獲取實時股價失敗: \(error.localizedDescription)")
                                    let mockStock = self.createMockStockData(for: symbol)
                                    promise(.success(mockStock))
                                    return
                                }
                                
                                guard let recentData = recentData,
                                      let price = recentData.regularMarketPrice else {
                                    self.logger.error("SwiftYFinance無法獲取實時股價")
                                    let mockStock = self.createMockStockData(for: symbol)
                                    promise(.success(mockStock))
                                    return
                                }
                                
                                // 從摘要中獲取漲跌數據
                                let change = summary.price?.regularMarketChange ?? 0.0
                                let changePercent = summary.price?.regularMarketChangePercent ?? 0.0
                                
                                // 創建 StockModel
                                let stock = StockModel(
                                    symbol: symbol,
                                    name: summary.quoteType?.shortName ?? symbol,
                                    price: Double(price),
                                    change: Double(change),
                                    changePercent: Double(changePercent),
                                    volume: Int(summary.summaryDetail?.volume ?? 0),
                                    marketCap: summary.summaryDetail?.marketCap != nil ? Double(summary.summaryDetail!.marketCap!) : nil,
                                    high52Week: summary.summaryDetail?.fiftyTwoWeekHigh != nil ? Double(summary.summaryDetail!.fiftyTwoWeekHigh!) : nil,
                                    low52Week: summary.summaryDetail?.fiftyTwoWeekLow != nil ? Double(summary.summaryDetail!.fiftyTwoWeekLow!) : nil,
                                    timestamp: Date()
                                )
                                
                                self.logger.info("成功獲取股票數據: \(symbol), 價格: \(price), 漲跌: \(change)")
                                promise(.success(stock))
                            }
                        }
                    }
                }
            }
        }
        .timeout(30, scheduler: DispatchQueue.global()) // 增加超時時間
        .eraseToAnyPublisher()
    }
    
    // 用於美股和其他非台灣股票的數據獲取
    private func fetchGeneralStockData(symbol: String, completion: @escaping (Result<StockModel, Error>) -> Void) {
        self.logger.info("使用API獲取一般股票數據: \(symbol)")
        
        // 使用更可靠的圖表數據API來獲取非台灣股票數據
        let baseURL = "https://query1.finance.yahoo.com"
        guard var urlComponents = URLComponents(string: "\(baseURL)/v8/finance/chart/\(symbol)") else {
            self.logger.error("無法構造股票數據URL")
            completion(.failure(NSError(domain: "com.menu-bar-stock-info", code: 20, userInfo: [NSLocalizedDescriptionKey: "無法構造URL"])))
            return
        }
        
        // 設置查詢參數
        let currentTimestamp = Int(Date().timeIntervalSince1970)
        let oneDayAgoTimestamp = currentTimestamp - 86400 // 一天前
        
        urlComponents.queryItems = [
            URLQueryItem(name: "period1", value: String(oneDayAgoTimestamp)),
            URLQueryItem(name: "period2", value: String(currentTimestamp)),
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "includePrePost", value: "true"),
            URLQueryItem(name: "region", value: "US"),
            URLQueryItem(name: "corsDomain", value: "finance.yahoo.com")
        ]
        
        guard let url = urlComponents.url else {
            self.logger.error("無法構造股票數據URL")
            completion(.failure(NSError(domain: "com.menu-bar-stock-info", code: 20, userInfo: [NSLocalizedDescriptionKey: "無法構造URL"])))
            return
        }
        
        self.logger.info("請求股票數據URL: \(url)")
        
        var request = URLRequest(url: url)
        request.addValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3.1 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.addValue("https://finance.yahoo.com", forHTTPHeaderField: "Referer")
        request.addValue("en-US,en;q=0.9,zh-TW;q=0.8,zh;q=0.7", forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 30
        
        // 創建自定義的URLSessionConfiguration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 5
        config.requestCachePolicy = .useProtocolCachePolicy
        
        if #available(macOS 14.0, *) {
            config.allowsConstrainedNetworkAccess = true
            config.allowsExpensiveNetworkAccess = true
        }
        
        // 使用自定義的URLSession
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request) { (data, response, error) in
            // 處理網絡錯誤
            if let error = error {
                self.logger.error("網絡請求錯誤: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // 檢查HTTP狀態碼
            guard let httpResponse = response as? HTTPURLResponse else {
                self.logger.error("非HTTP響應")
                completion(.failure(NSError(domain: "com.menu-bar-stock-info", code: 21, userInfo: [NSLocalizedDescriptionKey: "非HTTP響應"])))
                return
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                self.logger.error("HTTP錯誤: \(httpResponse.statusCode)")
                completion(.failure(NSError(domain: "com.menu-bar-stock-info", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP錯誤: \(httpResponse.statusCode)"])))
                return
            }
            
            // 確保有數據
            guard let data = data else {
                self.logger.error("沒有數據返回")
                completion(.failure(NSError(domain: "com.menu-bar-stock-info", code: 22, userInfo: [NSLocalizedDescriptionKey: "沒有數據返回"])))
                return
            }
            
            // 解析JSON數據
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let chart = json["chart"] as? [String: Any] else {
                    self.logger.error("無效的JSON數據")
                    completion(.failure(NSError(domain: "com.menu-bar-stock-info", code: 23, userInfo: [NSLocalizedDescriptionKey: "無效的JSON數據"])))
                    return
                }
                
                // 檢查是否有錯誤
                if let error = chart["error"] as? [String: Any] {
                    self.logger.error("API返回錯誤: \(error)")
                    completion(.failure(NSError(domain: "com.menu-bar-stock-info", code: 24, userInfo: [NSLocalizedDescriptionKey: "API返回錯誤"])))
                    return
                }
                
                // 獲取結果
                guard let result = chart["result"] as? [[String: Any]],
                      let firstResult = result.first,
                      let meta = firstResult["meta"] as? [String: Any] else {
                    self.logger.error("無法找到結果數據")
                    completion(.failure(NSError(domain: "com.menu-bar-stock-info", code: 25, userInfo: [NSLocalizedDescriptionKey: "無法找到結果數據"])))
                    return
                }
                
                // 獲取公司名稱
                let companyName = meta["shortName"] as? String ?? symbol
                
                // 獲取當前價格和上一個收盤價
                guard let regularMarketPrice = meta["regularMarketPrice"] as? Double,
                      let previousClose = meta["chartPreviousClose"] as? Double else {
                    self.logger.error("無法獲取股價數據")
                    completion(.failure(NSError(domain: "com.menu-bar-stock-info", code: 26, userInfo: [NSLocalizedDescriptionKey: "無法獲取股價數據"])))
                    return
                }
                
                // 計算漲跌
                let change = regularMarketPrice - previousClose
                let changePercent = (change / previousClose) * 100.0
                
                // 獲取成交量
                var volume: Int? = nil
                if let indicators = firstResult["indicators"] as? [String: Any],
                   let quote = indicators["quote"] as? [[String: Any]],
                   let firstQuote = quote.first,
                   let volumes = firstQuote["volume"] as? [Int?] {
                    // 獲取最後一個非nil的成交量值，如果沒有則嘗試第一個值
                    for vol in volumes.reversed() {
                        if let vol = vol {
                            volume = vol
                            break
                        }
                    }
                    
                    // 如果所有值都為nil，設置為默認值0
                    if volume == nil {
                        volume = 0
                    }
                }
                
                // 獲取52週高低點
                let high52Week = meta["fiftyTwoWeekHigh"] as? Double
                let low52Week = meta["fiftyTwoWeekLow"] as? Double
                
                // 創建股票模型
                let stock = StockModel(
                    symbol: symbol,
                    name: companyName,
                    price: regularMarketPrice,
                    change: change,
                    changePercent: changePercent,
                    volume: volume ?? 0,
                    marketCap: meta["marketCap"] as? Double,
                    high52Week: high52Week,
                    low52Week: low52Week,
                    timestamp: Date()
                )
                
                self.logger.info("成功獲取\(symbol)股價: \(regularMarketPrice), 漲跌: \(change) (\(changePercent)%)")
                completion(.success(stock))
                
            } catch {
                self.logger.error("JSON解析錯誤: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // 從 API 獲取特定區域股票數據（例如: .TW, .TWO）
    private func fetchTaiwanStockData(symbol: String, originalSymbol: String, completion: @escaping (Result<StockModel, Error>) -> Void) {
        self.logger.info("使用API獲取股票數據: \(symbol), 原始代碼: \(originalSymbol)")
        
        // 使用圖表數據API端點，該端點不需要授權
        let baseURL = "https://query1.finance.yahoo.com"
        guard var urlComponents = URLComponents(string: "\(baseURL)/v8/finance/chart/\(symbol)") else {
            self.logger.error("無法構造股票數據URL")
            completion(.failure(NSError(domain: "com.menu-bar-stock-info", code: 20, userInfo: [NSLocalizedDescriptionKey: "無法構造URL"])))
            return
        }
        
        // 設置查詢參數
        let currentTimestamp = Int(Date().timeIntervalSince1970)
        let oneDayAgoTimestamp = currentTimestamp - 86400 // 一天前
        
        // 根據不同的股票代碼設置不同的查詢參數
        var queryItems = [
            URLQueryItem(name: "period1", value: String(oneDayAgoTimestamp)),
            URLQueryItem(name: "period2", value: String(currentTimestamp)),
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "includePrePost", value: "true")
        ]
        
        // 對於.TWO結尾的股票可能需要額外的參數
        if originalSymbol.hasSuffix(".TWO") {
            queryItems.append(contentsOf: [
                URLQueryItem(name: "region", value: "TW"),
                URLQueryItem(name: "lang", value: "zh-TW"),
                URLQueryItem(name: "corsDomain", value: "finance.yahoo.com")
            ])
            self.logger.info("為OTC股票添加額外參數: \(originalSymbol)")
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            self.logger.error("無法構造股票數據URL")
            completion(.failure(NSError(domain: "com.menu-bar-stock-info", code: 20, userInfo: [NSLocalizedDescriptionKey: "無法構造URL"])))
            return
        }
        
        self.logger.info("請求股票數據URL: \(url)")
        
        var request = URLRequest(url: url)
        request.addValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3.1 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.addValue("https://finance.yahoo.com", forHTTPHeaderField: "Referer")
        request.addValue("en-US,en;q=0.9,zh-TW;q=0.8,zh;q=0.7", forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 30
        
        // 創建自定義的URLSessionConfiguration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 5
        config.requestCachePolicy = .useProtocolCachePolicy
        
        if #available(macOS 14.0, *) {
            config.allowsConstrainedNetworkAccess = true
            config.allowsExpensiveNetworkAccess = true
        }
        
        // 使用自定義的URLSession
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            // 檢查錯誤
            if let error = error {
                self.logger.error("獲取股票數據失敗: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // 檢查HTTP狀態碼
            if let httpResponse = response as? HTTPURLResponse {
                if !(200...299).contains(httpResponse.statusCode) {
                    self.logger.error("股票數據 HTTP錯誤: \(httpResponse.statusCode)")
                    completion(.failure(NSError(domain: "com.menu-bar-stock-info", code: 21, userInfo: [NSLocalizedDescriptionKey: "HTTP錯誤: \(httpResponse.statusCode)"])))
                    return
                }
            }
            
            // 確保有數據
            guard let data = data else {
                self.logger.error("股票數據無數據返回")
                completion(.failure(NSError(domain: "com.menu-bar-stock-info", code: 22, userInfo: [NSLocalizedDescriptionKey: "無數據返回"])))
                return
            }
            
            // 解析JSON數據
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.logger.error("無法解析股票數據JSON")
                    completion(.failure(NSError(domain: "com.menu-bar-stock-info", code: 23, userInfo: [NSLocalizedDescriptionKey: "無法解析JSON"])))
                    return
                }
                
                // 從圖表數據中提取股票信息
                guard let chart = json["chart"] as? [String: Any],
                      let result = chart["result"] as? [[String: Any]],
                      !result.isEmpty else {
                    self.logger.error("股票數據JSON格式無效")
                    completion(.failure(NSError(domain: "com.menu-bar-stock-info", code: 24, userInfo: [NSLocalizedDescriptionKey: "JSON格式無效"])))
                    return
                }
                
                let firstResult = result[0]
                
                // 獲取元數據
                guard let meta = firstResult["meta"] as? [String: Any] else {
                    self.logger.error("無法獲取股票元數據")
                    completion(.failure(NSError(domain: "com.menu-bar-stock-info", code: 25, userInfo: [NSLocalizedDescriptionKey: "無法獲取元數據"])))
                    return
                }
                
                // 提取當前價格和股票名稱
                let regularMarketPrice = meta["regularMarketPrice"] as? Double ?? 0.0
                let previousClose = meta["chartPreviousClose"] as? Double ?? 0.0 // 使用chartPreviousClose代替previousClose
                let change = regularMarketPrice - previousClose
                let changePercent = (change / previousClose) * 100
                let name = meta["shortName"] as? String ?? originalSymbol
                
                // 從元數據中直接提取52週高低點
                let high52Week = meta["fiftyTwoWeekHigh"] as? Double
                let low52Week = meta["fiftyTwoWeekLow"] as? Double
                
                self.logger.info("股票價格信息: 當前價格=\(regularMarketPrice), 前收盤價=\(previousClose), 變動=\(change), 百分比=\(changePercent)%")
                
                // 提取交易量數據
                var volume: Int = 0
                if let indicators = firstResult["indicators"] as? [String: Any],
                   let quote = indicators["quote"] as? [[String: Any]],
                   !quote.isEmpty,
                   let volumes = quote[0]["volume"] as? [Int?] {
                    if let lastVol = volumes.last, let value = lastVol {
                        volume = value
                    } else if let firstVol = volumes.first, let value = firstVol {
                        volume = value
                    }
                }
                
                // 創建StockModel
                let stock = StockModel(
                    symbol: originalSymbol,
                    name: name,
                    price: regularMarketPrice,
                    change: change,
                    changePercent: changePercent,
                    volume: volume,
                    marketCap: nil, // 圖表數據中沒有市值信息
                    high52Week: high52Week,
                    low52Week: low52Week,
                    timestamp: Date()
                )
                
                self.logger.info("成功獲取股票真實數據: \(stock.symbol), 價格: \(stock.price), 變動: \(stock.change)")
                completion(.success(stock))
                
            } catch {
                self.logger.error("解析股票數據JSON出錯: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // 創建模擬股票數據的方法
    private func createMockStockData(for symbol: String) -> StockModel {
        self.logger.info("為 \(symbol) 創建模擬數據")
        
        let mockData = StockModel(
            symbol: symbol,
            name: symbol.hasSuffix(".TW") ? "Taiwan Stock \(symbol)" : "\(symbol) Corporation",
            price: Double.random(in: 10...500),
            change: Double.random(in: -5...5),
            changePercent: Double.random(in: -3...3),
            volume: Int.random(in: 1_000_000...20_000_000),
            marketCap: Double.random(in: 1_000_000_000...200_000_000_000),
            high52Week: nil,
            low52Week: nil,
            timestamp: Date()
        )
        
        // 確保變動值一致
        return correctChangeValues(mockData)
    }
    
    // 帶有重試機制的摘要數據獲取方法
    private func fetchSummaryWithRetry(symbol: String, retryCount: Int, completion: @escaping (IdentifierSummary?, Error?) -> Void) {
        guard retryCount > 0 else {
            completion(nil, NSError(domain: "com.menu-bar-stock-info", code: 5, userInfo: [NSLocalizedDescriptionKey: "達到最大重試次數，仍無法獲取數據"]))
            return
        }
        
        self.logger.info("獲取股票摘要數據 \(symbol) (剩餘重試次數: \(retryCount))")
        
        SwiftYFinance.summaryDataBy(identifier: symbol) { summary, error in
            if let error = error {
                let nsError = error as NSError
                // 檢查是否為網絡錯誤
                if nsError.domain == NSURLErrorDomain {
                    self.logger.warning("網絡錯誤，即將重試: \(nsError.localizedDescription)")
                    // 延遲 1 秒後重試
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                        self.fetchSummaryWithRetry(symbol: symbol, retryCount: retryCount - 1, completion: completion)
                    }
                    return
                }
                
                // 其他錯誤直接返回
                completion(nil, error)
                return
            }
            
            // 成功獲取數據
            completion(summary, nil)
        }
    }
    
    // 帶有重試機制的實時數據獲取方法
    private func fetchRecentDataWithRetry(symbol: String, retryCount: Int, completion: @escaping (RecentStockData?, Error?) -> Void) {
        guard retryCount > 0 else {
            completion(nil, NSError(domain: "com.menu-bar-stock-info", code: 6, userInfo: [NSLocalizedDescriptionKey: "達到最大重試次數，仍無法獲取實時數據"]))
            return
        }
        
        self.logger.info("獲取股票實時數據 \(symbol) (剩餘重試次數: \(retryCount))")
        
        SwiftYFinance.recentDataBy(identifier: symbol) { recentData, error in
            if let error = error {
                let nsError = error as NSError
                // 檢查是否為網絡錯誤
                if nsError.domain == NSURLErrorDomain {
                    self.logger.warning("網絡錯誤，即將重試: \(nsError.localizedDescription)")
                    // 延遲 1 秒後重試
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                        self.fetchRecentDataWithRetry(symbol: symbol, retryCount: retryCount - 1, completion: completion)
                    }
                    return
                }
                
                // 其他錯誤直接返回
                completion(nil, error)
                return
            }
            
            // 成功獲取數據
            completion(recentData, nil)
        }
    }
    
    // 獲取股票歷史數據
    func fetchHistoricalData(for symbol: String, period: String = "1mo") -> AnyPublisher<[HistoricalDataPoint], Error> {
        // 檢查網絡是否可用
        guard isNetworkAvailable else {
            logger.warning("網絡不可用，返回空歷史數據")
            return Just([HistoricalDataPoint]())
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        return Future<[HistoricalDataPoint], Error> { promise in
            // 處理台灣股票代碼
            let processedSymbol = self.processTaiwanStockSymbol(symbol)
            self.logger.info("處理後的股票代碼(歷史數據): \(processedSymbol)")
            
            // 使用 chartDataBy 獲取圖表數據
            let currentDate = Date()
            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
            
            self.fetchHistoricalDataWithRetry(symbol: processedSymbol, start: oneMonthAgo, end: currentDate, retryCount: 3) { dataPoints, error in
                if let error = error {
                    self.logger.error("獲取歷史數據失敗: \(error.localizedDescription)")
                    promise(.failure(error))
                    return
                }
                
                guard let dataPoints = dataPoints, !dataPoints.isEmpty else {
                    promise(.failure(NSError(domain: "com.menu-bar-stock-info", code: 3, userInfo: [NSLocalizedDescriptionKey: "無效的歷史數據"])))
                    return
                }
                
                promise(.success(dataPoints))
            }
        }
        .timeout(15, scheduler: DispatchQueue.global()) // 增加超時時間
        .eraseToAnyPublisher()
    }
    
    // 帶有重試機制的歷史數據獲取方法 - 直接返回HistoricalDataPoint
    private func fetchHistoricalDataWithRetry(symbol: String, start: Date, end: Date, retryCount: Int, completion: @escaping ([HistoricalDataPoint]?, Error?) -> Void) {
        guard retryCount > 0 else {
            completion(nil, NSError(domain: "com.menu-bar-stock-info", code: 7, userInfo: [NSLocalizedDescriptionKey: "達到最大重試次數，仍無法獲取歷史數據"]))
            return
        }
        
        self.logger.info("獲取股票歷史數據 \(symbol) (剩餘重試次數: \(retryCount))")
        
        // 使用自定義方法直接獲取歷史數據，繞過庫的問題
        self.fetchChartDataDirectly(symbol: symbol, start: start, end: end) { chartDataPoints, error in
            if let error = error {
                let nsError = error as NSError
                // 檢查是否為網絡錯誤
                if nsError.domain == NSURLErrorDomain {
                    self.logger.warning("網絡錯誤，即將重試: \(nsError.localizedDescription)")
                    // 延遲 1 秒後重試
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                        self.fetchHistoricalDataWithRetry(symbol: symbol, start: start, end: end, retryCount: retryCount - 1, completion: completion)
                    }
                    return
                }
                
                // 其他錯誤直接返回
                completion(nil, error)
                return
            }
            
            // 成功獲取數據 - 直接轉換為HistoricalDataPoint
            if let chartDataPoints = chartDataPoints {
                let historicalDataPoints = chartDataPoints.compactMap { $0.toHistoricalDataPoint() }
                completion(historicalDataPoints, nil)
            } else {
                completion([], nil)
            }
        }
    }
    
    // 直接使用URLSession獲取歷史數據
    private func fetchChartDataDirectly(symbol: String, start: Date, end: Date, completion: @escaping ([ChartDataPoint]?, Error?) -> Void) {
        let startTimestamp = Int(start.timeIntervalSince1970)
        let endTimestamp = Int(end.timeIntervalSince1970)
        
        // 對台灣股票代碼進行特殊處理
        let processedSymbol = processTaiwanStockSymbol(symbol)
        
        // 只使用標準域名，避免使用IP地址（違反安全規則）
        let baseURL = "https://query1.finance.yahoo.com"
        self.logger.info("使用標準Yahoo Finance API端點: \(baseURL)")
        
        // 嘗試創建URL
        guard var urlComponents = URLComponents(string: "\(baseURL)/v8/finance/chart/\(processedSymbol)") else {
            self.logger.error("無法構造URL")
            completion(nil, NSError(domain: "com.menu-bar-stock-info", code: 8, userInfo: [NSLocalizedDescriptionKey: "無法構造URL"]))
            return
        }
        
        // 設置查詢參數
        urlComponents.queryItems = [
            URLQueryItem(name: "symbol", value: processedSymbol),
            URLQueryItem(name: "period1", value: String(startTimestamp)),
            URLQueryItem(name: "period2", value: String(endTimestamp)),
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "includePrePost", value: "true"),
            URLQueryItem(name: "cachecounter", value: String(Int.random(in: 100...1000)))
        ]
        
        // 創建請求
        guard let url = urlComponents.url else {
            self.logger.error("無法構造URL")
            completion(nil, NSError(domain: "com.menu-bar-stock-info", code: 8, userInfo: [NSLocalizedDescriptionKey: "無法構造URL"]))
            return
        }
        
        self.logger.info("直接請求圖表數據: \(url)")
        
        var request = URLRequest(url: url)
        request.addValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3.1 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.addValue("https://finance.yahoo.com", forHTTPHeaderField: "Referer")
        request.addValue("en-US,en;q=0.9,zh-TW;q=0.8,zh;q=0.7", forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 30  // 增加超時時間
        
        // 創建自定義的URLSessionConfiguration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30  // 增加超時時間
        config.timeoutIntervalForResource = 60 // 增加資源超時時間
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 5
        config.requestCachePolicy = .useProtocolCachePolicy  // 使用協議默認緩存策略
        
        if #available(macOS 14.0, *) {
            config.allowsConstrainedNetworkAccess = true
            config.allowsExpensiveNetworkAccess = true
        }
        
        // 使用自定義的URLSession
        let session = URLSession(configuration: config)
        
        // 執行請求
        let task = session.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            // 檢查錯誤
            if let error = error {
                self.logger.error("獲取圖表數據失敗: \(error.localizedDescription)")
                
                // 如果是超時錯誤，嘗試退回到使用SwiftYFinance庫
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
                    self.logger.warning("直接請求超時，嘗試使用SwiftYFinance庫")
                    self.fetchChartDataUsingSwiftYFinance(symbol: symbol, start: start, end: end, completion: completion)
                    return
                }
                
                completion(nil, error)
                return
            }
            
            // 檢查HTTP狀態碼
            if let httpResponse = response as? HTTPURLResponse {
                if !(200...299).contains(httpResponse.statusCode) {
                    self.logger.error("HTTP錯誤: \(httpResponse.statusCode)")
                    completion(nil, NSError(domain: "com.menu-bar-stock-info", code: 14, userInfo: [NSLocalizedDescriptionKey: "HTTP錯誤: \(httpResponse.statusCode)"]))
                    return
                }
            }
            
            // 確保有數據
            guard let data = data else {
                self.logger.error("無數據返回")
                completion(nil, NSError(domain: "com.menu-bar-stock-info", code: 9, userInfo: [NSLocalizedDescriptionKey: "無數據返回"]))
                return
            }
            
            // 嘗試解析JSON數據
            do {
                // 使用JSONSerialization進行解析
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.logger.error("無法解析JSON")
                    completion(nil, NSError(domain: "com.menu-bar-stock-info", code: 10, userInfo: [NSLocalizedDescriptionKey: "無法解析JSON"]))
                    return
                }
                
                // 檢查是否有錯誤信息
                if let chart = json["chart"] as? [String: Any],
                   let error = chart["error"] as? [String: Any],
                   let description = error["description"] as? String {
                    self.logger.error("Yahoo API錯誤: \(description)")
                    completion(nil, NSError(domain: "com.menu-bar-stock-info", code: 15, userInfo: [NSLocalizedDescriptionKey: "Yahoo API錯誤: \(description)"]))
                    return
                }
                
                // 提取數據
                guard let chart = json["chart"] as? [String: Any],
                      let result = chart["result"] as? [[String: Any]],
                      !result.isEmpty else {
                    self.logger.error("JSON格式無效")
                    completion(nil, NSError(domain: "com.menu-bar-stock-info", code: 10, userInfo: [NSLocalizedDescriptionKey: "JSON格式無效"]))
                    return
                }
                
                // 提取時間戳和價格數據
                let firstResult = result[0]
                guard let timestamps = firstResult["timestamp"] as? [Int],
                      let indicators = firstResult["indicators"] as? [String: Any],
                      let quote = indicators["quote"] as? [[String: Any]],
                      !quote.isEmpty else {
                    self.logger.error("無法提取數據點")
                    completion(nil, NSError(domain: "com.menu-bar-stock-info", code: 11, userInfo: [NSLocalizedDescriptionKey: "無法提取數據點"]))
                    return
                }
                
                let quoteData = quote[0]
                guard let closes = quoteData["close"] as? [Double?],
                      let opens = quoteData["open"] as? [Double?],
                      let lows = quoteData["low"] as? [Double?],
                      let highs = quoteData["high"] as? [Double?],
                      let volumes = quoteData["volume"] as? [Int?] else {
                    self.logger.error("無法提取價格數據")
                    completion(nil, NSError(domain: "com.menu-bar-stock-info", code: 12, userInfo: [NSLocalizedDescriptionKey: "無法提取價格數據"]))
                    return
                }
                
                // 構造自定義ChartDataPoint對象
                var chartDataArray: [ChartDataPoint] = []
                
                for i in 0..<min(timestamps.count, closes.count) {
                    if let closeValue = closes[i] {
                        let openValue = i < opens.count ? opens[i] : nil
                        let lowValue = i < lows.count ? lows[i] : nil
                        let highValue = i < highs.count ? highs[i] : nil
                        let volumeValue = i < volumes.count ? volumes[i] : nil
                        
                        let date = Date(timeIntervalSince1970: TimeInterval(timestamps[i]))
                        let chartData = ChartDataPoint(
                            date: date,
                            volume: volumeValue,
                            open: openValue != nil ? Float(openValue!) : nil,
                            close: Float(closeValue),
                            adjclose: Float(closeValue),
                            low: lowValue != nil ? Float(lowValue!) : nil,
                            high: highValue != nil ? Float(highValue!) : nil
                        )
                        chartDataArray.append(chartData)
                    }
                }
                
                self.logger.info("成功獲取歷史數據點: \(chartDataArray.count)")
                completion(chartDataArray, nil)
                
            } catch {
                self.logger.error("解析JSON出錯: \(error.localizedDescription)")
                completion(nil, error)
            }
        }
        
        task.resume()
    }
    
    // 使用SwiftYFinance庫獲取圖表數據（作為備用）
    private func fetchChartDataUsingSwiftYFinance(symbol: String, start: Date, end: Date, completion: @escaping ([ChartDataPoint]?, Error?) -> Void) {
        self.logger.info("使用SwiftYFinance庫獲取圖表數據")
        
        SwiftYFinance.chartDataBy(identifier: symbol, start: start, end: end, interval: .oneday) { chartData, error in
            if let error = error {
                self.logger.error("SwiftYFinance獲取圖表數據失敗: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let chartData = chartData, !chartData.isEmpty else {
                self.logger.error("SwiftYFinance返回空圖表數據")
                completion(nil, NSError(domain: "com.menu-bar-stock-info", code: 3, userInfo: [NSLocalizedDescriptionKey: "無效的歷史數據"]))
                return
            }
            
            // 轉換為我們的ChartDataPoint格式
            let chartDataPoints = chartData.map { data -> ChartDataPoint in
                ChartDataPoint(
                    date: data.date,
                    volume: data.volume,
                    open: data.open,
                    close: data.close,
                    adjclose: data.adjclose,
                    low: data.low,
                    high: data.high
                )
            }
            
            self.logger.info("SwiftYFinance成功獲取歷史數據點: \(chartDataPoints.count)")
            completion(chartDataPoints, nil)
        }
    }
    
    // 處理台灣股票代碼的方法
    private func processTaiwanStockSymbol(_ symbol: String) -> String {
        // 檢查是否為台灣主板股票（以.TW結尾）
        if symbol.hasSuffix(".TW") {
            // 台灣知名股票代碼列表，這些代碼不需要補0
            let knownTaiwanStocks = ["2330.TW", "2454.TW", "2317.TW", "2412.TW", "2308.TW", 
                                    "2303.TW", "2881.TW", "2882.TW", "2886.TW", "2891.TW"]
            
            // 如果是已知的股票代碼，直接返回原始代碼
            if knownTaiwanStocks.contains(symbol) {
                self.logger.info("使用知名台灣股票原始代碼: \(symbol)")
                return symbol
            }
            
            let code = symbol.replacingOccurrences(of: ".TW", with: "")
            
            // 檢查代碼長度
            // 如果代碼長度已經是4位或更長，不需要補零
            if code.count >= 4 {
                self.logger.info("台灣股票代碼長度已達4位或更長，保持原始代碼: \(symbol)")
                return symbol
            }
            
            // 如果是數字代碼且少於4位，前面補0到4位
            if code.allSatisfy({ $0.isNumber }) && code.count < 4 {
                let paddedCode = String(format: "%04d", Int(code) ?? 0)
                let resultCode = "\(paddedCode).TW"
                self.logger.info("補零後的台灣股票代碼: \(resultCode)")
                return resultCode
            }
        }
        // 如果是OTC櫃買中心股票（以.TWO結尾），特殊處理
        else if symbol.hasSuffix(".TWO") {
            // 根據標準，OTC股票代碼不需要補零，直接使用原始代碼
            self.logger.info("處理OTC股票代碼: \(symbol)，保持原格式")
            return symbol
        }
        
        // 對於其他類型的台灣股票或已經處理過的股票，直接返回原始代碼
        return symbol
    }
    
    // 修正 change 和 changePercent 以確保一致性
    private func correctChangeValues(_ stock: StockModel) -> StockModel {
        var correctedStock = stock
        
        // 根據 changePercent 重新計算 change
        correctedStock.change = stock.price * stock.changePercent / 100.0
        
        return correctedStock
    }
    
    // 模擬數據（作為備用）
    private func mockFetchStockData(for symbol: String) -> AnyPublisher<StockModel, Error> {
        let mockData: StockModel
        
        switch symbol.uppercased() {
        case "AAPL":
            mockData = StockModel(
                symbol: "AAPL",
                name: "Apple Inc.",
                price: Double.random(in: 160...170),
                change: Double.random(in: -3...3),
                changePercent: Double.random(in: -2...2),
                volume: Int.random(in: 40_000_000...50_000_000),
                marketCap: 2_700_000_000_000,
                high52Week: 188.52,
                low52Week: 143.90,
                timestamp: Date()
            )
        case "MSFT":
            mockData = StockModel(
                symbol: "MSFT",
                name: "Microsoft Corporation",
                price: Double.random(in: 300...310),
                change: Double.random(in: -4...4),
                changePercent: Double.random(in: -1.5...1.5),
                volume: Int.random(in: 30_000_000...40_000_000),
                marketCap: 2_300_000_000_000,
                high52Week: 315.95,
                low52Week: 275.37,
                timestamp: Date()
            )
        case "GOOG":
            mockData = StockModel(
                symbol: "GOOG",
                name: "Alphabet Inc.",
                price: Double.random(in: 140...145),
                change: Double.random(in: -2...2),
                changePercent: Double.random(in: -1...1),
                volume: Int.random(in: 25_000_000...35_000_000),
                marketCap: 1_800_000_000_000,
                high52Week: 150.28,
                low52Week: 120.47,
                timestamp: Date()
            )
        case "AMZN":
            mockData = StockModel(
                symbol: "AMZN",
                name: "Amazon.com, Inc.",
                price: Double.random(in: 178...185),
                change: Double.random(in: -3...3),
                changePercent: Double.random(in: -1.8...1.8),
                volume: Int.random(in: 35_000_000...45_000_000),
                marketCap: 1_900_000_000_000,
                high52Week: 188.65,
                low52Week: 155.50,
                timestamp: Date()
            )
        case "META":
            mockData = StockModel(
                symbol: "META",
                name: "Meta Platforms, Inc.",
                price: Double.random(in: 480...495),
                change: Double.random(in: -5...5),
                changePercent: Double.random(in: -1.2...1.2),
                volume: Int.random(in: 20_000_000...30_000_000),
                marketCap: 1_250_000_000_000,
                high52Week: 504.25,
                low52Week: 274.38,
                timestamp: Date()
            )
        case "TSLA":
            mockData = StockModel(
                symbol: "TSLA",
                name: "Tesla, Inc.",
                price: Double.random(in: 170...180),
                change: Double.random(in: -8...8),
                changePercent: Double.random(in: -5...5),
                volume: Int.random(in: 50_000_000...70_000_000),
                marketCap: 550_000_000_000,
                high52Week: 299.29,
                low52Week: 138.80,
                timestamp: Date()
            )
        default:
            // 對於未知股票，使用通用模擬數據方法
            mockData = createMockStockData(for: symbol)
        }
        
        // 確保 change 和 changePercent 一致
        let mockDataWithConsistentChange = correctChangeValues(mockData)
        
        return Just(mockDataWithConsistentChange)
            .setFailureType(to: Error.self)
            .delay(for: .seconds(0.5), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }
}

// 歷史數據點結構
struct HistoricalDataPoint: Identifiable {
    var id = UUID()
    let date: Date
    let price: Double
} 
