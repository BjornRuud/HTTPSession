# HTTPSession

A minimalistic HTTP client built on top of URLSession, written in Swift.

This framework is under heavy development and should not be used for anything yet.

## Goals

- No unnecessary abstractions. Uses URLSession, URLRequest and HTTPURLResponse.
- Progress tracking for both requests and responses.
- Support for data that doesn't fit in memory.
- Keep it simple, avoid swiss army knife syndrome. The client should handle requests, responses and data transfer both ways. That's it.
