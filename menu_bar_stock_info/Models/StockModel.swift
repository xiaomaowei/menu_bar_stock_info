//
//  StockModel.swift
//  menu_bar_stock_info
//
//  Created by Denis Wei on 2025/4/2.
//

import Foundation

struct StockModel: Identifiable, Codable {
    var id: String { symbol }
    var symbol: String
    var name: String
    var price: Double
    var change: Double
    var changePercent: Double
    var volume: Int
    var marketCap: Double?
    var high52Week: Double?
    var low52Week: Double?
    var timestamp: Date
    
    // 格式化價格顯示
    var formattedPrice: String {
        String(format: "%.2f", price)
    }
    
    // 格式化漲跌顯示
    var formattedChange: String {
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", change))"
    }
    
    // 格式化漲跌百分比顯示
    var formattedChangePercent: String {
        let sign = changePercent >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", changePercent))%"
    }
    
    // 判斷是否上漲
    var isPositive: Bool {
        change >= 0
    }
    
    // 格式化成交量顯示
    var formattedVolume: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        
        if volume >= 1_000_000_000 {
            return "\(formatter.string(from: NSNumber(value: Double(volume) / 1_000_000_000)) ?? "0")B"
        } else if volume >= 1_000_000 {
            return "\(formatter.string(from: NSNumber(value: Double(volume) / 1_000_000)) ?? "0")M"
        } else if volume >= 1_000 {
            return "\(formatter.string(from: NSNumber(value: Double(volume) / 1_000)) ?? "0")K"
        } else {
            return "\(volume)"
        }
    }
    
    // 格式化市值顯示
    var formattedMarketCap: String? {
        guard let marketCap = marketCap else { return nil }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        
        if marketCap >= 1_000_000_000_000 {
            return "\(formatter.string(from: NSNumber(value: marketCap / 1_000_000_000_000)) ?? "0")T"
        } else if marketCap >= 1_000_000_000 {
            return "\(formatter.string(from: NSNumber(value: marketCap / 1_000_000_000)) ?? "0")B"
        } else if marketCap >= 1_000_000 {
            return "\(formatter.string(from: NSNumber(value: marketCap / 1_000_000)) ?? "0")M"
        } else {
            return "\(formatter.string(from: NSNumber(value: marketCap)) ?? "0")"
        }
    }
}

// 配置模型的擴展，用於本地存儲
extension StockModel {
    // 測試數據
    static var mockData: StockModel {
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
        )
    }
} 