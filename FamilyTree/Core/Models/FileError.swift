import Foundation

enum FileError: LocalizedError {
    case fileNotFound
    case directoryNotFound
    case saveFailed
    case loadFailed
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "文件不存在"
        case .directoryNotFound:
            return "无法获取文档目录"
        case .saveFailed:
            return "保存文件失败"
        case .loadFailed:
            return "加载文件失败"
        }
    }
}