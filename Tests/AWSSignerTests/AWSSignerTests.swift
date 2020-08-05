//===----------------------------------------------------------------------===//
//
// This source file is part of the AWSSDKSwift open source project
//
// Copyright (c) 2017-2020 the AWSSDKSwift project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of AWSSDKSwift project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import AWSSignerV4
import NIO
import XCTest

@propertyWrapper struct EnvironmentVariable<Value: LosslessStringConvertible> {
    var defaultValue: Value
    var variableName: String

    public init(_ variableName: String, default: Value) {
        self.defaultValue = `default`
        self.variableName = variableName
    }

    public var wrappedValue: Value {
        guard let value = ProcessInfo.processInfo.environment[variableName] else { return self.defaultValue }
        return Value(value) ?? self.defaultValue
    }
}

final class AWSSignerTests: XCTestCase {
    @EnvironmentVariable("ENABLE_TIMING_TESTS", default: true) static var enableTimingTests: Bool
    let credentials: Credential = StaticCredential(accessKeyId: "MYACCESSKEY", secretAccessKey: "MYSECRETACCESSKEY")
    let credentialsWithSessionKey: Credential = StaticCredential(accessKeyId: "MYACCESSKEY", secretAccessKey: "MYSECRETACCESSKEY", sessionToken: "MYSESSIONTOKEN")

    func testSignGetHeaders() {
        let signer = AWSSigner(credentials: credentials, name: "glacier", region: "us-east-1")
        let headers = signer.signHeaders(url: URL(string: "https://glacier.us-east-1.amazonaws.com/-/vaults")!, method: .GET, headers: ["x-amz-glacier-version": "2012-06-01"], date: Date(timeIntervalSinceReferenceDate: 2_000_000))
        XCTAssertEqual(headers["Authorization"].first, "AWS4-HMAC-SHA256 Credential=MYACCESSKEY/20010124/us-east-1/glacier/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date;x-amz-glacier-version, Signature=acfa9b03fca6b098d7b88bfd9bbdb4687f5b34e944a9c6ed9f4814c1b0b06d62")
    }

    func testSignPutHeaders() {
        let signer = AWSSigner(credentials: credentials, name: "sns", region: "eu-west-1")
        let headers = signer.signHeaders(url: URL(string: "https://sns.eu-west-1.amazonaws.com/")!, method: .POST, headers: ["Content-Type": "application/x-www-form-urlencoded; charset=utf-8"], body: .string("Action=ListTopics&Version=2010-03-31"), date: Date(timeIntervalSinceReferenceDate: 200))
        XCTAssertEqual(headers["Authorization"].first, "AWS4-HMAC-SHA256 Credential=MYACCESSKEY/20010101/eu-west-1/sns/aws4_request, SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date, Signature=1d29943055a8ad094239e8de06082100f2426ebbb2c6a5bbcbb04c63e6a3f274")
    }

    func testSignS3GetURL() {
        let signer = AWSSigner(credentials: credentials, name: "s3", region: "us-east-1")
        let url = signer.signURL(url: URL(string: "https://s3.us-east-1.amazonaws.com/")!, method: .GET, date: Date(timeIntervalSinceReferenceDate: 100_000))
        XCTAssertEqual(url.absoluteString, "https://s3.us-east-1.amazonaws.com/?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=MYACCESSKEY%2F20010102%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20010102T034640Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host&X-Amz-Signature=27957103c8bfdff3560372b1d85976ed29c944f34295eca2d4fdac7fc02c375a")
    }

    func testSignS3GetWithQueryURL() {
        let signer = AWSSigner(credentials: credentials, name: "s3", region: "us-east-1")
        let url = signer.signURL(url: URL(string: "https://s3.us-east-1.amazonaws.com/testFile?versionId=1")!, method: .GET, date: Date(timeIntervalSinceReferenceDate: 100_000))
        XCTAssertEqual(url.absoluteString, "https://s3.us-east-1.amazonaws.com/testFile?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=MYACCESSKEY%2F20010102%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20010102T034640Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host&versionId=1&X-Amz-Signature=22678dbcdbbc468c306757c8abd021e093e588e4eba7d0d0da9b92717bbcc1b0")
    }

    func testSignS3PutURL() {
        let signer = AWSSigner(credentials: credentialsWithSessionKey, name: "s3", region: "eu-west-1")
        let url = signer.signURL(url: URL(string: "https://test-bucket.s3.amazonaws.com/test-put.txt")!, method: .PUT, body: .string("Testing signed URLs"), date: Date(timeIntervalSinceReferenceDate: 100_000))
        XCTAssertEqual(url.absoluteString, "https://test-bucket.s3.amazonaws.com/test-put.txt?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=MYACCESSKEY%2F20010102%2Feu-west-1%2Fs3%2Faws4_request&X-Amz-Date=20010102T034640Z&X-Amz-Expires=86400&X-Amz-Security-Token=MYSESSIONTOKEN&X-Amz-SignedHeaders=host&X-Amz-Signature=969dfbc450089f34f5b430611b18def1701c72c9e7e1608142051a898094227e")
    }

    func testBodyData() {
        let string = "testing, testing, 1,2,1,2"
        let data = string.data(using: .utf8)!
        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)

        let signer = AWSSigner(credentials: credentials, name: "sns", region: "eu-west-1")
        let headers1 = signer.signHeaders(url: URL(string: "https://sns.eu-west-1.amazonaws.com/")!, method: .POST, body: .string(string), date: Date(timeIntervalSinceReferenceDate: 0))
        let headers2 = signer.signHeaders(url: URL(string: "https://sns.eu-west-1.amazonaws.com/")!, method: .POST, body: .data(data), date: Date(timeIntervalSinceReferenceDate: 0))
        let headers3 = signer.signHeaders(url: URL(string: "https://sns.eu-west-1.amazonaws.com/")!, method: .POST, body: .byteBuffer(buffer), date: Date(timeIntervalSinceReferenceDate: 0))

        XCTAssertNotNil(headers1["Authorization"].first)
        XCTAssertEqual(headers1["Authorization"].first, headers2["Authorization"].first)
        XCTAssertEqual(headers2["Authorization"].first, headers3["Authorization"].first)
    }

    func testPerformanceSignedURL() {
        guard Self.enableTimingTests == true else { return }

        let signer = AWSSigner(credentials: credentials, name: "s3", region: "eu-west-1")

        measure {
            for _ in 0..<1000 {
                _ = signer.signURL(url: URL(string: "https://test-bucket.s3.amazonaws.com/test-put.txt")!, method: .GET)
            }
        }
    }

    func testPerformanceSignedHeaders() {
        guard Self.enableTimingTests == true else { return }

        let string = "testing, testing, 1,2,1,2"
        let signer = AWSSigner(credentials: credentials, name: "s3", region: "eu-west-1")

        measure {
            for _ in 0..<1000 {
                _ = signer.signHeaders(url: URL(string: "https://test-bucket.s3.amazonaws.com/test-put.txt")!, method: .GET, headers: ["Content-Type": "application/x-www-form-urlencoded; charset=utf-8"], body: .string(string))
            }
        }
    }
}
