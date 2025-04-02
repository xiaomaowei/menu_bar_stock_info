//
//  StockDetailView.swift
//  menu_bar_stock_info
//
//  Created by Denis Wei on 2025/4/2.
//

import SwiftUI
import Charts

struct StockDetailView: View {
    let stock: StockModel
    let historicalData: [HistoricalDataPoint]?
    @State private var selectedPoint: HistoricalDataPoint?
    
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
            
            // 歷史價格圖表
            if let data = historicalData, !data.isEmpty {
                chartView(data: data)
                    .frame(height: 120)
            } else {
                Text("無歷史數據")
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.secondary)
            }
            
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
        .frame(width: 320, height: 320)
    }
    
    // 圖表視圖
    @ViewBuilder
    private func chartView(data: [HistoricalDataPoint]) -> some View {
        Chart {
            ForEach(data) { point in
                LineMark(
                    x: .value("日期", point.date),
                    y: .value("價格", point.price)
                )
                .foregroundStyle(stock.isPositive ? .green : .red)
                .interpolationMethod(.catmullRom)
            }
            
            if let selected = selectedPoint {
                RuleMark(x: .value("Selected", selected.date))
                    .foregroundStyle(.gray.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .trailing) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dateFormatter.string(from: selected.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("$\(String(format: "%.2f", selected.price))")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .shadow(radius: 2)
                        )
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(compactDateFormatter.string(from: date))
                            .font(.caption)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x
                                
                                if let date = proxy.value(atX: x, as: Date.self),
                                   let closestPoint = findClosestPoint(to: date, in: data) {
                                    selectedPoint = closestPoint
                                }
                            }
                            .onEnded { _ in
                                selectedPoint = nil
                            }
                    )
            }
        }
        .chartYScale(domain: [minPrice(in: data) * 0.99, maxPrice(in: data) * 1.01])
    }
    
    private func findClosestPoint(to date: Date, in data: [HistoricalDataPoint]) -> HistoricalDataPoint? {
        guard !data.isEmpty else { return nil }
        
        return data.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }
    
    private func minPrice(in data: [HistoricalDataPoint]) -> Double {
        data.map { $0.price }.min() ?? 0
    }
    
    private func maxPrice(in data: [HistoricalDataPoint]) -> Double {
        data.map { $0.price }.max() ?? 0
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    private var compactDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter
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

// 預覽視圖
#Preview {
    // 創建測試數據
    let mockStock = StockModel.mockData
    let mockHistoricalData = [
        HistoricalDataPoint(date: Date().addingTimeInterval(-86400 * 30), price: 150.0),
        HistoricalDataPoint(date: Date().addingTimeInterval(-86400 * 25), price: 153.2),
        HistoricalDataPoint(date: Date().addingTimeInterval(-86400 * 20), price: 149.8),
        HistoricalDataPoint(date: Date().addingTimeInterval(-86400 * 15), price: 155.6),
        HistoricalDataPoint(date: Date().addingTimeInterval(-86400 * 10), price: 160.2),
        HistoricalDataPoint(date: Date().addingTimeInterval(-86400 * 5), price: 162.4),
        HistoricalDataPoint(date: Date(), price: mockStock.price)
    ]
    
    return StockDetailView(stock: mockStock, historicalData: mockHistoricalData)
        .frame(width: 320, height: 320)
} 