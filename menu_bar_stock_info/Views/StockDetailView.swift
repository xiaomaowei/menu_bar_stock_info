//
//  StockDetailView.swift
//  menu_bar_stock_info
//
//  Created by Denis Wei on 2025/4/2.
//

import SwiftUI

struct StockDetailView: View {
    let stock: StockModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題區
            HStack {
                VStack(alignment: .leading) {
                    Text(stock.symbol)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(stock.name)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 價格和漲跌幅
                VStack(alignment: .trailing) {
                    Text("$\(stock.formattedPrice)")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 4) {
                        Text(stock.formattedChange)
                        Text("(\(stock.formattedChangePercent))")
                    }
                    .font(.headline)
                    .foregroundColor(stock.isPositive ? .green : .red)
                }
            }
            .padding(.bottom, 8)
            
            Divider()
            
            // 詳細數據
            HStack(alignment: .top) {
                // 左側數據
                VStack(alignment: .leading, spacing: 8) {
                    detailRow(title: "成交量", value: stock.formattedVolume)
                    
                    if let marketCap = stock.formattedMarketCap {
                        detailRow(title: "市值", value: marketCap)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 右側數據
                VStack(alignment: .leading, spacing: 8) {
                    if let high = stock.high52Week {
                        detailRow(title: "52週高", value: String(format: "%.2f", high))
                    }
                    
                    if let low = stock.low52Week {
                        detailRow(title: "52週低", value: String(format: "%.2f", low))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Divider()
            
            // 時間戳記
            HStack {
                Spacer()
                
                Text("更新於 \(formattedTime)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 320, height: 220)
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: stock.timestamp)
    }
}

#Preview {
    StockDetailView(stock: StockModel.mockData)
        .frame(width: 320, height: 220)
} 