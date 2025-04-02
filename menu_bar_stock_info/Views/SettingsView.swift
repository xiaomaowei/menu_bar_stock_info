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
        VStack(spacing: 16) {
            // 添加股票區域
            VStack(alignment: .leading, spacing: 8) {
                Text("添加股票")
                    .font(.headline)
                
                HStack {
                    TextField("輸入股票代碼", text: $viewModel.newStockSymbol)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disableAutocorrection(true)
                        .frame(minWidth: 300)
                    
                    Button(action: {
                        viewModel.addStock()
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Text("添加")
                        }
                    }
                    .disabled(viewModel.newStockSymbol.isEmpty || viewModel.isLoading)
                    .frame(width: 80)
                }
                
                // 錯誤訊息
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 其他設定選項
            generalSettingsSection
            
            stocksSection
        }
        .padding()
        .sheet(isPresented: $showingAddAlert) {
            addAlertView
        }
    }
    
    private var generalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("一般設置")
                .font(.headline)
                .padding(.bottom, 4)
            
            Group {
                HStack(alignment: .center) {
                    Text("刷新時間")
                        .frame(width: 100, alignment: .leading)
                    
                    Picker("", selection: $viewModel.config.refreshInterval) {
                        Text("30秒").tag(TimeInterval(30))
                        Text("1分鐘").tag(TimeInterval(60))
                        Text("5分鐘").tag(TimeInterval(300))
                        Text("15分鐘").tag(TimeInterval(900))
                        Text("30分鐘").tag(TimeInterval(1800))
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 4)
                
                HStack {
                    Text("顯示格式")
                        .frame(width: 100, alignment: .leading)
                    
                    Picker("", selection: $viewModel.config.displayFormat) {
                        ForEach(ConfigModel.DisplayFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 4)
                
                if viewModel.config.displayFormat == .custom {
                    TextField("自定義格式", text: Binding(
                        get: { viewModel.config.customFormatString ?? "{symbol}: {price} {change}" },
                        set: { viewModel.config.customFormatString = $0 }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, 4)
                    
                    Text("格式變量: {symbol}, {price}, {change}, {percent}")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                }
                
                HStack {
                    Text("選單列文字顏色")
                        .frame(width: 120, alignment: .leading)
                    
                    Picker("", selection: $viewModel.config.textColorMode) {
                        ForEach(ConfigModel.TextColorMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 8)
                
                // 勾選項調整為兩行，每行兩個
                VStack(alignment: .leading, spacing: 8) {
                    // 第一行：兩個勾選項
                    HStack(spacing: 16) {
                        Toggle("顯示漲跌百分比", isOn: $viewModel.config.showChangePercent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Toggle("輪換顯示多支股票", isOn: $viewModel.config.rotateStocks)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // 第二行：一個勾選項 (可以增加更多)
                    HStack(spacing: 16) {
                        Toggle("啟動時顯示設置菜單", isOn: $viewModel.config.showSettingsOnStartup)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Spacer()
                    }
                }
                .padding(.bottom, 8)
            }
            
            // 套用設置按鈕放到右下角
            HStack {
                Spacer()
                
                Button("套用設置") {
                    viewModel.saveSettings()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var stocksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("股票管理")
                .font(.headline)
                .padding(.bottom, 4)
            
            if viewModel.config.stockSymbols.isEmpty {
                Text("尚未添加任何股票")
                    .foregroundColor(.gray)
                    .italic()
                    .frame(height: 150)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                List {
                    ForEach(viewModel.config.stockSymbols, id: \.self) { symbol in
                        HStack {
                            Text(symbol)
                                .frame(minWidth: 100, alignment: .leading)
                            
                            Spacer()
                            
                            Button("添加提醒") {
                                selectedStock = symbol
                                showingAddAlert = true
                            }
                            .buttonStyle(.borderless)
                            
                            Text("\(viewModel.config.alertThresholds[symbol]?.count ?? 0)個提醒")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 80)
                            
                            Button(action: {
                                if let index = viewModel.config.stockSymbols.firstIndex(of: symbol) {
                                    viewModel.removeStock(at: IndexSet(integer: index))
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        viewModel.removeStock(at: indexSet)
                    }
                }
                .listStyle(PlainListStyle())
                .frame(height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
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