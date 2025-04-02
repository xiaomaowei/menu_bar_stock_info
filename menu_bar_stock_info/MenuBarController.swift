//
//  MenuBarController.swift
//  menu_bar_stock_info
//
//  Created by Denis Wei on 2025/4/2.
//

import AppKit
import SwiftUI
import Combine

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem
    private var menu: NSMenu
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let stockViewModel: StockViewModel
    private var currentStockIndex = 0
    private var rotationTimer: Timer?
    private var popover: NSPopover?
    
    // 用於股票輪換顯示
    private var shouldRotate: Bool {
        let config = ConfigModel.loadFromUserDefaults()
        return config.rotateStocks && config.stockSymbols.count > 1
    }
    
    init(stockViewModel: StockViewModel) {
        // 創建狀態欄項目
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        self.stockViewModel = stockViewModel
        
        super.init()
        
        setupStatusItem()
        setupMenu()
        startUpdateTimer()
        
        // 訂閱股票數據更新
        stockViewModel.$stocks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuItems()
                self?.updateStatusItemDisplay()
            }
            .store(in: &cancellables)
    }
    
    private func setupStatusItem() {
        // 設置初始圖標和文字
        if let button = statusItem.button {
            button.title = "載入中..."
            button.image = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: nil)
        }
    }
    
    private func setupMenu() {
        // 添加菜單項
        menu.addItem(NSMenuItem(title: "更新數據", action: #selector(refreshData), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        
        // 股票列表區域（將動態更新）
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "設置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))
        
        // 設置菜單
        statusItem.menu = menu
    }
    
    private func startUpdateTimer() {
        // 獲取用戶設置的刷新間隔
        let config = ConfigModel.loadFromUserDefaults()
        let interval = config.refreshInterval
        
        // 設置定時器，根據用戶設置的間隔更新數據
        timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(refreshData), userInfo: nil, repeats: true)
        
        // 如果啟用了股票輪換，啟動輪換定時器
        if shouldRotate {
            startRotationTimer()
        }
        
        // 立即更新一次數據
        refreshData()
    }
    
    private func startRotationTimer() {
        // 每5秒輪換顯示一支股票
        rotationTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(rotateNextStock), userInfo: nil, repeats: true)
    }
    
    @objc private func rotateNextStock() {
        guard shouldRotate, !stockViewModel.stocks.isEmpty else { return }
        
        currentStockIndex = (currentStockIndex + 1) % stockViewModel.stocks.count
        updateStatusItemDisplay()
    }
    
    @objc private func refreshData() {
        // 獲取股票數據
        stockViewModel.fetchStockData()
    }
    
    private func updateStatusItemDisplay() {
        // 獲取當前設置
        let config = ConfigModel.loadFromUserDefaults()
        
        // 如果沒有股票數據，顯示載入中
        guard !stockViewModel.stocks.isEmpty else {
            if let button = statusItem.button {
                button.title = "載入中..."
                button.contentTintColor = NSColor.textColor
            }
            return
        }
        
        // 獲取當前要顯示的股票
        let stockIndex = shouldRotate ? currentStockIndex : 0
        if stockIndex >= stockViewModel.stocks.count {
            return
        }
        
        let stock = stockViewModel.stocks[stockIndex]
        
        // 根據設置格式化顯示內容
        let displayText = formatDisplayText(stock: stock, format: config.displayFormat, showPercent: config.showChangePercent, customFormat: config.customFormatString)
        
        // 更新菜單欄顯示
        if let button = statusItem.button {
            button.title = displayText
            
            // 根據股票漲跌設置顏色
            if stock.isPositive {
                button.contentTintColor = NSColor.green
            } else if stock.change < 0 {
                button.contentTintColor = NSColor.red
            } else {
                button.contentTintColor = NSColor.textColor
            }
        }
    }
    
    private func formatDisplayText(stock: StockModel, format: ConfigModel.DisplayFormat, showPercent: Bool, customFormat: String?) -> String {
        switch format {
        case .symbolAndPrice:
            return "\(stock.symbol): \(stock.formattedPrice)"
        case .symbolAndChange:
            if showPercent {
                return "\(stock.symbol): \(stock.formattedChange) (\(stock.formattedChangePercent))"
            } else {
                return "\(stock.symbol): \(stock.formattedChange)"
            }
        case .priceOnly:
            return stock.formattedPrice
        case .changeOnly:
            if showPercent {
                return "\(stock.formattedChange) (\(stock.formattedChangePercent))"
            } else {
                return stock.formattedChange
            }
        case .custom:
            if let customFormat = customFormat {
                var result = customFormat
                result = result.replacingOccurrences(of: "{symbol}", with: stock.symbol)
                result = result.replacingOccurrences(of: "{price}", with: stock.formattedPrice)
                result = result.replacingOccurrences(of: "{change}", with: stock.formattedChange)
                result = result.replacingOccurrences(of: "{percent}", with: stock.formattedChangePercent)
                return result
            } else {
                return "\(stock.symbol): \(stock.formattedPrice)"
            }
        }
    }
    
    private func updateMenuItems() {
        // 首先清除舊的股票菜單項
        let topItems = 2 // "更新數據" 和 分隔線
        let bottomItems = 4 // 分隔線, "設置", 分隔線, "退出"
        
        while menu.items.count > topItems + bottomItems {
            menu.removeItem(at: topItems)
        }
        
        // 添加股票項目
        for stock in stockViewModel.stocks {
            let stockItem = NSMenuItem(title: "\(stock.symbol): \(stock.formattedPrice) \(stock.formattedChange)", action: #selector(showStockDetail(_:)), keyEquivalent: "")
            stockItem.representedObject = stock.symbol
            
            // 設置股票項目的顏色
            if let attributedTitle = stockItem.attributedTitle?.mutableCopy() as? NSMutableAttributedString {
                let color: NSColor = stock.isPositive ? .green : (stock.change < 0 ? .red : .textColor)
                attributedTitle.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: attributedTitle.length))
                stockItem.attributedTitle = attributedTitle
            }
            
            menu.insertItem(stockItem, at: topItems)
        }
    }
    
    @objc private func showStockDetail(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String,
              let stock = stockViewModel.getStock(for: symbol) else {
            return
        }
        
        // 創建彈出窗口
        if popover == nil {
            popover = NSPopover()
            popover?.behavior = .transient
        }
        
        // 獲取股票歷史數據
        let historicalData = stockViewModel.historicalData[symbol]
        
        // 設置 SwiftUI 視圖
        let stockDetailView = StockDetailView(stock: stock, historicalData: historicalData)
        popover?.contentSize = NSSize(width: 320, height: 320)
        popover?.contentViewController = NSHostingController(rootView: stockDetailView)
        
        // 顯示彈出窗口
        if let button = statusItem.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    @objc private func openSettings() {
        // 獲取主視窗
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
} 