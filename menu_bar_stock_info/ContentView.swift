//
//  ContentView.swift
//  menu_bar_stock_info
//
//  Created by Denis Wei on 2025/4/2.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var stockViewModel = StockViewModel()
    @StateObject private var settingsViewModel: SettingsViewModel
    @State private var selectedTab = 0
    
    init() {
        let stockVM = StockViewModel()
        _stockViewModel = StateObject(wrappedValue: stockVM)
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(stockViewModel: stockVM))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SettingsView(viewModel: settingsViewModel, stockViewModel: stockViewModel)
                .tabItem {
                    Label("設置", systemImage: "gear")
                }
                .tag(0)
            
            StockListView(viewModel: stockViewModel)
                .tabItem {
                    Label("股票", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)
            
            AboutView()
                .tabItem {
                    Label("關於", systemImage: "info.circle")
                }
                .tag(2)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}

// 臨時使用的佔位視圖
struct StockListView: View {
    @ObservedObject var viewModel: StockViewModel
    
    var body: some View {
        VStack {
            Text("股票列表")
                .font(.headline)
                .padding()
            
            List {
                ForEach(viewModel.stocks) { stock in
                    StockRowView(stock: stock)
                }
            }
            
            Button("刷新數據") {
                viewModel.fetchStockData()
            }
            .padding()
        }
    }
}

struct StockRowView: View {
    let stock: StockModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(stock.symbol)
                    .font(.headline)
                Text(stock.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(stock.formattedPrice)
                    .font(.headline)
                
                Text(stock.formattedChange)
                    .foregroundColor(stock.isPositive ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
            
            Text("菜單欄股票行情")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("版本 1.0.0")
                .foregroundColor(.secondary)
            
            Text("一個簡潔的菜單欄應用，用於顯示您關注的股票實時行情。")
                .multilineTextAlignment(.center)
                .padding()
            
            Spacer()
            
            Text("© 2025 Denis Wei")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
