import Foundation

extension FileManager {
    private static var cache: [String: Data] = [:]
    private static let queue = DispatchQueue(label: "com.familytree.filemanager", qos: .userInitiated)
    private static var saveWorkItem: [String: DispatchWorkItem] = [:]
    private static let debounceInterval: TimeInterval = 0.5
    
    static var documentsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    static func save<T: Encodable>(_ data: T, to fileName: String) throws {
        let url = documentsDirectory.appendingPathComponent(fileName)
        try queue.sync {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(data)
            if cache[fileName] != jsonData {
                try jsonData.write(to: url, options: .atomic)
                cache[fileName] = jsonData
            }
        }
    }
    
    static func load<T: Decodable>(_ type: T.Type, from fileName: String) throws -> T {
        return try queue.sync {
            if let cachedData = cache[fileName] {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: cachedData)
            }
            
            let url = documentsDirectory.appendingPathComponent(fileName)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw NSError(domain: "FileManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "文件不存在"])
            }
            
            let data = try Data(contentsOf: url)
            cache[fileName] = data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
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
}