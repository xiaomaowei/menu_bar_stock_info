//
//  SettingsViewModel.swift
//  menu_bar_stock_info
//
//  Created by Denis Wei on 2025/4/2.
//

import Foundation
import Combine

class SettingsViewModel: ObservableObject {
    @Published var config: ConfigModel
    @Published var newStockSymbol: String = ""
    @Published var errorMessage: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    private let stockViewModel: StockViewModel
    
    init(stockViewModel: StockViewModel) {
        self.stockViewModel = stockViewModel
        self.config = ConfigModel.loadFromUserDefaults()
    }
    
    // 保存設置
    func saveSettings() {
        config.saveToUserDefaults()
        stockViewModel.updateConfig(config)
    }
    
    // 添加股票
    func addStock() {
        guard !newStockSymbol.isEmpty else {
            errorMessage = "股票代碼不能為空"
            return
        }
        
        let symbol = newStockSymbol.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 檢查股票是否已存在
        if config.stockSymbols.contains(symbol) {
            errorMessage = "股票 \(symbol) 已存在於列表中"
            return
        }
        
        // TODO: 驗證股票代碼是否有效
        
        // 添加到列表
        config.stockSymbols.append(symbol)
        saveSettings()
        
        // 通知 StockViewModel 獲取新添加的股票數據
        stockViewModel.addStock(symbol: symbol)
        
        // 清空輸入框
        newStockSymbol = ""
        errorMessage = nil
    }
    
    // 刪除股票
    func removeStock(at offsets: IndexSet) {
        let symbolsToRemove = offsets.map { config.stockSymbols[$0] }
        config.stockSymbols.remove(atOffsets: offsets)
        
        // 同時刪除對應的閾值
        for symbol in symbolsToRemove {
            config.alertThresholds[symbol] = nil
            stockViewModel.removeStock(symbol: symbol)
        }
        
        saveSettings()
    }
    
    // 添加警報閾值
    func addAlertThreshold(for symbol: String, type: AlertThreshold.AlertType, value: Double) {
        let threshold = AlertThreshold(type: type, value: value)
        
        if var thresholds = config.alertThresholds[symbol] {
            thresholds.append(threshold)
            config.alertThresholds[symbol] = thresholds
        } else {
            config.alertThresholds[symbol] = [threshold]
        }
        
        saveSettings()
    }
    
    // 刪除警報閾值
    func removeAlertThreshold(for symbol: String, at index: Int) {
        guard var thresholds = config.alertThresholds[symbol], index < thresholds.count else {
            return
        }
        
        thresholds.remove(at: index)
        
        if thresholds.isEmpty {
            config.alertThresholds.removeValue(forKey: symbol)
        } else {
            config.alertThresholds[symbol] = thresholds
        }
        
        saveSettings()
    }
    
    // 重置所有警報
    func resetAllAlerts() {
        stockViewModel.resetAllThresholds()
    }
} 