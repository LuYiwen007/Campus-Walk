//
//  CityWalkUITests.swift
//  CityWalkUITests
//
//  Created by 卢绎文 on 2025/4/25.
//

import XCTest

final class CityWalkUITests: XCTestCase {
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        app.launch()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        // 清理测试环境
    }

    func testAppLaunchAndSplashScreen() throws {
        // 验证启动画面
        XCTAssertTrue(app.staticTexts["CityWalk"].exists)
        
        // 等待启动画面消失
        let mainView = app.otherElements["MainView"]
        let exists = mainView.waitForExistence(timeout: 3.0)
        XCTAssertTrue(exists, "主界面应该在启动画面后显示")
    }
    
    func testChatInteraction() throws {
        // 等待启动画面消失
        Thread.sleep(forTimeInterval: 2.5)
        
        // 验证聊天输入框存在
        let messageTextField = app.textFields["发送消息..."]
        XCTAssertTrue(messageTextField.exists, "消息输入框应该存在")
        
        // 测试发送消息
        messageTextField.tap()
        messageTextField.typeText("你好")
        app.buttons["paperplane.fill"].tap()
        
        // 验证消息已发送
        let messageText = app.staticTexts["你好"]
        XCTAssertTrue(messageText.waitForExistence(timeout: 2.0))
        
        // 等待并验证回复
        let predicate = NSPredicate(format: "exists == true")
        let messageList = app.scrollViews.firstMatch
        expectation(for: predicate, evaluatedWith: messageList, handler: nil)
        waitForExpectations(timeout: 5.0)
    }
    
    func testMapInteraction() throws {
        // 等待启动画面消失
        Thread.sleep(forTimeInterval: 2.5)
        
        // 验证地图视图存在
        let mapView = app.maps.firstMatch
        XCTAssertTrue(mapView.exists, "地图视图应该存在")
        
        // 测试个人资料按钮
        let profileButton = app.buttons["person.circle.fill"]
        XCTAssertTrue(profileButton.exists, "个人资料按钮应该存在")
        
        // 点击个人资料按钮
        profileButton.tap()
        
        // 验证个人资料视图显示
        let profileView = app.otherElements["UserProfileView"]
        XCTAssertTrue(profileView.waitForExistence(timeout: 2.0))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
