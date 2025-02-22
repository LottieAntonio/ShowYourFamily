/*
 * RelativeTitleGenerator 类
 * 作用：生成亲属称谓
 * - 计算并生成称谓
 * - 处理称谓的缓存
 * - 生成关系路径描述
 */

import Foundation

class RelativeTitleGenerator {
    private let relationships: [Relationship]
    private let persons: [Person]
    private var titleCache: [UUID: String] = [:]
    
    // 关系处理器
    private let directHandler: DirectRelationHandler
    private let ancestorHandler: AncestorRelationHandler
    private let collateralHandler: CollateralRelationHandler
    private let marriageHandler: MarriageRelationHandler
    private let descendantHandler: DescendantRelationHandler
    
    init(relationships: [Relationship], persons: [Person]) {
        self.relationships = relationships
        self.persons = persons
        
        // 初始化处理器
        self.directHandler = DirectRelationHandler(relationships: relationships, persons: persons)
        self.ancestorHandler = AncestorRelationHandler(relationships: relationships, persons: persons)
        self.collateralHandler = CollateralRelationHandler(relationships: relationships, persons: persons)
        self.marriageHandler = MarriageRelationHandler(relationships: relationships, persons: persons)
        self.descendantHandler = DescendantRelationHandler(relationships: relationships, persons: persons)
    }
    
    func generateTitle(for relative: Person) -> String? {
        // 添加安全检查
        guard !persons.isEmpty else { return relative.name }
        guard !relationships.isEmpty else { return relative.name }
        
    
        // 如果是自己，直接返回
        if relative.isSelf {
            return "自己"
        }
        
        // 获取自己的信息
        guard let selfPerson = persons.first(where: { $0.isSelf }) else {
            return relative.name
        }
        
        // 清除旧的缓存
        titleCache.removeAll()
        
        // 按优先级尝试不同的关系处理器
        // 修改处理器的调用顺序和逻辑
        let baseTitle: String
        if let title = directHandler.findDirectTitle(from: selfPerson, to: relative) {
            // 直接关系（包括兄弟姐妹）
            baseTitle = title
        } else if let title = ancestorHandler.findAncestorTitle(from: selfPerson, to: relative) {
            // 祖辈关系
            baseTitle = title
        } else if let title = descendantHandler.findDescendantTitle(from: selfPerson, to: relative) {
            // 后代关系
            baseTitle = title
        } else if let title = marriageHandler.findMarriageTitle(from: selfPerson, to: relative) {
            // 姻亲关系
            baseTitle = title
        } else if let title = collateralHandler.findCollateralTitle(from: selfPerson, to: relative) {
            // 旁系关系
            baseTitle = title
        } else {
            return "跟\(selfPerson.name)没有直接关系"
        }
        
        // 组合最终称谓：自己的名字 + 的 + 称谓
        let finalTitle = "\(selfPerson.lastName)\(selfPerson.firstName)的\(baseTitle)"
        titleCache[relative.id] = finalTitle
        
        return finalTitle
    }
}
