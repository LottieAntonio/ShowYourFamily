import Foundation

extension FileManager {
    private static var cache: [String: Data] = [:]
    private static let queue = DispatchQueue(label: "com.familytree.filemanager", qos: .userInitiated)
    private static var saveWorkItem: [String: DispatchWorkItem] = [:]
    private static let debounceInterval: TimeInterval = 0.5
    
    static var documentsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        print("📁 文档目录：\(paths[0].path)")
        return paths[0]
    }
    
    static func save<T: Encodable>(_ data: T, to fileName: String) throws {
        let url = documentsDirectory.appendingPathComponent(fileName)
        print("📝 准备保存数据到：\(fileName)")
        try queue.sync {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(data)
            if cache[fileName] != jsonData {
                try jsonData.write(to: url, options: .atomic)
                cache[fileName] = jsonData
                print("✅ 数据成功保存到：\(fileName)")
            } else {
                print("ℹ️ 数据未变化，跳过保存：\(fileName)")
            }
        }
    }
    
    static func load<T: Decodable>(_ type: T.Type, from fileName: String) throws -> T {
        print("📝 尝试加载数据：\(fileName)")
        return try queue.sync {
            if let cachedData = cache[fileName] {
                print("📦 使用缓存数据：\(fileName)")
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let decoded = try decoder.decode(T.self, from: cachedData)
                
                // 检查缓存的数据是否为空数组
                if let array = decoded as? Array<Any>, array.isEmpty {
                    print("⚠️ 缓存数据为空数组，清除缓存")
                    cache.removeValue(forKey: fileName)
                    throw FileError.fileNotFound
                }
                
                return decoded
            }
            
            let url = documentsDirectory.appendingPathComponent(fileName)
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("❌ 文件不存在：\(fileName)")
                throw FileError.fileNotFound
            }
            
            print("💾 从文件读取数据：\(fileName)")
            let data = try Data(contentsOf: url)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // 先尝试解码
            let decoded = try decoder.decode(T.self, from: data)
            
            // 检查是否为空数组
            if let array = decoded as? Array<Any>, array.isEmpty {
                print("⚠️ 加载到空数组，视为文件不存在")
                throw FileError.fileNotFound
            }
            
            // 只有在数据有效时才缓存
            cache[fileName] = data
            return decoded
        }
    }
    
    static func delete(_ fileName: String) throws {
        try queue.sync {
            let url = documentsDirectory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                cache.removeValue(forKey: fileName)
                print("✅ 文件已删除: \(url.path)")
            } else {
                print("⚠️ 要删除的文件不存在: \(url.path)")
            }
        }
    }
    
    static func clearCache() {
        queue.sync {
            cache.removeAll()
            print("🗑 清除文件缓存")
        }
    }
}