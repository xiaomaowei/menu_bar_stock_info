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
    @Published var historicalData: [String: [HistoricalDataPoint]] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.menu-bar-stock-info", category: "StockViewModel")
    private let stockFetcher = StockFetcher()
    
    private var config: ConfigModel
    private var fetchTimer: Timer?
    
    init() {
        // 從 UserDefaults 加載配置
        config = ConfigModel.loadFromUserDefaults()
        
        // 如果沒有配置的股票，設置初始默認股票
        if config.stockSymbols.isEmpty {
            config.stockSymbols = ["AAPL", "MSFT", "GOOG"]
            config.saveToUserDefaults()
        }
        
        // 加載初始數據
        fetchStockData()
    }
    
    // 從 API 獲取股票數據
    func fetchStockData() {
        isLoading = true
        error = nil
        
        let symbols = config.stockSymbols
        guard !symbols.isEmpty else {
            isLoading = false
            return
        }
        
        stockFetcher.fetchMultipleStocks(symbols: symbols)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    self.error = "獲取股票數據錯誤: \(error.localizedDescription)"
                    self.logger.error("Error fetching stock data: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] receivedStocks in
                guard let self = self else { return }
                self.stocks = receivedStocks
                
                // 檢查警報閾值
                self.checkAlertThresholds()
                
                self.logger.info("Stock data updated successfully: \(receivedStocks.count) stocks")
                
                // 如果股票列表發生變化，也獲取歷史數據
                self.fetchHistoricalDataIfNeeded()
            })
            .store(in: &cancellables)
    }
    
    // 獲取歷史數據
    private func fetchHistoricalDataIfNeeded() {
        for symbol in config.stockSymbols {
            if historicalData[symbol] == nil {
                fetchHistoricalData(for: symbol)
            }
        }
    }
    
    // 為特定股票獲取歷史數據
    func fetchHistoricalData(for symbol: String, period: String = "1mo") {
        stockFetcher.fetchHistoricalData(for: symbol, period: period)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.logger.error("Error fetching historical data for \(symbol): \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] dataPoints in
                self?.historicalData[symbol] = dataPoints
                self?.logger.info("Historical data updated for \(symbol): \(dataPoints.count) points")
            })
            .store(in: &cancellables)
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
            
            // 從 API 獲取新添加的股票數據
            fetchStockData()
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
            historicalData.removeValue(forKey: symbol)
        }
    }
    
    // 更新配置
    func updateConfig(_ newConfig: ConfigModel) {
        let oldInterval = config.refreshInterval
        let newInterval = newConfig.refreshInterval
        
        config = newConfig
        config.saveToUserDefaults()
        
        // 如果刷新間隔變化，重新設置定時器
        if oldInterval != newInterval {
            setupRefreshTimer()
        }
        
        // 如果股票列表變化，重新獲取數據
        fetchStockData()
    }
    
    // 設置刷新定時器
    private func setupRefreshTimer() {
        // 取消現有定時器
        fetchTimer?.invalidate()
        
        // 創建新定時器
        fetchTimer = Timer.scheduledTimer(timeInterval: config.refreshInterval, target: self, selector: #selector(refreshData), userInfo: nil, repeats: true)
    }
    
    // 刷新數據
    @objc private func refreshData() {
        fetchStockData()
    }
}

// MARK: - UNUserNotificationCenter Import
import UserNotifications 