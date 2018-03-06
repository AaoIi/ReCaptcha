//
//  ReCaptcha+Rx__Tests.swift
//  ReCaptcha
//
//  Created by Flávio Caetano on 13/04/17.
//  Copyright © 2018 ReCaptcha. All rights reserved.
//

@testable import ReCaptcha

import RxBlocking
import RxCocoa
import RxSwift
import XCTest


class ReCaptcha_Rx__Tests: XCTestCase {

    fileprivate var apiKey: String!
    fileprivate var presenterView: UIView!

    override func setUp() {
        super.setUp()

        presenterView = UIApplication.shared.keyWindow!
        apiKey = String(arc4random())
    }

    override func tearDown() {
        presenterView = nil
        apiKey = nil

        super.tearDown()
    }


    func test__Validate__Token() {
        let manager = ReCaptchaWebViewManager(messageBody: "{token: key}", apiKey: apiKey)
        manager.configureWebView { _ in
            XCTFail("should not ask to configure the webview")
        }

        do {
            // Validate
            let result = try manager.rx.validate(on: presenterView)
                .toBlocking()
                .single()

            // Verify
            XCTAssertEqual(result, apiKey)
        }
        catch let error {
            XCTFail(error.localizedDescription)
        }
    }


    func test__Validate__Show_ReCaptcha() {
        let manager = ReCaptchaWebViewManager(messageBody: "{action: \"showReCaptcha\"}", apiKey: apiKey)
        var didConfigureWebView = false

        manager.configureWebView { _ in
            didConfigureWebView = true
        }

        do {
            // Validate
            _ = try manager.rx.validate(on: presenterView)
                .timeout(2, scheduler: MainScheduler.instance)
                .toBlocking()
                .single()

            XCTFail("should have thrown exception")
        }
        catch let error {
            XCTAssertEqual(String(describing: error), RxError.timeout.debugDescription)
            XCTAssertTrue(didConfigureWebView)
        }
    }


    func test__Validate__Error() {
        let manager = ReCaptchaWebViewManager(messageBody: "\"foobar\"", apiKey: apiKey)
        manager.configureWebView { _ in
            XCTFail("should not ask to configure the webview")
        }

        do {
            // Validate
            _ = try manager.rx.validate(on: presenterView, resetOnError: false)
                .toBlocking()
                .single()
                
            XCTFail("should have thrown exception")
        }
        catch let error {
            XCTAssertEqual(error as? ReCaptchaError, .wrongMessageFormat)
        }
    }

    // MARK: Dispose

    func test__Dispose() {
        let exp = expectation(description: "stop loading")

        // Stop
        let manager = ReCaptchaWebViewManager(messageBody: "{action: \"showReCaptcha\"}")
        manager.configureWebView { _ in
            XCTFail("should not ask to configure the webview")
        }

        let disposable = manager.rx.validate(on: presenterView)
            .do(onDispose: exp.fulfill)
            .subscribe { _ in
                XCTFail("should not validate")
            }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            disposable.dispose()
        }

        waitForExpectations(timeout: 10)
    }

    // MARK: Reset

    func test__Reset() {
        // Validate
        let manager = ReCaptchaWebViewManager(messageBody: "{token: key}", apiKey: apiKey, shouldFail: true)
        manager.configureWebView { _ in
            XCTFail("should not ask to configure the webview")
        }

        do {
            // Error
            _ = try manager.rx.validate(on: presenterView, resetOnError: false)
                .toBlocking()
                .single()
        }
        catch let error {
            XCTAssertEqual(error as? ReCaptchaError, .wrongMessageFormat)

            // Resets after failure
            _ = Observable<Void>.just(())
                .bind(to: manager.rx.reset)
        }

        do {
            // Resets and tries again
            let result = try manager.rx.validate(on: presenterView, resetOnError: false)
                .toBlocking()
                .single()

            XCTAssertEqual(result, apiKey)
        }
        catch let error {
            XCTFail(error.localizedDescription)
        }
    }

    func test__Validate__Reset_On_Error() {
        // Validate
        let manager = ReCaptchaWebViewManager(messageBody: "{token: key}", apiKey: apiKey, shouldFail: true)
        manager.configureWebView { _ in
            XCTFail("should not ask to configure the webview")
        }

        do {
            // Error
            let result = try manager.rx.validate(on: presenterView, resetOnError: true)
                .toBlocking()
                .single()

            XCTAssertEqual(result, apiKey)
        }
        catch let error {
            XCTFail(error.localizedDescription)
        }
    }
}