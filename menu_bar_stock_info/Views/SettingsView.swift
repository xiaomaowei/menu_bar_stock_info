//
//  SettingsView.swift
//  menu_bar_stock_info
//
//  Created by Denis Wei on 2025/4/2.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var stockViewModel: StockViewModel
    
    @State private var showingAddAlert = false
    @State private var selectedStock: String? = nil
    @State private var alertType: AlertThreshold.AlertType = .priceAbove
    @State private var alertValue: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("設置")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            generalSettingsSection
            
            stocksSection
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingAddAlert) {
            addAlertView
        }
    }
    
    private var generalSettingsSection: some View {
        VStack(alignment: .leading) {
            Text("一般設置")
                .font(.headline)
                .padding(.bottom, 8)
            
            Picker("刷新間隔", selection: $viewModel.config.refreshInterval) {
                Text("30秒").tag(TimeInterval(30))
                Text("1分鐘").tag(TimeInterval(60))
                Text("5分鐘").tag(TimeInterval(300))
                Text("15分鐘").tag(TimeInterval(900))
                Text("30分鐘").tag(TimeInterval(1800))
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.bottom, 8)
            
            Picker("顯示格式", selection: $viewModel.config.displayFormat) {
                ForEach(ConfigModel.DisplayFormat.allCases, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .padding(.bottom, 8)
            
            if viewModel.config.displayFormat == .custom {
                TextField("自定義格式", text: Binding(
                    get: { viewModel.config.customFormatString ?? "{symbol}: {price} {change}" },
                    set: { viewModel.config.customFormatString = $0 }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom, 8)
                
                Text("格式變量: {symbol}, {price}, {change}, {percent}")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
            
            Toggle("顯示漲跌百分比", isOn: $viewModel.config.showChangePercent)
                .padding(.bottom, 8)
            
            Toggle("輪換顯示多支股票", isOn: $viewModel.config.rotateStocks)
                .padding(.bottom, 12)
            
            Button("套用設置") {
                viewModel.saveSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var stocksSection: some View {
        VStack(alignment: .leading) {
            Text("股票管理")
                .font(.headline)
                .padding(.bottom, 8)
            
            HStack {
                TextField("添加股票代碼", text: $viewModel.newStockSymbol)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        viewModel.addStock()
                    }
                
                Button("添加") {
                    viewModel.addStock()
                }
                .buttonStyle(.borderedProminent)
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            List {
                ForEach(viewModel.config.stockSymbols, id: \.self) { symbol in
                    HStack {
                        Text(symbol)
                        
                        Spacer()
                        
                        Button("添加提醒") {
                            selectedStock = symbol
                            showingAddAlert = true
                        }
                        .buttonStyle(.borderless)
                        
                        Text("\(viewModel.config.alertThresholds[symbol]?.count ?? 0)個提醒")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onDelete { indexSet in
                    viewModel.removeStock(at: indexSet)
                }
            }
            .frame(minHeight: 100, maxHeight: 200)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var addAlertView: some View {
        VStack(spacing: 20) {
            Text("為 \(selectedStock ?? "") 添加提醒")
                .font(.headline)
            
            Picker("提醒類型", selection: $alertType) {
                ForEach(AlertThreshold.AlertType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            TextField("閾值", text: $alertValue)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            HStack {
                Button("取消") {
                    showingAddAlert = false
                }
                .buttonStyle(.bordered)
                
                Button("添加") {
                    if let value = Double(alertValue), let stock = selectedStock {
                        viewModel.addAlertThreshold(for: stock, type: alertType, value: value)
                        showingAddAlert = false
                        alertValue = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(Double(alertValue) == nil)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

#Preview {
    let stockVM = StockViewModel()
    let settingsVM = SettingsViewModel(stockViewModel: stockVM)
    return SettingsView(viewModel: settingsVM, stockViewModel: stockVM)
} 