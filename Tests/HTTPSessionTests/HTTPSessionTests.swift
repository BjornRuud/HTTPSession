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

        http.HEAD["/hello"] = { request in
            return .ok(.text("hello"))
        }

        http.POST["/post"] = { r in
            let data = Data(bytes: r.body)
            var response = String(data: data, encoding: .utf8) ?? ""
            return HttpResponse.ok(.text(response))
        }

        http.PUT["/put"] = { r in
            let data = Data(bytes: r.body)
            var response = String(data: data, encoding: .utf8) ?? ""
            return HttpResponse.ok(.text(response))
        }

        http.DELETE["/delete"] = { r in
            return HttpResponse.ok(.text("deleted"))
        }

        return http
    }()

    let basePath = "http://127.0.0.1:8080"

    override func setUp() {
        try? server.start()
    }

    override func tearDown() {
        server.stop()
    }

    func cacheURL(for path: String) -> URL {
        let url = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        return url.appendingPathComponent(path)
    }

    func urlFor(path: String) -> URL {
        return URL(string: basePath + path)!
    }

    func testServerTimeout() {
        let expect = expectation(description: "timeout")
        let url = URL(string: "http://1.2.3.4:8080")!
        let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 1)

        session.get(request) { result in
            guard let _ = result.error else {
                XCTFail()
                return
            }
            expect.fulfill()
        }
        waitForExpectations(timeout: 4)
    }

    func testServerFail() {
        let expect = expectation(description: "fail")
        let url = urlFor(path: "/fail")
        let request = URLRequest(url: url)

        session.get(request) { result in
            guard let response = result.response else {
                XCTFail()
                return
            }
            XCTAssertEqual(response.statusCode, 404)
            expect.fulfill()
        }
        waitForExpectations(timeout: 4)
    }

    func testGet() {
        let expect = expectation(description: "hello")
        let url = urlFor(path: "/hello")
        let request = URLRequest(url: url)

        session.get(request) { result in
            if let error = result.error {
                XCTFail("\(error)")
                return
            }
            guard let data = result.data else {
                XCTFail()
                return
            }
            let text = String(data: data, encoding: .utf8)!
            XCTAssertEqual(text, "hello")
            expect.fulfill()
        }
        waitForExpectations(timeout: 4)
    }

    func testHead() {
        let expect = expectation(description: "hello")
        let url = urlFor(path: "/hello")
        let request = URLRequest(url: url)

        session.head(request) { result in
            if let error = result.error {
                XCTFail("\(error)")
                return
            }
            guard let data = result.data else {
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
        let body = "fooBar".data(using: .utf8)!

        session.post(request, body: body) { (result) in
            if let error = result.error {
                XCTFail("\(error)")
                return
            }
            guard let data = result.data else {
                XCTFail()
                return
            }
            let text = String(data: data, encoding: .utf8)!
            XCTAssertEqual(text, "fooBar")
            expect.fulfill()
        }
        waitForExpectations(timeout: 4)
    }

    func testPut() {
        let expect = expectation(description: "put")
        let url = urlFor(path: "/put")
        let request = URLRequest(url: url)
        let body = "fooBar".data(using: .utf8)!

        session.put(request, body: body) { (result) in
            if let error = result.error {
                XCTFail("\(error)")
                return
            }
            guard let data = result.data else {
                XCTFail()
                return
            }
            let text = String(data: data, encoding: .utf8)!
            XCTAssertEqual(text, "fooBar")
            expect.fulfill()
        }
        waitForExpectations(timeout: 4)
    }

    func testDelete() {
        let expect = expectation(description: "delete")
        let url = urlFor(path: "/delete")
        let request = URLRequest(url: url)

        session.delete(request) { (result) in
            if let error = result.error {
                XCTFail("\(error)")
                return
            }
            guard let data = result.data else {
                XCTFail()
                return
            }
            let text = String(data: data, encoding: .utf8)!
            XCTAssertEqual(text, "deleted")
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

        session.post(request, body: upData, uploadProgress: {
            (bytesUploaded, totalBytesUploaded, totalBytesToUpload) in
            upCount = totalBytesUploaded
            upTotal = totalBytesToUpload
        }, downloadProgress: {
            (bytesDownloaded, totalBytesDownloaded, totalBytesToDownload) in
            downCount = totalBytesDownloaded
            downTotal = totalBytesToDownload
        }) { (result) in
            if let error = result.error {
                XCTFail("\(error)")
                return
            }
            guard let data = result.data else {
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

    func testDownloadProgress() {
        let expect = expectation(description: "downloadProgress")
        var downCount: Int64 = 0
        var downTotal: Int64 = 0

        let url = urlFor(path: "/hello")
        let request = URLRequest(url: url)

        session.get(request, downloadProgress: { (bytesDownloaded, totalBytesDownloaded, totalBytesToDownload) in
            downCount = totalBytesDownloaded
            downTotal = totalBytesToDownload
        }, completion: { result in
            if let error = result.error {
                XCTFail("\(error)")
                return
            }
            guard let data = result.data, data.count > 0 else {
                XCTFail()
                return
            }
            XCTAssertEqual(downCount, downTotal)
            XCTAssertEqual(downCount, Int64(data.count))
            expect.fulfill()
        })
        waitForExpectations(timeout: 4)
    }

    func testFileDownload() {
        let expect = expectation(description: "fileDownload")

        let url = urlFor(path: "/hello")
        let request = URLRequest(url: url)

        let fileUrl = cacheURL(for: "hello.txt")

        session.get(request, downloadTo: fileUrl) { result in
            if let error = result.error {
                XCTFail("\(error)")
                return
            }
            guard let data = result.data, data.count > 0 else {
                XCTFail()
                return
            }
            let fileData = try! Data(contentsOf: fileUrl)
            XCTAssertEqual(data, fileData)
            expect.fulfill()
        }
        waitForExpectations(timeout: 4)
    }

    func testInvalidFileURL() {
        let expect = expectation(description: "fileDownload")

        let url = urlFor(path: "/hello")
        let request = URLRequest(url: url)

        let fileUrl = cacheURL(for: "foo/")

        session.get(request, downloadTo: fileUrl) { result in
            if let error = result.error {
                switch error {
                case .invalidDownloadURL(_):
                    expect.fulfill()
                default:
                    XCTFail()
                }
            } else {
                XCTFail()
            }
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
