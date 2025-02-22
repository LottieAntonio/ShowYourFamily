import Foundation

class DescendantRelationHandler: BaseRelationHandler {
    func findDescendantTitle(from source: Person, to target: Person) -> String? {
        // 获取关系路径
        let path = findRelationPath(from: source.id, to: target.id)
        guard !path.isEmpty else { return nil }
        
        // 检查是否是父子关系路径
        var currentId = source.id
        var generationCount = 0
        var throughDaughter = false
        
        for relation in path {
            // 检查是否是从父到子的方向，或者从子到父的方向但类型是父母
            if (relation.fromPerson == currentId && relation.type == .child) ||
               (relation.toPerson == currentId && (relation.type == .father || relation.type == .mother)) {
                // 获取子女
                let childId = relation.fromPerson == currentId ? relation.toPerson : relation.fromPerson
                // 检查子女性别
                if let child = persons.first(where: { $0.id == childId }),
                   child.gender == .female {
                    throughDaughter = true
                }
                currentId = childId
                generationCount += 1
            } else {
                return nil
            }
        }
        
        // 确保最后一个人是目标人物
        guard currentId == target.id else { return nil }
        
        // 处理直系晚辈
        switch generationCount {
        case 1:
            return target.gender == .male ? "儿子" : "女儿"
        case 2:
            if throughDaughter {
                return target.gender == .male ? "外孙" : "外孙女"
            } else {
                return target.gender == .male ? "孙子" : "孙女"
            }
        case 3:
            if throughDaughter {
                return target.gender == .male ? "曾外孙" : "曾外孙女"
            } else {
                return target.gender == .male ? "曾孙" : "曾孙女"
            }
        default:
            if generationCount > 3 {
                let prefix = String(repeating: "玄", count: generationCount - 3)
                if throughDaughter {
                    return target.gender == .male ? "\(prefix)外孙" : "\(prefix)外孙女"
                } else {
                    return target.gender == .male ? "\(prefix)孙" : "\(prefix)孙女"
                }
            }
            return nil
        }
    }
    
    
}
