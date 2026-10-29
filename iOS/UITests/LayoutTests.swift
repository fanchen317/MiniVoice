import XCTest

final class LayoutTests: XCTestCase {
    func testKeyboardAndSheetGestures() {
        let app = XCUIApplication(); app.launchArguments = ["--mv-ui-fixture"]
        XCUIDevice.shared.orientation = .portrait; app.launch()
        XCTAssertTrue(app.buttons["搜索音乐"].firstMatch.waitForExistence(timeout: 20))
        app.buttons["搜索音乐"].firstMatch.tap()
        let search = app.textFields["搜索音乐"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("山海")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["收起搜索"].firstMatch.isHittable)
        search.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue)
        app.buttons["收起搜索"].firstMatch.tap()
        app.buttons["打开侧边栏"].firstMatch.tap()
        app.buttons["新建歌单"].firstMatch.tap()
        let name = app.textFields["歌单名称"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("键盘测试")
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        let create = app.buttons["创建"].firstMatch
        XCTAssertTrue(create.isHittable)
        XCTAssertLessThanOrEqual(create.frame.maxY, keyboard.frame.minY, "软键盘不能遮挡歌单提交按钮")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "playlist-keyboard"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["关闭弹窗"].firstMatch.tap()
        XCTAssertTrue(app.buttons["打开侧边栏"].firstMatch.waitForExistence(timeout: 5))
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        let expand = app.buttons["展开播放条"].firstMatch
        if expand.exists { expand.tap() }
        XCTAssertTrue(app.buttons["播放队列"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["播放队列"].firstMatch.tap()
        let grip = app.buttons["向上展开或向下收起弹窗"].firstMatch
        XCTAssertTrue(grip.waitForExistence(timeout: 5), app.debugDescription)
        let initial = grip.frame.minY
        let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: -200))
        start.press(forDuration: 0.1, thenDragTo: end)
        let expanded = NSPredicate { _, _ in grip.frame.minY < initial - 30 }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: expanded, object: nil)], timeout: 5), .completed)
        let upper = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        upper.press(forDuration: 0.1, thenDragTo: upper.withOffset(CGVector(dx: 0, dy: 200)))
        XCTAssertTrue(app.buttons["关闭弹窗"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["关闭弹窗"].firstMatch.tap()
    }

    func testDiagnosticsSystemExporter() {
        let app = XCUIApplication(); app.launchArguments = ["--mv-ui-fixture"]
        XCUIDevice.shared.orientation = .portrait; app.launch()
        XCTAssertTrue(app.buttons["打开侧边栏"].firstMatch.waitForExistence(timeout: 20))
        app.buttons["打开侧边栏"].firstMatch.tap(); app.buttons["设置"].firstMatch.tap()
        let export = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "导出诊断报告")).firstMatch
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        let dialog = app.otherElements.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "设置", "网页对话框")).firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 5))
        func visible() -> Bool { export.isHittable && export.frame.minY >= dialog.frame.minY + 90 && export.frame.maxY <= dialog.frame.maxY - 8 }
        for _ in 0..<10 {
            if visible() { break }
            let start = dialog.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            start.press(forDuration: 0.05, thenDragTo: dialog.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
        }
        XCTAssertTrue(visible(), "导出操作必须在弹窗实际可见区域内"); export.tap()
        let cancel = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "取消")).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), app.debugDescription)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "diagnostics-system-exporter"; screenshot.lifetime = .keepAlways; add(screenshot)
        cancel.tap()
        XCTAssertTrue(app.buttons["关闭弹窗"].firstMatch.waitForExistence(timeout: 5))
    }

    func testLandscapeViewport() {
        let app = XCUIApplication(); app.launchArguments = ["--mv-ui-fixture"]
        XCUIDevice.shared.orientation = .landscapeLeft; app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["打开侧边栏"].firstMatch.waitForExistence(timeout: 20))
        let web = app.webViews.firstMatch
        XCTAssertGreaterThan(web.frame.width, web.frame.height)
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = "landscape-system-screen"; image.lifetime = .keepAlways; add(image)
    }

    func testTouchAndRotationMatrix() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--mv-ui-fixture"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        let sidebar = app.buttons["打开侧边栏"].firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 30), app.debugDescription)
        sidebar.tap()
        let settings = app.buttons["设置"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.switches["浅色模式"].firstMatch.waitForExistence(timeout: 10), app.debugDescription)
        func rotate(_ orientation: UIDeviceOrientation) {
            XCUIDevice.shared.orientation = orientation
            let landscape = orientation == .landscapeLeft
            let settled = NSPredicate { _, _ in landscape ? app.frame.width > app.frame.height : app.frame.height > app.frame.width }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 8), .completed)
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        }
        for style in ["简易", "音乐库", "音乐墙"] {
            rotate(.portrait)
            app.switches[style].firstMatch.tap()
            for theme in ["浅色模式", "深色模式"] {
                rotate(.portrait)
                app.switches[theme].firstMatch.tap()
                for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
                    rotate(orientation)
                    // Wait on a visible control after system rotation; no DOM events are synthesized.
                    let close = app.buttons["关闭弹窗"].firstMatch
                    XCTAssertTrue(close.waitForExistence(timeout: 5))
                    XCTAssertTrue(close.isHittable, "\(style)/\(theme)/\(orientation)")
                    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                    attachment.name = "\(style)-\(theme)-\(orientation.rawValue)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                    close.tap()
                    let open = app.buttons["打开侧边栏"].firstMatch
                    XCTAssertTrue(open.waitForExistence(timeout: 5))
                    XCTAssertTrue(open.isHittable)
                    let page = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                    page.name = "page-\(style)-\(theme)-\(orientation.rawValue)"
                    page.lifetime = .keepAlways
                    add(page)
                    open.tap()
                    app.buttons["设置"].firstMatch.tap()
                    XCTAssertTrue(app.buttons["关闭弹窗"].firstMatch.waitForExistence(timeout: 5))
                }
            }
        }
        app.buttons["关闭弹窗"].firstMatch.tap()
        XCTAssertTrue(app.buttons["音乐墙设置"].firstMatch.waitForExistence(timeout: 5))
    }
}
