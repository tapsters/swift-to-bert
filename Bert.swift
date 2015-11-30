//
//  Bert.swift
//
//  Based on https://github.com/saleyn/erlb.js
//  Created by Vitaly Shutko <sokal32@gmail.com> on 11/27/15.
//  Copyright © 2015 sokal32. All rights reserved.
//

import Foundation

enum BertError: ErrorType {
    case NotValidBertObject
    case NotValidErlangTerm
    case UnexpectedErlangType
    case IntegerValueToLarge
    case AtomLengthToLarge
}

enum BertType: UInt8 {
    case Version = 131
    case SmallAtom = 115
    case Atom = 100
    case Binary = 109
    case SmallInteger = 97
    case Integer = 98
    case SmallBig = 110
//        case LargetBig = 111
//        case Float = 99
    case NewFloat = 70
    case String = 107
//        case Port = 102
//        case Pid = 103
    case SmallTuple = 104
    case LargeTuple = 105
    case List = 108
//        case Reference = 101
//        case NewReference = 114
    case Nil = 106
}

class BertObject {
    var type: UInt8 = 0
}

class BertAtom: BertObject {
    var value = ""
    
    init (fromString string: String) {
        value = string
    }
}

class BertBool: BertObject {
    var value: Bool
    
    init (fromBool b: Bool) {
        value = b
    }
}

class BertUndefined: BertAtom {
    init () {
        super.init(fromString: "undefined")
    }
}

class BertBinary: BertObject {
    var value: NSData
    
    init (fromNSData d: NSData) {
        value = d
    }
}

class BertNumber: BertObject {
    var value: Int64
    
    init (fromUInt8 i: UInt8) {
        value = Int64(i)
    }
    
    init (fromInt32 i: Int32) {
        value = Int64(i)
    }

    init (fromInt64 i: Int64) {
        value = i
    }
}

class BertFloat: BertObject {
    var value: Double
    
    init (fromDouble d: Double) {
        value = d
    }
}

class BertString: BertObject {
    var value: String
    
    init (fromString s: String) {
        value = s
    }
}

class BertTuple: BertObject {
    var elements: [BertObject]
    
    init (fromElements e: [BertObject]) {
        elements = e
    }
}

class BertList: BertObject {
    var elements: [BertObject]
    
    init (fromElements e: [BertObject]) {
        elements = e
    }
}

class Bert {
    
    class func encode (object: BertObject) throws -> [UInt8] {
        let length = try getEncodeSize(object)
        var offset: Int = 0
        var data = [UInt8](count: length + 1, repeatedValue: 0)
        
        data[offset++] = BertType.Version.rawValue
        
        try encodeInner(object, data: &data, offset: &offset)
        
        return data
    }
    
    class func getObjectClassName(object: BertObject) -> String {
        let className = NSStringFromClass(object_getClass(object) as AnyClass)
        let classNameArr = className.componentsSeparatedByString(".")

        return classNameArr.last!
    }

    class func getEncodeSize (object: BertObject) throws -> Int {
        switch getObjectClassName(object) {
            case "BertBool":
                let bool = (object as! BertBool)
                return 1 + 2 + (bool.value ? 4 : 5)
            case "BertUndefined":
                return 1 + 2 + 9
            case "BertAtom":
                let atom = (object as! BertAtom)
                return 1 + 2 + atom.value.characters.count
            case "BertBinary":
                let binary = (object as! BertBinary)
                return 1 + 4 + binary.value.length
            case "BertNumber":
                let number = (object as! BertNumber)
                if number.value >= 0 && number.value <= 255 {
                    return 1 + 1
                }
                if number.value >= -2147483648 && number.value <= 2147483647 {
                    return 1 + 4
                }
                return 1 + 1 + 8
            case "BertFloat":
                return 1 + 8
            case "BertString":
                // TODO: implement encoding for length > 0xFF
                let string = (object as! BertString)
                return 1 + 2 + string.value.characters.count
            case "BertTuple":
                let tuple = (object as! BertTuple)
                var n = 0
                for element in tuple.elements {
                    n += try getEncodeSize(element)
                }
                return 1 + (tuple.elements.count <= 255 ? 1 : 4) + n
            case "BertList":
                let list = (object as! BertList)
                var n = 0
                for element in list.elements {
                    n += try getEncodeSize(element)
                }
                return 1 + 4 + 1 + n
            default:
                throw BertError.UnexpectedErlangType
        }
    }
    
    class func encodeInner(object: BertObject, inout data: [UInt8], inout offset: Int) throws {
        switch getObjectClassName(object) {
            case "BertAtom":       encodeAtom(object as! BertAtom, data: &data, offset: &offset)
            case "BertBool":       encodeBool(object as! BertBool, data: &data, offset: &offset)
            case "BertUndefined":  encodeAtom(object as! BertUndefined, data: &data, offset: &offset)
            case "BertBinary":     encodeBinary(object as! BertBinary, data: &data, offset: &offset)
            case "BertNumber":     encodeNumber(object as! BertNumber, data: &data, offset: &offset)
            case "BertFloat":      encodeFloat(object as! BertFloat, data: &data, offset: &offset)
            case "BertString":     encodeString(object as! BertString, data: &data, offset: &offset)
            case "BertTuple":  try encodeTuple(object as! BertTuple, data: &data, offset: &offset)
            case "BertList":   try encodeList(object as! BertList, data: &data, offset: &offset)
            default:
                throw BertError.UnexpectedErlangType
        }
    }
    
    class func encodeAtom(atom: BertAtom, inout data: [UInt8], inout offset: Int) {
        let length = UInt16(atom.value.characters.count)

        data[offset++] = BertType.Atom.rawValue

        writeUInt16(length, data: &data, offset: &offset)
        
        memcpy(&data[offset], (atom.value as NSString).UTF8String, Int(length))
        offset += Int(length)
    }
    
    class func encodeBool(bool: BertBool, inout data: [UInt8], inout offset: Int) {
        let atom = BertAtom(fromString: (bool.value ? "true" : "false"))
        encodeAtom(atom, data: &data, offset: &offset)
    }
    
    class func encodeBinary(binary: BertBinary, inout data: [UInt8], inout offset: Int) {
        data[offset++] = BertType.Binary.rawValue
        
        let length = UInt32(binary.value.length)
        
        writeUInt32(length, data: &data, offset: &offset)
        
        memcpy(&data[offset], binary.value.bytes, Int(length))
        offset += Int(length)
    }
    
    class func encodeNumber(number: BertNumber, inout data: [UInt8], inout offset: Int) {
        if number.value >= 0 && number.value <= 255 {
            data[offset++] = BertType.SmallInteger.rawValue
            data[offset++] = UInt8(number.value)
        } else if number.value >= -2147483648 && number.value <= 2147483647 {
            data[offset++] = BertType.Integer.rawValue
            writeUInt32(UInt32(number.value), data: &data, offset: &offset)
        } else {
            data[offset++] = BertType.SmallBig.rawValue
            
            var i: UInt64 = UInt64(number.value < 0 ? -number.value : number.value)
            var n = 0
            var pos = offset + 2 //arity, sign
            
            while (i > 0) {
                data[pos++] = UInt8(i % 256)
                i = UInt64(floor(Double(i / 256)))
                n++
            }
            
            data[offset++] = UInt8(n)
            data[offset++] = UInt8(Int(number.value < 0))
            offset += n
        }
    }
    
    class func encodeFloat(float: BertFloat, inout data: [UInt8], inout offset: Int) {
        data[offset++] = BertType.NewFloat.rawValue
        
        let bytes = withUnsafePointer(&float.value) {
            Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>($0), count: sizeof(Double)))
        }
        var i = UnsafePointer<UInt64>(bytes).memory.bigEndian

        memcpy(&data[offset], &i, sizeof(Double))
        offset += 8
    }
    
    class func encodeString(string: BertString, inout data: [UInt8], inout offset: Int) {
        data[offset++] = BertType.String.rawValue
        
        writeUInt16(UInt16(string.value.characters.count), data: &data, offset: &offset)
        
        memcpy(&data[offset], (string.value as NSString).UTF8String, string.value.characters.count)
        offset += string.value.characters.count
    }
    
    class func encodeTuple(tuple: BertTuple, inout data: [UInt8], inout offset: Int) throws {
        if tuple.elements.count <= 255 {
            data[offset++] = BertType.SmallTuple.rawValue
            data[offset++] = UInt8(tuple.elements.count)
        } else {
            data[offset++] = BertType.LargeTuple.rawValue
            writeUInt32(UInt32(tuple.elements.count), data: &data, offset: &offset)
        }
        
        for element in tuple.elements {
            try encodeInner(element, data: &data, offset: &offset)
        }
    }
    
    class func encodeList(list: BertList, inout data: [UInt8], inout offset: Int) throws {
        data[offset++] = BertType.List.rawValue
        writeUInt32(UInt32(list.elements.count), data: &data, offset: &offset)

        for element in list.elements {
            try encodeInner(element, data: &data, offset: &offset)
        }
        
        data[offset++] = BertType.Nil.rawValue
    }
    
    class func writeUInt16(i: UInt16, inout data: [UInt8], inout offset: Int) {
        data[offset++] = UInt8((i & 0xFF00) >> 8)
        data[offset++] = UInt8(i & 0xFF)
    }
    
    class func writeUInt32(i: UInt32, inout data: [UInt8], inout offset: Int) {
        data[offset++] = UInt8((i & 0xFF000000) >> 24)
        data[offset++] = UInt8((i & 0xFF0000) >> 16)
        data[offset++] = UInt8((i & 0xFF00) >> 8)
        data[offset++] = UInt8(i & 0xFF)
    }

    class func decode (data: NSData) throws -> BertObject {
        var offset = 0
        var buffer = [UInt8](count: 1, repeatedValue: 0)

        data.getBytes(&buffer, range: NSMakeRange(offset++, 1))
        let header = buffer[0]

        if header != BertType.Version.rawValue {
            throw BertError.NotValidErlangTerm
        }
        
        return try decodeInner(data, offset: &offset)
    }
    
    class func decodeInner (data: NSData, inout offset: Int) throws -> BertObject {
        var buffer = [UInt8](count: 1, repeatedValue: 0)

        data.getBytes(&buffer, range: NSMakeRange(offset, 1))
        let type = buffer[0]
        
        switch type {
            case BertType.Atom.rawValue:         return try decodeAtom(data, offset: &offset)
            case BertType.SmallAtom.rawValue:    return try decodeAtom(data, offset: &offset)
            case BertType.Binary.rawValue:       return     decodeBinary(data, offset: &offset)
            case BertType.SmallInteger.rawValue: return try decodeNumber(data, offset: &offset)
            case BertType.Integer.rawValue:      return try decodeNumber(data, offset: &offset)
            case BertType.SmallBig.rawValue:     return try decodeNumber(data, offset: &offset)
            case BertType.NewFloat.rawValue:     return     decodeDouble(data, offset: &offset)
            case BertType.String.rawValue:       return     decodeString(data, offset: &offset)
            case BertType.SmallTuple.rawValue:   return try decodeTuple(data, offset: &offset)
            case BertType.LargeTuple.rawValue:   return try decodeTuple(data, offset: &offset)
            case BertType.List.rawValue:         return try decodeList(data, offset: &offset)
        default:
            throw BertError.UnexpectedErlangType
        }
    }

    class func decodeAtom(data: NSData, inout offset: Int) throws -> BertObject {
        var buffer = [UInt8](count: 2, repeatedValue: 0)
        
        data.getBytes(&buffer, range: NSMakeRange(offset++, 1))
        let type = buffer[0]
        var n: Int
        
        switch type {
            case BertType.Atom.rawValue:
                data.getBytes(&buffer, range: NSMakeRange(offset, 2))
                offset += 2
                n = Int(UInt16(UnsafePointer<UInt16>(buffer).memory.bigEndian))
            case BertType.SmallAtom.rawValue:
                data.getBytes(&buffer, range: NSMakeRange(offset++, 1))
                n = Int(buffer[0])
            default:
                throw BertError.UnexpectedErlangType
        }
        
        var buffer1 = [UInt8](count: n, repeatedValue: 0)
        data.getBytes(&buffer1, range: NSMakeRange(offset, n))
        offset += n

        let value = NSString(bytes: buffer1, length: n, encoding: NSUTF8StringEncoding) as! String
        
        switch value {
            case "true":      return BertBool(fromBool: true)
            case "false":     return BertBool(fromBool: false)
            case "undefined": return BertUndefined()
            default:          return BertAtom(fromString: value)
        }
    }
    
    class func decodeBinary(data: NSData, inout offset: Int) -> BertObject {
        offset++

        var buffer = [UInt8](count: 4, repeatedValue: 0)
        
        data.getBytes(&buffer, range: NSMakeRange(offset, 4))
        offset += 4
        let length = Int(Int32(UnsafePointer<Int32>(buffer).memory.bigEndian))
        
        var dataBuffer = [UInt8](count: length, repeatedValue: 0)
        data.getBytes(&dataBuffer, range: NSMakeRange(offset, length))
        offset += length

        return BertBinary(fromNSData: NSData(bytes: dataBuffer, length: length))
    }

    class func decodeNumber(data: NSData, inout offset: Int) throws -> BertObject {
        var buffer = [UInt8](count: 10, repeatedValue: 0)
        
        data.getBytes(&buffer, range: NSMakeRange(offset++, 1))
        let type = buffer[0]
        
        switch type {
            case BertType.SmallInteger.rawValue:
                data.getBytes(&buffer, range: NSMakeRange(offset++, 1))
                let value = buffer[0]
                return BertNumber(fromUInt8: value)
            case BertType.Integer.rawValue:
                data.getBytes(&buffer, range: NSMakeRange(offset, 4))
                offset += 4
                let value = Int32(UnsafePointer<Int32>(buffer).memory.bigEndian)
                return BertNumber(fromInt32: value)
            case BertType.SmallBig.rawValue:
                data.getBytes(&buffer, range: NSMakeRange(offset++, 1))
                let arity = buffer[0]
                if (arity > 7) {
                    throw BertError.IntegerValueToLarge
                }

                data.getBytes(&buffer, range: NSMakeRange(offset++, 1))
                let sign = buffer[0]
                
                var value: Int64 = 0
                var n: Int64 = 1
                for i in 0...arity-1 {
                    data.getBytes(&buffer, range:NSMakeRange(offset++, 1))
                    let v = Int64(buffer[0])
                    value += v * n
                    if i+1 != arity {
                        n *= 256
                    }
                }
                
                if sign > 0 {
                    value = -value
                }

                return BertNumber(fromInt64: Int64(value))
            default:
                throw BertError.UnexpectedErlangType
        }
    }

    class func decodeDouble(data: NSData, inout offset: Int) -> BertObject {
        offset++
        
        var buffer = [UInt8](count: 8, repeatedValue: 0)

        data.getBytes(&buffer, range: NSMakeRange(offset, 8))
        offset += 8
        
        var i = Int64(UnsafePointer<Int64>(buffer).memory.bigEndian)
        var d: Double = 0
        memcpy(&d, &i, sizeof(Int64))

        return BertFloat(fromDouble: d)
    }

    class func decodeString(data: NSData, inout offset: Int) -> BertObject {
        offset++
        
        var buffer = [UInt8](count: 2, repeatedValue: 0)
        data.getBytes(&buffer, range: NSMakeRange(offset, 2))
        offset += 2
        
        let length = Int(UInt16(UnsafePointer<UInt16>(buffer).memory.bigEndian))
        var stringBuffer = [UInt8](count: length, repeatedValue: 0)

        data.getBytes(&stringBuffer, range: NSMakeRange(offset, length))
        offset += length
        
        return BertString(fromString: String(bytes: stringBuffer, encoding: NSUTF8StringEncoding)!)
    }
    
    class func decodeTuple(data: NSData, inout offset: Int) throws -> BertObject {
        var buffer = [UInt8](count: 4, repeatedValue: 0)
        var n: Int

        data.getBytes(&buffer, range: NSMakeRange(offset++, 1))
        let type = buffer[0]
        
        switch type {
            case BertType.SmallTuple.rawValue:
                data.getBytes(&buffer, range: NSMakeRange(offset++, 1))
                n = Int(buffer[0])
            case BertType.LargeTuple.rawValue:
                data.getBytes(&buffer, range: NSMakeRange(offset, 4))
                offset += 4
                n = Int(UInt32(UnsafePointer<UInt32>(buffer).memory.bigEndian))
            default:
                throw BertError.UnexpectedErlangType
        }
        
        var elements = [BertObject]()
        for _ in 0...n-1 {
            elements.append(try decodeInner(data, offset: &offset))
        }

        return BertTuple(fromElements: elements)
    }
    
    class func decodeList(data: NSData, inout offset: Int) throws -> BertObject {
        offset++
        
        var buffer = [UInt8](count: 4, repeatedValue: 0)
        
        data.getBytes(&buffer, range: NSMakeRange(offset, 4))
        offset += 4
        let n = Int(UInt32(UnsafePointer<UInt32>(buffer).memory.bigEndian))
        
        var elements = [BertObject]()
        for _ in 0...n-1 {
            elements.append(try decodeInner(data, offset: &offset))
        }
        
        data.getBytes(&buffer, range: NSMakeRange(offset, 1))
        if (buffer[0] == BertType.Nil.rawValue) {
            offset++
        }
        
        return BertList(fromElements: elements)
    }
}