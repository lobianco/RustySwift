//
//  AppDelegate.swift
//  RustySwift
//
//  Created by Anthony on 10/25/19.
//  Copyright © 2019 Planet 4. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        self.window = UIWindow.init(frame: UIScreen.main.bounds)
        self.window?.rootViewController = ViewController();
        self.window?.makeKeyAndVisible()
        
        return true
    }
    
}
