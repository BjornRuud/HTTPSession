# HTTPSession

A minimalistic HTTP client written in Swift, built on top of URLSession.

Yet another HTTP client? Why? Because I couldn't find one written in Swift that had these features:

- No unnecessary abstractions. Uses URLSession, URLRequest and HTTPURLResponse.
- Progress tracking for both requests and responses.
- Support for large files.
- Minimalistic and single-purpose. The client should handle HTTP requests, responses and data transfer both ways. That's it.


## Installation

### Manual

The entire client is a single file. Either add the `HTTPSession.swift` file to your project, or add the HTTPSession project file to your project and set HTTPSession as a build dependency under `Target Settings -> Build Phases -> Target Dependencies`.

### Carthage

Add to your Cartfile:

```
github "BjornRuud/HTTPSession"
```

### Cocoapods

The pod won't be available in the CocoaPods repository until it has matured a bit more. Install it using a repository reference in your Podfile:

```
pod 'HTTPSession', :git => 'https://github.com/BjornRuud/HTTPSession.git'
```


## Usage

### Simple download request

```swift
let url = URL(string: "http://storage.com/file")!
let request = URLRequest(url: url)

session.get(request) { result in
    switch result {
    case .failure(let error, let response, let data):
        // Handle failure
    }
    case .success(let response, let data):
        // Handle success
    }

    // Or use the convenience methods on HTTPResult

    if let error = result.error() {
        // Failed!
        return
    }

    guard let response = result.response(), let data = result.data() else {
        return
    }

    // Handle response and data
}
```

### Download with progress

```swift
let url = URL(string: "http://storage.com/file")!
let request = URLRequest(url: url)

session.get(request, downloadProgress: {
    (bytesDownloaded, totalBytesDownloaded, totalBytesToDownload) in

    // Report progress

}) { result in
    switch result {
    case .failure(let error, let response, let data):
        // Handle failure
    }
    case .success(let response, let data):
        // Handle success
    }
}
```

### Download to file

```swift
let fileDestination = URL(string: "file://path/to/file")!
let url = URL(string: "http://storage.com/file")!
let request = URLRequest(url: url)

session.get(request, downloadTo: fileDestination) { result in
    switch result {
    case .failure(let error, let response, let data):
        // Handle failure
    }
    case .success(let response, let data):
        // Capture the file URL in the closure if you want to use it here.
        // The response data is always mapped to virtual memory so a data object is always returned.
    }
}
```

### Upload with progress

```swift
let someFile = URL(string: "file://path/to/file")!
// Map data to virtual memory in case of large file
guard let data = try? Data(contentsOf: someFile, options: .alwaysMapped) else {
    return
}
let url = URL(string: "http://storage.com/file")!
let request = URLRequest(url: url)

session.post(request, body: data, uploadProgress: {
    (bytesUploaded, totalBytesUploaded, totalBytesToUpload) in

    // Report progress

}) { result in
    switch result {
    case .failure(let error, let response, let data):
        // Handle failure
    }
    case .success(let response, let data):
        // Handle success
    }
}
```
