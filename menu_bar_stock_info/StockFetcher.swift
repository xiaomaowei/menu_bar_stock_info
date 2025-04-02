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

class StockFetcher {
    private let logger = Logger(subsystem: "com.menu-bar-stock-info", category: "StockFetcher")
    // 不要创建SwiftYFinance的实例，因为它是使用类方法的
    // private let yFinance = SwiftYFinance()
    
    // 從 API 獲取股票數據
    func fetchStockData(for symbol: String) -> AnyPublisher<StockModel, Error> {
        logger.info("Fetching stock data for \(symbol)")
        
        // 使用 SwiftYFinance 獲取實際數據
        return fetchRealStockData(for: symbol)
            .catch { error -> AnyPublisher<StockModel, Error> in
                // 如果獲取失敗，使用模擬數據
                self.logger.error("Failed to fetch data for \(symbol): \(error.localizedDescription)")
                return self.mockFetchStockData(for: symbol)
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
            // 獲取股票報價 - 使用类方法
            SwiftYFinance.fetchQuote(ticker: symbol) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let quote = result,
                      let price = quote.bid.value ?? quote.regularMarketPrice,
                      let change = quote.regularMarketChange,
                      let changePercent = quote.regularMarketChangePercent,
                      let volume = quote.regularMarketVolume else {
                    promise(.failure(NSError(domain: "com.menu-bar-stock-info", code: 1, userInfo: [NSLocalizedDescriptionKey: "不完整的股票數據"])))
                    return
                }
                
                // 創建 StockModel
                let stock = StockModel(
                    symbol: symbol,
                    name: quote.shortName ?? symbol,
                    price: price,
                    change: change,
                    changePercent: changePercent,
                    volume: volume,
                    marketCap: quote.marketCap,
                    high52Week: quote.fiftyTwoWeekHigh,
                    low52Week: quote.fiftyTwoWeekLow,
                    timestamp: Date()
                )
                
                promise(.success(stock))
            }
        }
        .timeout(5, scheduler: DispatchQueue.global()) // 設置超時時間
        .eraseToAnyPublisher()
    }
    
    // 獲取股票歷史數據
    func fetchHistoricalData(for symbol: String, period: String = "1mo") -> AnyPublisher<[HistoricalDataPoint], Error> {
        return Future<[HistoricalDataPoint], Error> { promise in
            // 这里也使用类方法
            SwiftYFinance.fetchChartData(for: symbol, period: period) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let chartData = result,
                      let timestamps = chartData.meta.timestamp,
                      let prices = chartData.meta.regularMarketPrice,
                      timestamps.count == prices.count else {
                    promise(.failure(NSError(domain: "com.menu-bar-stock-info", code: 2, userInfo: [NSLocalizedDescriptionKey: "無效的歷史數據"])))
                    return
                }
                
                var dataPoints: [HistoricalDataPoint] = []
                
                for i in 0..<timestamps.count {
                    let timestamp = Date(timeIntervalSince1970: Double(timestamps[i]))
                    dataPoints.append(HistoricalDataPoint(date: timestamp, price: prices[i]))
                }
                
                promise(.success(dataPoints))
            }
        }
        .timeout(10, scheduler: DispatchQueue.global())
        .eraseToAnyPublisher()
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
            // 對於未知股票，生成隨機數據
            mockData = StockModel(
                symbol: symbol.uppercased(),
                name: "\(symbol.uppercased()) Corporation",
                price: Double.random(in: 50...500),
                change: Double.random(in: -10...10),
                changePercent: Double.random(in: -5...5),
                volume: Int.random(in: 10_000_000...50_000_000),
                marketCap: Double.random(in: 10_000_000_000...3_000_000_000_000),
                high52Week: nil,
                low52Week: nil,
                timestamp: Date()
            )
        }
        
        // 確保 change 和 changePercent 一致
        let mockDataWithConsistentChange = correctChangeValues(mockData)
        
        return Just(mockDataWithConsistentChange)
            .setFailureType(to: Error.self)
            .delay(for: .seconds(0.5), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }
    
    // 修正 change 和 changePercent 以確保一致性
    private func correctChangeValues(_ stock: StockModel) -> StockModel {
        var correctedStock = stock
        
        // 根據 changePercent 重新計算 change
        correctedStock.change = stock.price * stock.changePercent / 100.0
        
        return correctedStock
    }
}

// 歷史數據點結構
struct HistoricalDataPoint: Identifiable {
    var id = UUID()
    let date: Date
    let price: Double
} 