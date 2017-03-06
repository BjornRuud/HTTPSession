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

public enum HTTPError: Error {
    case noResponse
}

public enum HTTPMethod: String {
    case get = "GET"
    case head = "HEAD"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

public enum HTTPResultDataType {
    case data(Data)
    case url(URL)
}

public enum HTTPResult {
    case failure(Error)
    case success(HTTPResultDataType, HTTPURLResponse)

    public func error() -> Error? {
        switch self {
        case .failure(let error):
            return error
        case .success(_, _):
            return nil
        }
    }

    public func response() -> HTTPURLResponse? {
        switch self {
        case .failure(_):
            return nil
        case .success(_, let response):
            return response
        }
    }

    public func data() -> Data? {
        switch self {
        case .failure(_):
            return nil
        case .success(let type, _):
            switch type {
            case .data(let data):
                return data
            case .url(let url):
                guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else {
                    return nil
                }
                return data
            }
        }
    }

    public func url() -> URL? {
        switch self {
        case .failure(_):
            return nil
        case .success(let type, _):
            switch type {
            case .data(_):
                return nil
            case .url(let url):
                return url
            }
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
    public private(set) var session: URLSession!

    /**
     Since `HTTPSession` uses the delegate methods on `URLSession`, completion and progress closures (as well as
     as other task related data) are stored in a `TaskHandler` object. This dictionary keeps track of the handlers
     using the task identifier as key.
     */
    fileprivate var taskHandlers = [Int: TaskHandler]()

    public init(configuration: URLSessionConfiguration? = nil) {
        super.init()

        let config = configuration ?? URLSessionConfiguration.default
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    deinit {
        session.invalidateAndCancel()
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
        var methodRequest = request
        methodRequest.httpMethod = method
        let task = session.uploadTask(with: methodRequest, from: data)

        let handler = TaskHandler(completion: completion)
        handler.uploadProgress = uploadProgress
        handler.downloadProgress = downloadProgress
        handler.url = fileUrl
        taskHandlers[task.taskIdentifier] = handler
        task.resume()

        return task.taskIdentifier
    }

}

extension HTTPSession: URLSessionTaskDelegate {
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
            handler.completion(.failure(error))
            return
        }

        if let error = handler.error {
            handler.completion(.failure(error))
            return
        }

        guard let response = task.response as? HTTPURLResponse else {
            handler.completion(.failure(HTTPError.noResponse))
            return
        }

        if let url = handler.url {
            handler.completion(.success(.url(url), response))
        } else {
            let data = handler.data ?? Data()
            handler.completion(.success(.data(data), response))
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

        if let fileUrl = handler.url {
            // If download URL is provided, move temp file to requested location
            do {
                try FileManager.default.moveItem(at: location, to: fileUrl)
            } catch let fileError {
                handler.error = fileError
                return
            }
        } else {
            // Memory map temp file to Data so that the file reference stays valid after the temp file is removed
            do {
                handler.data = try Data(contentsOf: location, options: .alwaysMapped)
            } catch let dataError {
                handler.error = dataError
                return
            }
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
    var error: Error? = nil

    init(completion: @escaping HTTPSession.ResultCompletion) {
        self.completion = completion
    }
}
