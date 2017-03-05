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

enum HTTPError: Error {
    case invalidDownloadURL(URL)
    case invalidStatusCode(HTTPURLResponse)
    case noResponse
    case noTemporaryDownloadURL
}

enum HTTPMethod: String {
    case GET
    case HEAD
    case POST
    case PUT
    case DELETE
}

enum HTTPResultDataType {
    case data(Data)
    case url(URL)
}

enum HTTPResult {
    case failure(Error)
    case success(HTTPResultDataType, HTTPURLResponse)
}

final class HTTPSession: NSObject {
    typealias ResultCompletion = (HTTPResult) -> Void

    typealias DownloadProgress = (_ bytesDownloaded: Int64, _ totalBytesDownloaded: Int64, _ totalBytesToDownload: Int64) -> Void

    typealias UploadProgress = (_ bytesUploaded: Int64, _ totalBytesUploaded: Int64, _ totalBytesToUpload: Int64) -> Void

    static var shared = HTTPSession()

    private(set) var session: URLSession! = nil

    fileprivate var taskHandlers = [Int: TaskHandler]()

    init(config: URLSessionConfiguration? = nil) {
        super.init()

        let config = config ?? URLSessionConfiguration.ephemeral
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    @discardableResult
    func get(_ request: URLRequest, downloadTo fileUrl: URL? = nil, downloadProgress: DownloadProgress? = nil, completion: @escaping ResultCompletion) -> URLSessionDownloadTask {
        var req = request
        req.httpMethod = HTTPMethod.GET.rawValue

        return sendDownloadTask(request: request, downloadTo: fileUrl, downloadProgress: downloadProgress, completion: completion)
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
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let handler = taskHandlers[task.taskIdentifier], let progress = handler.uploadProgress else {
            return
        }
        progress(bytesSent, totalBytesSent, totalBytesExpectedToSend)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
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
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // The only data tasks used are upload tasks, and they are converted to download tasks so that we can track progress
        completionHandler(.becomeDownload)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        guard let handler = taskHandlers.removeValue(forKey: dataTask.taskIdentifier) else {
            return
        }
        taskHandlers[downloadTask.taskIdentifier] = handler
    }
}

extension HTTPSession: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
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

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
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
