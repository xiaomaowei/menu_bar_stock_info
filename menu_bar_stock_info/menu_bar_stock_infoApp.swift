//
//  menu_bar_stock_infoApp.swift
//  menu_bar_stock_info
//
//  Created by Denis Wei on 2025/4/2.
//

import SwiftUI
import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?
    var statusItem: NSStatusItem?
    var stockViewModel = StockViewModel()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 檢查程序是否已在運行，確保只有一個實例
        if !ensureSingleInstance() {
            NSApplication.shared.terminate(self)
            return
        }
        
        // 請求通知權限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("通知權限已獲得")
            } else if let error = error {
                print("通知權限請求錯誤: \(error.localizedDescription)")
            }
        }
        
        // 初始化菜單欄控制器，並傳入共享的 StockViewModel
        menuBarController = MenuBarController(stockViewModel: stockViewModel)
    }
    
    // 檢查應用程序是否已經運行
    private func ensureSingleInstance() -> Bool {
        // 獲取當前進程的進程ID
        let pid = ProcessInfo.processInfo.processIdentifier
        
        // 獲取當前應用程序的標識符
        let bundleID = Bundle.main.bundleIdentifier ?? "com.menu-bar-stock-info"
        
        // 使用NSRunningApplication查找同一應用程序的其他運行實例
        let runningApps = NSWorkspace.shared.runningApplications
        let instances = runningApps.filter { $0.bundleIdentifier == bundleID }
        
        // 如果找到的實例數大於1（不包括當前進程），則表示已有另一個實例在運行
        if instances.count > 1 {
            // 顯示警告信息
            let alert = NSAlert()
            alert.messageText = "應用程序已在運行"
            alert.informativeText = "菜單欄股票行情已經在運行中，無法啟動多個實例。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "確定")
            alert.runModal()
            
            // 找到已存在的實例並激活它
            if let existingInstance = instances.first(where: { $0.processIdentifier != pid }) {
                existingInstance.activate(options: .activateIgnoringOtherApps)
            }
            
            return false
        }
        
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 清理資源
    }
    
    func activateApp() {
        if #available(macOS 14.0, *) {
            // macOS 14+使用新的API
            NSApp.activate()
        } else {
            // 舊版macOS繼續使用舊API
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

@main
struct menu_bar_stock_infoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .hidden()
                .onAppear {
                    // 設置為配件模式，隱藏主視窗，只顯示菜單欄圖標
                    NSApplication.shared.setActivationPolicy(.accessory)
                    
                    // 關閉所有非菜單欄窗口
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        for window in NSApplication.shared.windows {
                            if window.title.contains("Settings") || 
                               window.title.contains("menu_bar_stock_info") {
                                window.close()
                            }
                        }
                    }
                }
        }
        // 禁用設置菜單
        .commands {
            // 禁用所有默認命令
            CommandGroup(replacing: .appSettings) { EmptyView() }
            CommandGroup(replacing: .systemServices) { EmptyView() }
        }
    }
}
