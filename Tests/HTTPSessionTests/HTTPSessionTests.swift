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

        http["/hello"] = { request in
            return .ok(.text("hello"))
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
            guard let (data, _) = result.data() else {
                XCTFail()
                return
            }
            let text = String(data: data, encoding: .utf8)!
            XCTAssertEqual(text, "hello")
            expect.fulfill()
        }
        waitForExpectations(timeout: 4)
    }
}

#if os(Linux)
extension HTTPSessionTests {
    static var allTests : [(String, (HTTPSessionTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
#endif
