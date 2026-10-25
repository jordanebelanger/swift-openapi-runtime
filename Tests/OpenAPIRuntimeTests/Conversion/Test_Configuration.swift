//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftOpenAPIGenerator open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftOpenAPIGenerator project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftOpenAPIGenerator project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import XCTest
import HTTPTypes
@_spi(Generated) import OpenAPIRuntime

final class Test_Configuration: Test_Runtime {

    func testDateTranscoder_iso8601() throws {
        let transcoder: any DateTranscoder = .iso8601
        XCTAssertEqual(try transcoder.encode(testDate), testDateString)
        XCTAssertEqual(testDate, try transcoder.decode(testDateString))
    }

    func testDateTranscoder_iso8601WithFractionalSeconds() throws {
        let transcoder: any DateTranscoder = .iso8601WithFractionalSeconds

        // There is a small accuracy difference in the Foundation ISO8601DateFormatter
        // and the new Foundation .formatted() APIs, so the below tests take that into account
        #if FullFoundation || canImport(Darwin)
        XCTAssertEqual(try transcoder.encode(testDateWithFractionalSeconds), testDateWithFractionalSecondsString)
        #else
        XCTAssertEqual(
            try transcoder.encode(testDateWithFractionalSeconds),
            testDateWithFractionalSecondsStringNewFoundationAPIs
        )
        #endif
        XCTAssertEqual(
            testDateWithFractionalSeconds.timeIntervalSince1970,
            try transcoder.decode(testDateWithFractionalSecondsString).timeIntervalSince1970,
            accuracy: 0.00001
        )
    }

    func _testJSON(configuration: Configuration, expected: String) async throws {
        let converter = Converter(configuration: configuration)
        var headerFields: HTTPFields = [:]
        let body = try converter.setResponseBodyAsJSON(
            testPetWithPath,
            headerFields: &headerFields,
            contentType: "application/json"
        )
        let data = try await Data(collecting: body, upTo: 1024)
        XCTAssertEqualStringifiedData(data, expected)
    }

    func testJSONEncodingOptions_default() async throws {
        try await _testJSON(configuration: Configuration(), expected: testPetWithPathPrettifiedWithEscapingSlashes)
    }

    func testJSONEncodingOptions_empty() async throws {
        try await _testJSON(
            configuration: Configuration(jsonEncodingOptions: [
                .sortedKeys  // without sorted keys, this test would be unreliable
            ]),
            expected: testPetWithPathMinifiedWithEscapingSlashes
        )
    }

    func testJSONEncodingOptions_prettyWithoutEscapingSlashes() async throws {
        try await _testJSON(
            configuration: Configuration(jsonEncodingOptions: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
            expected: testPetWithPathPrettifiedWithoutEscapingSlashes
        )
    }

    func _testHeaderField(configuration: Configuration, value: String, expected: String) throws {
        let converter = Converter(configuration: configuration)
        var headerFields: HTTPFields = [:]
        try converter.setHeaderFieldAsURI(in: &headerFields, name: "foo", value: value)
        XCTAssertEqual(headerFields, [.foo: expected])
        let decodedValue = try converter.getRequiredHeaderFieldAsURI(in: headerFields, name: "foo", as: String.self)
        XCTAssertEqual(decodedValue, value)
    }

    func testHeaderFieldEncoding_default() throws {
        try _testHeaderField(
            configuration: Configuration(),
            value: "session=a%20b; Path=/",
            expected: "session%3Da%2520b%3B%20Path%3D%2F"
        )
    }

    func testHeaderFieldEncoding_unencoded() throws {
        try _testHeaderField(
            configuration: Configuration(headerFieldEncoding: .unencoded),
            value: "session=a%20b; Path=/",
            expected: "session=a%20b; Path=/"
        )
    }

    func testHeaderFieldEncoding_unencodedDoesNotAffectPathAndQuery() throws {
        let converter = Converter(configuration: Configuration(headerFieldEncoding: .unencoded))
        XCTAssertEqual(try converter.renderedPath(template: "/items/{}", parameters: ["a/b c"]), "/items/a%2Fb%20c")
        var request = HTTPRequest(soar_path: "/items", method: .get)
        try converter.setQueryItemAsURI(in: &request, style: nil, explode: nil, name: "q", value: "a=b c")
        XCTAssertEqual(request.path, "/items?q=a%3Db%20c")
        let value: String = try converter.getRequiredQueryItemAsURI(
            in: "q=a%3Db%20c",
            style: nil,
            explode: nil,
            name: "q",
            as: String.self
        )
        XCTAssertEqual(value, "a=b c")
    }
}
