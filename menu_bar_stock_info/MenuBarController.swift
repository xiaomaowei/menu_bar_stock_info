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
    
    // 保存打開的窗口引用
    private var stockDetailWindows = [NSWindow]()
    private var settingsWindow: NSWindow?
    
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
        
        // 訂閱股票數據更新
        stockViewModel.$stocks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuItems()
                self?.updateStatusItemDisplay()
            }
            .store(in: &cancellables)
        
        // 立即請求更新股票數據
        DispatchQueue.main.async { [weak self] in
            self?.refreshData()
        }
        
        // 啟動更新定時器
        startUpdateTimer()
            
        // 檢查是否需要在啟動時顯示設置菜單
        let config = ConfigModel.loadFromUserDefaults()
        if config.showSettingsOnStartup {
            // 延遲一點執行，確保應用程序已完全啟動
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.openSettings()
            }
        }
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
        let refreshItem = NSMenuItem(title: "更新數據", action: #selector(refreshData), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(NSMenuItem.separator())
        
        // 股票列表區域（將動態更新）
        
        menu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(title: "設置", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
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
        // 更新狀態菜單顯示
        if let button = statusItem.button {
            button.title = "更新中..."
        }
        
        // 獲取股票數據
        stockViewModel.fetchStockData()
        
        // 更新菜單項
        DispatchQueue.main.async { [weak self] in
            self?.updateMenuItems()
        }
    }
    
    private func updateStatusItemDisplay() {
        // 獲取當前設置
        let config = ConfigModel.loadFromUserDefaults()
        
        // 如果沒有股票數據，顯示載入中
        guard !stockViewModel.stocks.isEmpty else {
            if let button = statusItem.button {
                button.title = "載入中..."
                applyTextColor(button, config: config, isLoading: true)
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
            applyTextColor(button, config: config, stock: stock)
        }
    }
    
    // 應用文字顏色到狀態欄按鈕
    private func applyTextColor(_ button: NSStatusBarButton, config: ConfigModel, stock: StockModel? = nil, isLoading: Bool = false) {
        // 根據配置決定顏色
        var textColor: NSColor
        
        switch config.textColorMode {
        case .automatic:
            if let stock = stock {
                // 根據股票漲跌設置顏色
                if stock.isPositive {
                    textColor = NSColor.green
                } else if stock.change < 0 {
                    textColor = NSColor.red
                } else {
                    textColor = NSColor.labelColor
                }
            } else {
                textColor = NSColor.labelColor
            }
        case .fixed:
            // 固定使用白色
            textColor = NSColor.white
        case .system:
            // 使用系統默認顏色
            textColor = NSColor.labelColor
        }
        
        // 應用顏色到按鈕文字
        let title = button.title
        let attributedString = NSMutableAttributedString(string: title)
        attributedString.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: title.count))
        button.attributedTitle = attributedString
    }
    
    private func formatDisplayText(stock: StockModel, format: ConfigModel.DisplayFormat, showPercent: Bool, customFormat: String?) -> String {
        let formattedPrice = String(format: "%.2f", stock.price)
        let formattedChange = stock.change >= 0 ? String(format: "+%.2f", stock.change) : String(format: "%.2f", stock.change)
        let formattedChangePercent = stock.formattedChangePercent
        
        switch format {
        case .symbolAndPrice:
            return "\(stock.symbol): \(formattedPrice)"
        case .symbolAndChange:
            if showPercent {
                return "\(stock.symbol): \(formattedChange) (\(formattedChangePercent))"
            } else {
                return "\(stock.symbol): \(formattedChange)"
            }
        case .priceOnly:
            return formattedPrice
        case .changeOnly:
            if showPercent {
                return "\(formattedChange) (\(formattedChangePercent))"
            } else {
                return formattedChange
            }
        case .custom:
            if let customFormat = customFormat {
                var result = customFormat
                result = result.replacingOccurrences(of: "{symbol}", with: stock.symbol)
                result = result.replacingOccurrences(of: "{price}", with: formattedPrice)
                result = result.replacingOccurrences(of: "{change}", with: formattedChange)
                result = result.replacingOccurrences(of: "{percent}", with: formattedChangePercent)
                return result
            } else {
                return "\(stock.symbol): \(formattedPrice)"
            }
        }
    }
    
    private func updateMenuItems() {
        // 清除現有菜單項目
        menu.removeAllItems()
        
        // 獲取當前設置
        let config = ConfigModel.loadFromUserDefaults()
        
        // 添加更新數據菜單項
        let refreshItem = NSMenuItem(title: "更新數據", action: #selector(refreshData), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(NSMenuItem.separator())
        
        // 添加所有股票項目
        for stock in stockViewModel.stocks {
            let displayText = formatDisplayText(stock: stock, format: config.displayFormat, showPercent: config.showChangePercent, customFormat: config.customFormatString)
            let menuItem = NSMenuItem(title: displayText, action: #selector(showStockDetail(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = stock.symbol
            
            // 設置股票項目顏色
            let attributedTitle = NSMutableAttributedString(string: displayText)
            let color: NSColor
            
            // 根據股票漲跌設置顏色
            if stock.isPositive {
                color = NSColor.green
            } else if stock.change < 0 {
                color = NSColor.red
            } else {
                color = NSColor.labelColor
            }
            
            attributedTitle.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: attributedTitle.length))
            menuItem.attributedTitle = attributedTitle
            
            menu.addItem(menuItem)
        }
        
        // 添加分隔線
        menu.addItem(NSMenuItem.separator())
        
        // 添加設置菜單項
        let settingsItem = NSMenuItem(title: "設置", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // 添加退出項
        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        // 綁定菜單到狀態項
        statusItem.menu = menu
    }
    
    @objc private func showStockDetail(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String,
              let stock = stockViewModel.getStock(for: symbol) else {
            return
        }
        
        // 檢查該股票的詳情視窗是否已經打開
        for existingWindow in stockDetailWindows {
            if existingWindow.title == "\(symbol) 詳情" {
                // 如果已經有此股票的視窗，則激活它並返回
                existingWindow.orderFrontRegardless()
                existingWindow.level = .floating
                activateApp()
                return
            }
        }
        
        // 獲取股票歷史數據
        let historicalData = stockViewModel.historicalData[symbol] ?? []
        
        // 創建股票詳情視圖
        let stockDetailView = StockDetailView(stock: stock, historicalData: historicalData)
        
        // 創建視圖控制器和窗口
        let viewController = NSHostingController(rootView: stockDetailView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = viewController
        window.title = "\(symbol) 詳情"
        window.center()
        window.level = .floating
        window.orderFrontRegardless()
        
        // 設置窗口關閉時的回調，清除引用
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        // 保存窗口引用
        stockDetailWindows.append(window)
        
        // 激活應用程序
        activateApp()
    }
    
    @objc private func openSettings() {
        // 如果設置窗口已經打開，則直接激活它
        if let existingWindow = settingsWindow {
            if existingWindow.isVisible {
                // 窗口已經可見，只需置頂並激活
                existingWindow.orderFrontRegardless()
                existingWindow.level = .floating
                activateApp()
                return
            } else {
                // 窗口存在但不可見，直接顯示
                existingWindow.orderFrontRegardless()
                existingWindow.level = .floating
                activateApp()
                return
            }
        }
        
        // 創建設置視圖
        let settingsViewModel = SettingsViewModel(stockViewModel: stockViewModel)
        let settingsView = SettingsView(viewModel: settingsViewModel, stockViewModel: stockViewModel)
        
        // 創建視圖控制器和窗口
        let viewController = NSHostingController(rootView: settingsView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 650),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = viewController
        window.title = "設置"
        window.level = .floating // 設置為浮動窗口，確保顯示在最上層
        
        // 獲取鼠標位置並設置窗口位置
        var mouseLocation = NSEvent.mouseLocation
        
        // 根據屏幕大小調整窗口位置，確保窗口完全可見
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
        let windowSize = window.frame.size
        
        // 確保窗口不會超出屏幕右邊界
        if mouseLocation.x + windowSize.width > screenFrame.maxX {
            mouseLocation.x = screenFrame.maxX - windowSize.width
        }
        
        // 確保窗口不會超出屏幕底部
        if mouseLocation.y - windowSize.height < screenFrame.minY {
            mouseLocation.y = screenFrame.minY + windowSize.height
        }
        
        // 設置窗口位置，將鼠標位置作為窗口的左上角
        window.setFrameTopLeftPoint(mouseLocation)
        
        // 顯示窗口，使用orderFrontRegardless確保置頂
        window.orderFrontRegardless()
        
        // 設置窗口關閉時的回調，清除引用
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        // 保存窗口引用
        settingsWindow = window
        
        // 將窗口置於前台並激活
        activateApp()
    }
    
    // 跨macOS版本兼容的應用激活方法
    private func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - NSWindowDelegate
extension MenuBarController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // 如果是設置窗口關閉
        if window == settingsWindow {
            settingsWindow = nil
            return
        }
        
        // 如果是股票詳情窗口關閉
        stockDetailWindows.removeAll { $0 == window }
    }
} 