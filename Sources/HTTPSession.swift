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

public enum HTTPSessionError: Error, CustomStringConvertible {
    case data(Error)
    case file(Error)
    case http(HTTPURLResponse, Data)
    case invalidDownloadURL(URL)
    case noResponse
    case task(Error)

    public var description: String {
        switch self {
        case .data(let error):
            return error.localizedDescription

        case .file(let error):
            return error.localizedDescription

        case .http(let response, let data):
            let text: String
            if let code = HTTPStatusCode(rawValue: response.statusCode) {
                text = code.text
            } else {
                text = "Unknown"
            }
            return "\(response.statusCode) \(text) (\(data.count) bytes)"

        case .invalidDownloadURL(let url):
            return "Invalid download URL: \(url.absoluteString)"

        case .noResponse:
            return "No response"

        case .task(let error):
            return error.localizedDescription
        }
    }
}

public enum HTTPMethod: String {
    case get    = "GET"
    case head   = "HEAD"
    case post   = "POST"
    case put    = "PUT"
    case delete = "DELETE"
}

public enum HTTPResult {
    case failure(HTTPSessionError)
    case success(HTTPURLResponse, Data)

    public var error: HTTPSessionError? {
        switch self {
        case .failure(let error):
            return error
        case .success(_, _):
            return nil
        }
    }

    public var response: HTTPURLResponse? {
        switch self {
        case .failure(let sessionError):
            switch sessionError {
            case .http(let response, _):
                return response
            default:
                return nil
            }
        case .success(let response, _):
            return response
        }
    }

    public var data: Data? {
        switch self {
        case .failure(let sessionError):
            switch sessionError {
            case .http(_, let data):
                return data
            default:
                return nil
            }
        case .success(_, let data):
            return data
        }
    }
}

public enum HTTPStatusCode: Int {
    case `continue`                  = 100
    case switchingProtocols          = 101

    case ok                          = 200
    case created                     = 201
    case accepted                    = 202
    case nonAuthoritativeInformation = 203
    case noContent                   = 204
    case resetContent                = 205
    case partialContent              = 206

    case multipleChoices             = 300
    case movedPermanently            = 301
    case found                       = 302
    case seeOther                    = 303
    case notModified                 = 304
    case useProxy                    = 305
    case temporaryRedirect           = 307

    case badRequest                  = 400
    case unauthorized                = 401
    case paymentRequired             = 402
    case forbidden                   = 403
    case notFound                    = 404
    case methodNotAllowed            = 405
    case notAcceptable               = 406
    case proxyAuthenticationRequired = 407
    case requestTimeout              = 408
    case conflict                    = 409
    case gone                        = 410
    case lengthRequired              = 411
    case preconditionFailed          = 412
    case payloadTooLarge             = 413
    case uriTooLong                  = 414
    case unsupportedMediaType        = 415
    case rangeNotSatisfiable         = 416
    case expectationFailed           = 417
    case upgradeRequired             = 426

    case internalServerError         = 500
    case notImplemented              = 501
    case badGateway                  = 502
    case serviceUnavailable          = 503
    case gatewayTimeout              = 504
    case httpVersionNotSupported     = 505

    public var text: String {
        switch self {
        // 1xx
        case .continue:                    return "Continue"
        case .switchingProtocols:          return "Switching Protocols"

        // 2xx
        case .ok:                          return "OK"
        case .created:                     return "Created"
        case .accepted:                    return "Accepted"
        case .nonAuthoritativeInformation: return "Non-Authoritative Information"
        case .noContent:                   return "No Content"
        case .resetContent:                return "Reset Content"
        case .partialContent:              return "Partial Content"

        // 3xx
        case .multipleChoices:             return "Multiple Choices"
        case .movedPermanently:            return "Moved Permanently"
        case .found:                       return "Found"
        case .seeOther:                    return "See Other"
        case .notModified:                 return "Not Modified"
        case .useProxy:                    return "Use Proxy"
        case .temporaryRedirect:           return "Temporary Redirect"

        // 4xx
        case .badRequest:                  return "Bad Request"
        case .unauthorized:                return "Unauthorized"
        case .paymentRequired:             return "Payment Required"
        case .forbidden:                   return "Forbidden"
        case .notFound:                    return "Not Found"
        case .methodNotAllowed:            return "Method Not Allowed"
        case .notAcceptable:               return "Not Acceptable"
        case .proxyAuthenticationRequired: return "Proxy Authentication Required"
        case .requestTimeout:              return "Request Timeout"
        case .conflict:                    return "Conflict"
        case .gone:                        return "Gone"
        case .lengthRequired:              return "Length Required"
        case .preconditionFailed:          return "Precondition Failed"
        case .payloadTooLarge:             return "Payload Too Large"
        case .uriTooLong:                  return "URI Too Long"
        case .unsupportedMediaType:        return "Unsupported Media Type"
        case .rangeNotSatisfiable:         return "Range Not Satisfiable"
        case .expectationFailed:           return "Expectation Failed"
        case .upgradeRequired:             return "Upgrade Required"

        // 5xx
        case .internalServerError:         return "Internal Server Error"
        case .notImplemented:              return "Not Implemented"
        case .badGateway:                  return "Bad Gateway"
        case .serviceUnavailable:          return "Service Unavailable"
        case .gatewayTimeout:              return "Gateway Timeout"
        case .httpVersionNotSupported:     return "HTTP Version Not Supported"
        }
    }
}

public final class HTTPSession: NSObject {

    /// Completion closure for request methods.
    public typealias ResultCompletion = (HTTPResult) -> Void

    /// Download progress closure called periodically by responses with body data.
    public typealias DownloadProgress = (_ bytesDownloaded: Int64, _ totalBytesDownloaded: Int64, _ totalBytesToDownload: Int64) -> Void

    /// Upload progress closure called periodically by requests with body data.
    public typealias UploadProgress = (_ bytesUploaded: Int64, _ totalBytesUploaded: Int64, _ totalBytesToUpload: Int64) -> Void

    /// Shared `HTTPSession` for easy access. The default is configured with `URLSessionConfiguration.default`.
    public static var shared = HTTPSession()

    /// The underlying `URLSession` used for tasks.
    public private(set) var urlSession: URLSession!

    /// If set this handler will be used for both session and task authentication challenges.
    public var authenticationChallengeHandler: ( (URLSession, URLSessionTask?, URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) )?

    /// Enable to pass responses directly to the completion handler without parsing the status code.
    /// Use this to implement custom response handling.
    public var enableResponsePassthrough: Bool = false

    /**
     Since `HTTPSession` uses the delegate methods on `URLSession`, completion and progress closures (as well as
     as other task related data) are stored in a `TaskHandler` object. This dictionary keeps track of the handlers
     using the task identifier as key.
     */
    fileprivate var taskHandlers = [Int: TaskHandler]()

    public init(configuration: URLSessionConfiguration? = nil) {
        super.init()

        let config = configuration ?? URLSessionConfiguration.default
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    deinit {
        urlSession.invalidateAndCancel()
    }

    @discardableResult
    public func get(_ request: URLRequest, body data: Data = Data(), downloadTo fileUrl: URL? = nil, uploadProgress: UploadProgress? = nil, downloadProgress: DownloadProgress? = nil, completion: @escaping ResultCompletion) -> Int {
        return send(request: request, method: HTTPMethod.get.rawValue, body: data, downloadTo: fileUrl, uploadProgress: uploadProgress, downloadProgress: downloadProgress, completion: completion)
    }

    @discardableResult
    public func head(_ request: URLRequest, body data: Data = Data(), uploadProgress: UploadProgress? = nil, completion: @escaping ResultCompletion) -> Int {
        return send(request: request, method: HTTPMethod.head.rawValue, body: data, uploadProgress: uploadProgress, completion: completion)
    }

    @discardableResult
    public func post(_ request: URLRequest, body data: Data, downloadTo fileUrl: URL? = nil, uploadProgress: UploadProgress? = nil, downloadProgress: DownloadProgress? = nil, completion: @escaping ResultCompletion) -> Int {
        return send(request: request, method: HTTPMethod.post.rawValue, body: data, downloadTo: fileUrl, uploadProgress: uploadProgress, downloadProgress: downloadProgress, completion: completion)
    }

    @discardableResult
    public func put(_ request: URLRequest, body data: Data, downloadTo fileUrl: URL? = nil, uploadProgress: UploadProgress? = nil, downloadProgress: DownloadProgress? = nil, completion: @escaping ResultCompletion) -> Int {
        return send(request: request, method: HTTPMethod.put.rawValue, body: data, downloadTo: fileUrl, uploadProgress: uploadProgress, downloadProgress: downloadProgress, completion: completion)
    }

    @discardableResult
    public func delete(_ request: URLRequest, body data: Data = Data(), downloadTo fileUrl: URL? = nil, uploadProgress: UploadProgress? = nil, downloadProgress: DownloadProgress? = nil, completion: @escaping ResultCompletion) -> Int {
        return send(request: request, method: HTTPMethod.delete.rawValue, body: data, downloadTo: fileUrl, uploadProgress: uploadProgress, downloadProgress: downloadProgress, completion: completion)
    }

    @discardableResult
    public func send(
        request: URLRequest,
        method: String = HTTPMethod.get.rawValue,
        body data: Data = Data(),
        downloadTo fileUrl: URL? = nil,
        uploadProgress: UploadProgress? = nil,
        downloadProgress: DownloadProgress? = nil,
        completion: @escaping ResultCompletion) -> Int
    {
        if let fileUrl = fileUrl {
            var invalidFileUrl = false

            if fileUrl.hasDirectoryPath {
                invalidFileUrl = true
            } else {
                // Verify parent folder of file is writeable
                let folderUrl = fileUrl.deletingLastPathComponent()
                invalidFileUrl = !FileManager.default.isWritableFile(atPath: folderUrl.path)
            }

            if invalidFileUrl {
                urlSession.delegateQueue.addOperation {
                    completion(.failure(.invalidDownloadURL(fileUrl)))
                }
                return -1
            }
        }

        var methodRequest = request
        methodRequest.httpMethod = method
        let task = urlSession.uploadTask(with: methodRequest, from: data)

        let handler = TaskHandler(completion: completion)
        handler.uploadProgress = uploadProgress
        handler.downloadProgress = downloadProgress
        handler.url = fileUrl
        taskHandlers[task.taskIdentifier] = handler
        task.resume()

        return task.taskIdentifier
    }
}

extension HTTPSession: URLSessionDelegate {
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        urlSessionOrTask(session, task: nil, didReceive: challenge, completionHandler: completionHandler)
    }
}

extension HTTPSession: URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        urlSessionOrTask(session, task: task, didReceive: challenge, completionHandler: completionHandler)
    }

    fileprivate func urlSessionOrTask(_ session: URLSession, task: URLSessionTask?, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let authHandler = authenticationChallengeHandler else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let (disposition, credential) = authHandler(session, task, challenge)
        completionHandler(disposition, credential)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let handler = taskHandlers[task.taskIdentifier], let progress = handler.uploadProgress else {
            return
        }
        progress(bytesSent, totalBytesSent, totalBytesExpectedToSend)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let handler = taskHandlers.removeValue(forKey: task.taskIdentifier) else {
            return
        }

        if let error = error {
            handler.completion(.failure(.task(error)))
            return
        }

        if let error = handler.error {
            handler.completion(.failure(error))
            return
        }

        guard let response = task.response as? HTTPURLResponse else {
            handler.completion(.failure(.noResponse))
            return
        }

        let data = handler.data ?? Data()

        if !enableResponsePassthrough && 400 ..< 600 ~= response.statusCode {
            handler.completion(.failure(.http(response, data)))
        } else {
            handler.completion(.success(response, data))
        }
    }
}

extension HTTPSession: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // The only data tasks used are upload tasks, and they are converted to download tasks so that we can track progress
        completionHandler(.becomeDownload)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        guard let handler = taskHandlers.removeValue(forKey: dataTask.taskIdentifier) else {
            return
        }
        taskHandlers[downloadTask.taskIdentifier] = handler
    }
}

extension HTTPSession: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let handler = taskHandlers[downloadTask.taskIdentifier] else {
            return
        }

        var newLocation = location

        if let fileUrl = handler.url {
            // If download URL is provided, move temp file to requested location
            do {
                let fm = FileManager.default
                try? fm.removeItem(at: fileUrl)
                try fm.moveItem(at: location, to: fileUrl)
                newLocation = fileUrl
            } catch let fileError {
                handler.error = .file(fileError)
                return
            }
        }

        // Memory map downloaded file to virtual memory so size won't be an issue for returned data.
        // If this was a temp file the mapping keeps the file reference alive.
        do {
            handler.data = try Data(contentsOf: newLocation, options: .alwaysMapped)
        } catch let dataError {
            handler.error = .data(dataError)
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let handler = taskHandlers[downloadTask.taskIdentifier], let progress = handler.downloadProgress else {
            return
        }
        progress(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
    }
}

fileprivate final class TaskHandler {
    let completion: HTTPSession.ResultCompletion
    var uploadProgress: HTTPSession.UploadProgress? = nil
    var downloadProgress: HTTPSession.DownloadProgress? = nil
    var data: Data? = nil
    var url: URL? = nil
    var error: HTTPSessionError? = nil

    init(completion: @escaping HTTPSession.ResultCompletion) {
        self.completion = completion
    }
}

extension URLSession {
    public func task(withID taskID: Int, completion: @escaping (URLSessionTask?) -> Void) {
        getAllTasks() { (allTasks) in
            let foundTask = allTasks.first(where: { $0.taskIdentifier == taskID })
            completion(foundTask)
        }
    }
}
