/**
 *  HTTPSession
 *
 *  Copyright (c) 2017 Bjørn Olav Ruud. Licensed under the MIT license, as follows:
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in all
 *  copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *  SOFTWARE.
 */

import Foundation
import XCTest
import HTTPSession
import Swifter

class HTTPSessionTests: XCTestCase {
    let session = HTTPSession()

    let server: HttpServer = {
        let http = HttpServer()

        http.GET["/hello"] = { request in
            return .ok(.text("hello"))
        }

        http.POST["/post"] = { r in
            let data = Data(bytes: r.body)
            var response = String(data: data, encoding: .utf8) ?? ""
            return HttpResponse.ok(.text(response))
        }

        try? http.start()

        return http
    }()

    let basePath = "http://127.0.0.1:8080"

    func urlFor(path: String) -> URL {
        return URL(string: basePath + path)!
    }

    func testHello() {
        let expect = expectation(description: "hello")
        let url = urlFor(path: "/hello")
        session.get(url) { result in
            if let error = result.error() {
                XCTFail("\(error)")
                return
            }
            guard let data = result.data() else {
                XCTFail()
                return
            }
            let text = String(data: data, encoding: .utf8)!
            XCTAssertEqual(text, "hello")
            expect.fulfill()
        }
        waitForExpectations(timeout: 4)
    }

    func testDownloadProgress() {
        let expect = expectation(description: "downloadProgress")
        let url = urlFor(path: "/hello")
        var byteCount: Int64 = 0
        var totalBytes: Int64 = 0

        session.get(url, downloadProgress: { (bytesDownloaded, totalBytesDownloaded, totalBytesToDownload) in
            byteCount = totalBytesDownloaded
            totalBytes = totalBytesToDownload
        }, completion: { result in
            if let error = result.error() {
                XCTFail("\(error)")
                return
            }
            guard let data = result.data(), data.count > 0 else {
                XCTFail()
                return
            }
            let sameProgress = (byteCount == totalBytes)
            let sameSize = sameProgress && (totalBytes == Int64(data.count))
            XCTAssertTrue(sameSize)
            expect.fulfill()
        })
        waitForExpectations(timeout: 4)
    }

    func testHead() {
        let expect = expectation(description: "hello")
        let url = urlFor(path: "/hello")
        session.head(url) { result in
            if let error = result.error() {
                XCTFail("\(error)")
                return
            }
            guard let data = result.data() else {
                XCTFail()
                return
            }
            XCTAssertEqual(data.count, 0)
            expect.fulfill()
        }
        waitForExpectations(timeout: 4)
    }

    func testPost() {
        let expect = expectation(description: "post")
        let url = urlFor(path: "/post")
        let request = URLRequest(url: url)
        session.post(request, from: "fooBar".data(using: .utf8)!) { (result) in
            if let error = result.error() {
                XCTFail("\(error)")
                return
            }
            guard let data = result.data() else {
                XCTFail()
                return
            }
            let text = String(data: data, encoding: .utf8)!
            XCTAssertEqual(text, "fooBar")
            expect.fulfill()
        }
        waitForExpectations(timeout: 4)
    }

    func testUploadProgress() {
        let expect = expectation(description: "post")
        let url = urlFor(path: "/post")
        let request = URLRequest(url: url)

        var upCount: Int64 = 0
        var upTotal: Int64 = 0
        var downCount: Int64 = 0
        var downTotal: Int64 = 0

        let upData = "fooBar".data(using: .utf8)!

        session.post(request, from: upData, uploadProgress: {
            (bytesUploaded, totalBytesUploaded, totalBytesToUpload) in
            upCount = totalBytesUploaded
            upTotal = totalBytesToUpload
        }, downloadProgress: {
            (bytesDownloaded, totalBytesDownloaded, totalBytesToDownload) in
            downCount = totalBytesDownloaded
            downTotal = totalBytesToDownload
        }) { (result) in
            if let error = result.error() {
                XCTFail("\(error)")
                return
            }
            guard let data = result.data() else {
                XCTFail()
                return
            }
            XCTAssertEqual(upCount, upTotal)
            XCTAssertEqual(upCount, Int64(upData.count))
            XCTAssertEqual(downCount, downTotal)
            XCTAssertEqual(downCount, Int64(data.count))
            expect.fulfill()
        }
        waitForExpectations(timeout: 4)
    }
}

#if os(Linux)
extension HTTPSessionTests {
    static var allTests : [(String, (HTTPSessionTests) -> () throws -> Void)] {
        return [
            ("testHello", testHello),
            ("testDownloadProgress", testDownloadProgress),
        ]
    }
}
#endif
