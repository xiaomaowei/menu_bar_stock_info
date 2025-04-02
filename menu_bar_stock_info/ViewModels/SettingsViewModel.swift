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
    @Published var isLoading: Bool = false
    
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
        let trimmedSymbol = newStockSymbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmedSymbol.isEmpty else {
            errorMessage = "股票代碼不能為空"
            return
        }
        
        // 檢查是否已經存在
        guard !config.stockSymbols.contains(trimmedSymbol) else {
            errorMessage = "股票代碼已存在"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // 使用StockFetcher驗證股票代碼
        let stockFetcher = StockFetcher()
        stockFetcher.validateStockSymbol(trimmedSymbol)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                
                if case .failure(let error) = completion {
                    self.errorMessage = "驗證股票代碼時發生錯誤: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] isValid in
                guard let self = self else { return }
                
                if isValid {
                    self.config.stockSymbols.append(trimmedSymbol)
                    self.saveSettings()
                    self.newStockSymbol = ""
                } else {
                    self.errorMessage = "無法驗證股票代碼 \(trimmedSymbol)，請確認股票代碼是否正確"
                }
            }
            .store(in: &cancellables)
    }
    
    // 刪除股票
    func removeStock(at offsets: IndexSet) {
        config.stockSymbols.remove(atOffsets: offsets)
        saveSettings()
    }
    
    // 使用股票代碼移除股票
    func removeStock(_ symbol: String) {
        if let index = config.stockSymbols.firstIndex(of: symbol) {
            config.stockSymbols.remove(at: index)
            saveSettings()
        }
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