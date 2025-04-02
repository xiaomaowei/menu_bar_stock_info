//
//  StockViewModel.swift
//  menu_bar_stock_info
//
//  Created by Denis Wei on 2025/4/2.
//

import Foundation
import Combine
import OSLog

class StockViewModel: ObservableObject {
    @Published var stocks: [StockModel] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.menu-bar-stock-info", category: "StockViewModel")
    
    private var config: ConfigModel
    
    init() {
        // 從 UserDefaults 加載配置
        config = ConfigModel.loadFromUserDefaults()
        
        // 加載初始測試數據
        loadMockData()
    }
    
    // 加載測試數據
    private func loadMockData() {
        stocks = [
            StockModel(
                symbol: "AAPL",
                name: "Apple Inc.",
                price: 165.23,
                change: 1.23,
                changePercent: 0.75,
                volume: 45_678_900,
                marketCap: 2_700_000_000_000,
                high52Week: 188.52,
                low52Week: 143.90,
                timestamp: Date()
            ),
            StockModel(
                symbol: "MSFT",
                name: "Microsoft Corporation",
                price: 305.42,
                change: -2.34,
                changePercent: -0.76,
                volume: 32_456_700,
                marketCap: 2_300_000_000_000,
                high52Week: 315.95,
                low52Week: 275.37,
                timestamp: Date()
            ),
            StockModel(
                symbol: "GOOG",
                name: "Alphabet Inc.",
                price: 142.56,
                change: 0.87,
                changePercent: 0.61,
                volume: 28_345_600,
                marketCap: 1_800_000_000_000,
                high52Week: 150.28,
                low52Week: 120.47,
                timestamp: Date()
            )
        ]
    }
    
    // 從 API 獲取股票數據
    func fetchStockData() {
        isLoading = true
        error = nil
        
        // TODO: 整合 SwiftYFinance 獲取真實數據
        // 暫時使用模擬數據
        
        // 模擬網絡請求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // 更新測試數據，模擬價格變化
            self.updateMockData()
            self.isLoading = false
            
            // 檢查警報閾值
            self.checkAlertThresholds()
            
            self.logger.info("Stock data updated successfully")
        }
    }
    
    // 更新測試數據
    private func updateMockData() {
        for i in 0..<stocks.count {
            if i < stocks.count {
                let randomChange = Double.random(in: -5.0...5.0)
                let newPrice = max(stocks[i].price + randomChange, 1.0) // 確保價格為正
                let changeValue = newPrice - stocks[i].price
                let changePercent = (changeValue / stocks[i].price) * 100.0
                
                stocks[i].price = newPrice
                stocks[i].change = changeValue
                stocks[i].changePercent = changePercent
                stocks[i].timestamp = Date()
                stocks[i].volume = Int.random(in: 10_000_000...50_000_000)
            }
        }
    }
    
    // 檢查是否有觸發警報閾值
    private func checkAlertThresholds() {
        for stock in stocks {
            if let thresholds = config.alertThresholds[stock.symbol] {
                for threshold in thresholds {
                    if threshold.isTriggered(for: stock) && !threshold.triggered {
                        // 觸發通知
                        sendNotification(for: stock, threshold: threshold)
                        
                        // 更新閾值狀態
                        updateThresholdStatus(symbol: stock.symbol, thresholdId: threshold.id, triggered: true)
                    }
                }
            }
        }
    }
    
    // 發送系統通知
    private func sendNotification(for stock: StockModel, threshold: AlertThreshold) {
        let content = UNMutableNotificationContent()
        content.title = "股票提醒: \(stock.symbol)"
        
        switch threshold.type {
        case .priceAbove:
            content.body = "\(stock.name) 價格已超過 \(threshold.value)，當前為 \(stock.formattedPrice)"
        case .priceBelow:
            content.body = "\(stock.name) 價格已低於 \(threshold.value)，當前為 \(stock.formattedPrice)"
        case .percentChangeAbove:
            content.body = "\(stock.name) 漲幅已超過 \(threshold.value)%，當前為 \(stock.formattedChangePercent)"
        case .percentChangeBelow:
            content.body = "\(stock.name) 跌幅已超過 \(abs(threshold.value))%，當前為 \(stock.formattedChangePercent)"
        }
        
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // 更新閾值觸發狀態
    private func updateThresholdStatus(symbol: String, thresholdId: UUID, triggered: Bool) {
        if var thresholds = config.alertThresholds[symbol] {
            if let index = thresholds.firstIndex(where: { $0.id == thresholdId }) {
                thresholds[index].triggered = triggered
                config.alertThresholds[symbol] = thresholds
                config.saveToUserDefaults()
            }
        }
    }
    
    // 重置所有閾值的觸發狀態
    func resetAllThresholds() {
        var updated = false
        
        for (symbol, thresholds) in config.alertThresholds {
            var updatedThresholds = thresholds
            for i in 0..<updatedThresholds.count {
                if updatedThresholds[i].triggered {
                    updatedThresholds[i].triggered = false
                    updated = true
                }
            }
            config.alertThresholds[symbol] = updatedThresholds
        }
        
        if updated {
            config.saveToUserDefaults()
        }
    }
    
    // 獲取特定股票的數據
    func getStock(for symbol: String) -> StockModel? {
        return stocks.first(where: { $0.symbol == symbol })
    }
    
    // 添加股票到跟踪列表
    func addStock(symbol: String) {
        if !config.stockSymbols.contains(symbol) {
            config.stockSymbols.append(symbol)
            config.saveToUserDefaults()
            // TODO: 從 API 獲取新添加的股票數據
        }
    }
    
    // 從跟踪列表中移除股票
    func removeStock(symbol: String) {
        if let index = config.stockSymbols.firstIndex(of: symbol) {
            config.stockSymbols.remove(at: index)
            config.alertThresholds[symbol] = nil
            config.saveToUserDefaults()
            
            // 同時從當前數據中移除
            stocks.removeAll(where: { $0.symbol == symbol })
        }
    }
    
    // 更新配置
    func updateConfig(_ newConfig: ConfigModel) {
        config = newConfig
        config.saveToUserDefaults()
    }
}

// MARK: - UNUserNotificationCenter Import
import UserNotifications 