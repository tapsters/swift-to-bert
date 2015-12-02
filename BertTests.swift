//
//  BertTests.swift
//  Radius
//
//  Based on https://github.com/saleyn/erlb.js
//  Created by Vitaly Shutko <sokal32@gmail.com> on 11/27/15.
//  Copyright © 2015 sokal32. All rights reserved.
//

import XCTest
import Radius

class BertTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func checkEncoding(result: BertObject, data: [UInt8]) throws {
        let inversedResult = try Bert.encode(result)
        var inversetResultBytes = [UInt8](count: inversedResult.length, repeatedValue: 0)
        inversedResult.getBytes(&inversetResultBytes, length: inversedResult.length)
        XCTAssertEqual(inversetResultBytes, data)
    }

    func testAtom() {
        let data: [UInt8] = [131,100,0,4,99,104,97,116]
        let result: BertAtom
        do {
            result = try Bert.decode(NSData(bytes: data, length: data.count)) as! BertAtom
            XCTAssertEqual(result.value, "chat")

            try checkEncoding(result, data: data)
        } catch {
            XCTFail()
        }
    }
    
    func testBinary() {
        let data: [UInt8] = [131,109,0,0,0,3,1,2,3]
        let result: BertBinary
        do {
            result = try Bert.decode(NSData(bytes: data, length: data.count)) as! BertBinary
            var buffer = [UInt8](count: result.value.length, repeatedValue: 0)
            result.value.getBytes(&buffer, length:result.value.length)
            XCTAssertEqual(buffer, [1,2,3])

            try checkEncoding(result, data: data)
        } catch {
            XCTFail()
        }
    }

    func testSmallInt() {
        let data: [UInt8] = [131,97,35]
        let result: BertNumber
        do {
            result = try Bert.decode(NSData(bytes: data, length: data.count)) as! BertNumber
            XCTAssertEqual(result.value, 35)
            
            try checkEncoding(result, data: data)
        } catch {
            XCTFail()
        }
    }
    
    func testInteger() {
        let data: [UInt8] = [131,98,59,154,202,0]
        let result: BertNumber
        do {
            result = try Bert.decode(NSData(bytes: data, length: data.count)) as! BertNumber
            XCTAssertEqual(result.value, 1000000000)
            
            try checkEncoding(result, data: data)
        } catch {
            XCTFail()
        }
    }

    func testSmallBig() {
        let data: [UInt8] = [131,110,7,0,255,255,255,255,255,255,255]
        let result: BertNumber
        do {
            result = try Bert.decode(NSData(bytes: data, length: data.count)) as! BertNumber
            XCTAssertEqual(result.value, 72057594037927935)
            
            try checkEncoding(result, data: data)
        } catch {
            XCTFail()
        }
    }
    
    func testDouble() {
        let data: [UInt8] = [131,70,64,57,76,204,204,204,204,205]
        let result: BertFloat
        do {
            result = try Bert.decode(NSData(bytes: data, length: data.count)) as! BertFloat
            XCTAssertEqual(result.value, 25.3)
            
            try checkEncoding(result, data: data)
        } catch {
            XCTFail()
        }
    }
    
    func testString() {
        let data: [UInt8] = [131,107,0,5,104,101,108,108,111]
        let result: BertString
        do {
            result = try Bert.decode(NSData(bytes: data, length: data.count)) as! BertString
            XCTAssertEqual(result.value, "hello")
            
            try checkEncoding(result, data: data)
        } catch {
            XCTFail()
        }
    }

    func testTuple() {
        let data: [UInt8] = [131,104,3,97,1,100,0,4,99,104,97,116,107,0,5,104,101,108,108,111]
        let result: BertTuple
        do {
            result = try Bert.decode(NSData(bytes: data, length: data.count)) as! BertTuple
            XCTAssertEqual(result.elements.count, 3)
            XCTAssertEqual((result.elements[0] as! BertNumber).value, 1)
            XCTAssertEqual((result.elements[1] as! BertAtom).value, "chat")
            XCTAssertEqual((result.elements[2] as! BertString).value, "hello")
            
            try checkEncoding(result, data: data)
        } catch {
            XCTFail()
        }
    }
    
    func testList() {
        let data: [UInt8] = [131,108,0,0,0,3,97,1,100,0,4,99,104,97,116,107,0,5,104,101,108,108,111,106]
        let result: BertList
        do {
            result = try Bert.decode(NSData(bytes: data, length: data.count)) as! BertList
            XCTAssertEqual(result.elements.count, 3)
            XCTAssertEqual((result.elements[0] as! BertNumber).value, 1)
            XCTAssertEqual((result.elements[1] as! BertAtom).value, "chat")
            XCTAssertEqual((result.elements[2] as! BertString).value, "hello")
            
            try checkEncoding(result, data: data)
        } catch {
            XCTFail()
        }
    }

}
