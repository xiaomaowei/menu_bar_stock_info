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
    
    func applicationWillTerminate(_ notification: Notification) {
        // 清理資源
    }
}

@main
struct menu_bar_stock_infoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 400, height: 300) // 設置主視窗尺寸
                .onAppear {
                    // 隱藏主視窗，只顯示菜單欄圖標
                    NSApplication.shared.setActivationPolicy(.accessory)
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowResizability(.contentSize)
    }
}
