//
//  ConfigModel.swift
//  menu_bar_stock_info
//
//  Created by Denis Wei on 2025/4/2.
//

import Foundation

// 添加对StockModel的引用，解决编译错误
// SwiftCompile 错误是由于AlertThreshold.isTriggered方法中使用了StockModel类型，但没有导入该类型
struct StockModelReference {
    // 这个引用用于确保编译时能够找到StockModel
    // 后续可以删除这个结构体
    @available(*, unavailable)
    static func reference() {
        let _ = StockModel.mockData
    }
}

struct ConfigModel: Codable {
    var stockSymbols: [String]
    var refreshInterval: TimeInterval // 以秒為單位
    var displayFormat: DisplayFormat
    var showChangePercent: Bool
    var rotateStocks: Bool
    var alertThresholds: [String: [AlertThreshold]]
    
    // 顯示格式枚舉
    enum DisplayFormat: String, Codable, CaseIterable {
        case symbolAndPrice = "Symbol + Price"
        case symbolAndChange = "Symbol + Change"
        case priceOnly = "Price Only"
        case changeOnly = "Change Only"
        case custom = "Custom"
    }
    
    // 自定義格式字符串
    var customFormatString: String?
    
    // 默認配置
    static var defaultConfig: ConfigModel {
        ConfigModel(
            stockSymbols: ["AAPL", "MSFT", "GOOG"],
            refreshInterval: 60.0, // 60秒
            displayFormat: .symbolAndPrice,
            showChangePercent: true,
            rotateStocks: false,
            alertThresholds: [:]
        )
    }
    
    // 輔助方法：從UserDefaults加載配置
    static func loadFromUserDefaults() -> ConfigModel {
        if let data = UserDefaults.standard.data(forKey: "stockAppConfig") {
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(ConfigModel.self, from: data)
            } catch {
                print("Error decoding config: \(error.localizedDescription)")
            }
        }
        return defaultConfig
    }
    
    // 輔助方法：保存配置到UserDefaults
    func saveToUserDefaults() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self)
            UserDefaults.standard.set(data, forKey: "stockAppConfig")
        } catch {
            print("Error encoding config: \(error.localizedDescription)")
        }
    }
}

// 警報閾值結構
struct AlertThreshold: Codable, Identifiable {
    var id = UUID()
    var type: AlertType
    var value: Double
    var triggered: Bool = false
    
    enum AlertType: String, Codable, CaseIterable {
        case priceAbove = "Price Above"
        case priceBelow = "Price Below"
        case percentChangeAbove = "Percent Change Above"
        case percentChangeBelow = "Percent Change Below"
    }
    
    // 檢查股票是否觸發閾值
    func isTriggered(for stock: StockModel) -> Bool {
        switch type {
        case .priceAbove:
            return stock.price > value
        case .priceBelow:
            return stock.price < value
        case .percentChangeAbove:
            return stock.changePercent > value
        case .percentChangeBelow:
            return stock.changePercent < value
        }
    }
}

// 確保UUID在編碼和解碼時保持一致
extension AlertThreshold {
    enum CodingKeys: String, CodingKey {
        case id, type, value, triggered
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        type = try container.decode(AlertType.self, forKey: .type)
        value = try container.decode(Double.self, forKey: .value)
        triggered = try container.decodeIfPresent(Bool.self, forKey: .triggered) ?? false
    }
} 