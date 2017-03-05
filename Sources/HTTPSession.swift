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
    case invalidDownloadURL(URL)
    case invalidStatusCode(HTTPURLResponse)
    case noResponse
    case noTemporaryDownloadURL
}

public enum HTTPMethod: String {
    case GET
    case HEAD
    case POST
    case PUT
    case DELETE
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
        default:
            return nil
        }
    }

    public func response() -> HTTPURLResponse? {
        switch self {
        case .success(_, let response):
            return response
        default:
            return nil
        }
    }

    public func data() -> Data? {
        switch self {
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
        default:
            return nil
        }
    }

    public func url() -> URL? {
        switch self {
        case .success(let type, _):
            switch type {
            case .data(_):
                return nil
            case .url(let url):
                return url
            }
        default:
            return nil
        }
    }
}

public final class HTTPSession: NSObject {
    public typealias ResultCompletion = (HTTPResult) -> Void

    public typealias DownloadProgress = (_ bytesDownloaded: Int64, _ totalBytesDownloaded: Int64, _ totalBytesToDownload: Int64) -> Void

    public typealias UploadProgress = (_ bytesUploaded: Int64, _ totalBytesUploaded: Int64, _ totalBytesToUpload: Int64) -> Void

    public static var shared = HTTPSession()

    public private(set) var session: URLSession! = nil

    fileprivate var taskHandlers = [Int: TaskHandler]()

    public init(config: URLSessionConfiguration? = nil) {
        super.init()

        let config = config ?? URLSessionConfiguration.default
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    @discardableResult
    public func get(_ url: URL, downloadTo fileUrl: URL? = nil, downloadProgress: DownloadProgress? = nil, completion: @escaping ResultCompletion) -> URLSessionTask {
        let request = URLRequest(url: url)
        return get(request, downloadTo: fileUrl, downloadProgress: downloadProgress, completion: completion)
    }

    @discardableResult
    public func get(_ request: URLRequest, downloadTo fileUrl: URL? = nil, downloadProgress: DownloadProgress? = nil, completion: @escaping ResultCompletion) -> URLSessionTask {
        var req = request
        req.httpMethod = HTTPMethod.GET.rawValue

        return sendDownloadTask(request: req, downloadTo: fileUrl, downloadProgress: downloadProgress, completion: completion)
    }

    @discardableResult
    public func head(_ url: URL, completion: @escaping ResultCompletion) -> URLSessionTask {
        let request = URLRequest(url: url)
        return head(request, completion: completion)
    }

    @discardableResult
    public func head(_ request: URLRequest, completion: @escaping ResultCompletion) -> URLSessionTask {
        var req = request
        req.httpMethod = HTTPMethod.HEAD.rawValue

        return sendDownloadTask(request: req, downloadTo: nil, downloadProgress: nil, completion: completion)
    }
    
    @discardableResult
    private func sendDownloadTask(
        request: URLRequest,
        downloadTo fileUrl: URL? = nil,
        downloadProgress: DownloadProgress? = nil,
        completion: @escaping ResultCompletion) -> URLSessionDownloadTask
    {
        let task = session.downloadTask(with: request)

        let handler = TaskHandler(completion: completion)
        handler.downloadProgress = downloadProgress
        handler.url = fileUrl
        taskHandlers[task.taskIdentifier] = handler
        task.resume()

        return task
    }

    @discardableResult
    private func sendUploadTask(
        request: URLRequest,
        from data: Data,
        uploadProgress: UploadProgress? = nil,
        downloadProgress: DownloadProgress? = nil,
        completion: @escaping ResultCompletion) -> URLSessionUploadTask
    {
        let task = session.uploadTask(with: request, from: data)

        let handler = TaskHandler(completion: completion)
        handler.uploadProgress = uploadProgress
        handler.downloadProgress = downloadProgress
        taskHandlers[task.taskIdentifier] = handler
        task.resume()

        return task
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
            let fm = FileManager.default
            do {
                try fm.moveItem(at: location, to: fileUrl)
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
