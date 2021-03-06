//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2017-2020 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AsyncHTTPClient
import NIO
@testable import SotoCore
import SotoTestUtils
import SotoXML
import XCTest

class STSAssumeRoleTests: XCTestCase {
    func testInternalSTSAssumeRoleProvider() throws {
        let credentials = STSCredentials(
            accessKeyId: "STSACCESSKEYID",
            expiration: Date(timeIntervalSince1970: 87_387_346),
            secretAccessKey: "STSSECRETACCESSKEY",
            sessionToken: "STSSESSIONTOKEN"
        )
        let testServer = AWSTestServer(serviceProtocol: .xml)
        defer { XCTAssertNoThrow(try testServer.stop()) }
        let client = AWSClient(
            credentialProvider: .internalSTSAssumeRole(
                request: .init(roleArn: "arn:aws:iam::000000000000:role/test-sts-assume-role", roleSessionName: "testInternalSTSAssumeRoleProvider"),
                credentialProvider: .empty,
                region: .useast1,
                endpoint: testServer.address
            ),
            httpClientProvider: .createNew,
            logger: TestEnvironment.logger
        )
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        XCTAssertNoThrow(try testServer.processRaw { _ in
            let output = STSAssumeRoleResponse(credentials: credentials)
            let xml = try XMLEncoder().encode(output)
            let byteBuffer = ByteBufferAllocator().buffer(string: xml.xmlString)
            let response = AWSTestServer.Response(httpStatus: .ok, headers: [:], body: byteBuffer)
            return .result(response)
        })
        var result: Credential?
        XCTAssertNoThrow(result = try client.credentialProvider.getCredential(on: client.eventLoopGroup.next(), logger: AWSClient.loggingDisabled).wait())
        let stsCredentials = result as? STSCredentials
        XCTAssertEqual(stsCredentials?.accessKeyId, credentials.accessKeyId)
        XCTAssertEqual(stsCredentials?.expiration, credentials.expiration)
        XCTAssertEqual(stsCredentials?.secretAccessKey, credentials.secretAccessKey)
        XCTAssertEqual(stsCredentials?.sessionToken, credentials.sessionToken)
    }
}

// Extend STSAssumeRoleRequest so it can be used with the AWSTestServer
extension STSAssumeRoleRequest: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let roleArn = try container.decode(String.self, forKey: .roleArn)
        let roleSessionName = try container.decode(String.self, forKey: .roleSessionName)
        self.init(roleArn: roleArn, roleSessionName: roleSessionName)
    }

    private enum CodingKeys: String, CodingKey {
        case roleArn = "RoleArn"
        case roleSessionName = "RoleSessionName"
    }
}

// Extend STSAssumeRoleResponse so it can be used with the AWSTestServer
extension STSAssumeRoleResponse: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(credentials, forKey: .credentials)
    }

    private enum CodingKeys: String, CodingKey {
        case credentials = "Credentials"
    }
}

// Extend STSCredentials so it can be used with the AWSTestServer
extension STSCredentials: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessKeyId, forKey: .accessKeyId)
        try container.encode(expiration, forKey: .expiration)
        try container.encode(secretAccessKey, forKey: .secretAccessKey)
        try container.encode(sessionToken, forKey: .sessionToken)
    }

    private enum CodingKeys: String, CodingKey {
        case accessKeyId = "AccessKeyId"
        case expiration = "Expiration"
        case secretAccessKey = "SecretAccessKey"
        case sessionToken = "SessionToken"
    }
}
