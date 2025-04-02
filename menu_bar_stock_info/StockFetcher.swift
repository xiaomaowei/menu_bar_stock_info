//
//  StockFetcher.swift
//  menu_bar_stock_info
//
//  Created by Denis Wei on 2025/4/2.
//

import Foundation
import Combine
import OSLog

class StockFetcher {
    private let logger = Logger(subsystem: "com.menu-bar-stock-info", category: "StockFetcher")
    
    // 從 API 獲取股票數據
    func fetchStockData(for symbol: String) -> AnyPublisher<StockModel, Error> {
        logger.info("Fetching stock data for \(symbol)")
        
        // TODO: 整合 SwiftYFinance 獲取實際數據
        // 暫時返回模擬數據
        return mockFetchStockData(for: symbol)
    }
    
    // 獲取多支股票數據
    func fetchMultipleStocks(symbols: [String]) -> AnyPublisher<[StockModel], Error> {
        let publishers = symbols.map { fetchStockData(for: $0) }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .eraseToAnyPublisher()
    }
    
    // 模擬數據
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

// MARK: - 未來 SwiftYFinance 整合
extension StockFetcher {
    // TODO: 使用 SwiftYFinance 實現實際的數據獲取
    // func fetchRealStockData(for symbol: String) -> AnyPublisher<StockModel, Error> {
    //     // 實際實現將在整合 SwiftYFinance 時添加
    // }
} 