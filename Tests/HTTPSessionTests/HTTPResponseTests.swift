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

class HTTPResponseTests: XCTestCase {
    let session = HTTPSession()

    let server: HttpServer = {
        let http = HttpServer()

        http.get["/500"] = { request in
            return .internalServerError
        }

        http.get["/basicAuth"] = { request in
            if let auth = request.headers["authorization"] {
                return .ok(.text(auth))
            } else {
                let statusCode = HTTPStatusCode.unauthorized
                return .raw(statusCode.rawValue, statusCode.text(), ["WWW-Authenticate": "Basic realm=\"simple\""], nil)
            }
        }

        return http
    }()

    let basePath = "http://127.0.0.1:8080"

    override func setUp() {
        try? server.start()
    }

    override func tearDown() {
        server.stop()
        session.authenticationChallengeHandler = nil
    }

    func urlFor(path: String) -> URL {
        return URL(string: basePath + path)!
    }

    func testBasicAuth() {
        let expect = expectation(description: "basic auth")
        let url = urlFor(path: "/basicAuth")
        let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 1)

        session.authenticationChallengeHandler = { (session, task, challenge) in
            let credential = URLCredential(user: "foo", password: "bar", persistence: .forSession)
            return (.useCredential, credential)
        }

        session.get(request) { result in
            if case .success(_, _) = result {
                expect.fulfill()
            } else {
                XCTFail()
            }
        }
        waitForExpectations(timeout: 4)
    }

    func testInternalServerError() {
        let expect = expectation(description: "internal server error")
        let url = urlFor(path: "/500")
        let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 1)

        session.get(request) { result in
            if case .failure(_, let response, _) = result, let failResponse = response {
                XCTAssertEqual(failResponse.statusCode, HTTPStatusCode.internalServerError.rawValue)
                expect.fulfill()
            } else {
                XCTFail()
            }
        }
        waitForExpectations(timeout: 4)
    }
}

#if os(Linux)
    extension HTTPResponseTests {
        static var allTests : [(String, (HTTPSessionTests) -> () throws -> Void)] {
            return [
                ("testBasicAuth", testBasicAuth),
                ("testInternalServerError", testInternalServerError),
            ]
        }
    }
#endif
