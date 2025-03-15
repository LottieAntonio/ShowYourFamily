/*
 * RelativeTitleGenerator 类
 * 作用：生成亲属称谓
 * - 计算并生成称谓
 * - 处理称谓的缓存
 * - 生成关系路径描述
 */

import Foundation

class RelativeTitleGenerator {
    // 关系数据
    private var relationships: [Relationship]
    private var persons: [Person]
    
    // 称谓缓存
    private var titleCache: [String: String] = [:]
    
    // 关系处理器
    private var directHandler: DirectRelationHandler
    private var ancestorHandler: AncestorRelationHandler
    private var collateralHandler: CollateralRelationHandler
    private var marriageHandler: MarriageRelationHandler
    private var descendantHandler: DescendantRelationHandler
    
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
    
    // 生成缓存键
    private func cacheKey(from sourceId: UUID, to targetId: UUID) -> String {
        return "\(sourceId.uuidString)_\(targetId.uuidString)"
    }
    
    // 清除缓存
    private func clearCache() {
        titleCache.removeAll()
    }
    
    // 更新数据
    func updateData(relationships: [Relationship], persons: [Person]) {
        self.relationships = relationships
        self.persons = persons
        
        // 更新各个处理器
        directHandler.updateData(relationships: relationships, persons: persons)
        ancestorHandler.updateData(relationships: relationships, persons: persons)
        collateralHandler.updateData(relationships: relationships, persons: persons)
        marriageHandler.updateData(relationships: relationships, persons: persons)
        descendantHandler.updateData(relationships: relationships, persons: persons)
        
        // 清除缓存
        clearCache()
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
        
        // 检查缓存
        let key = cacheKey(from: selfPerson.id, to: relative.id)
        if let cachedTitle = titleCache[key] {
            return cachedTitle
        }
        
        // 设置处理超时
        let startTime = Date()
        let maxProcessTime: TimeInterval = 2.0 // 最多处理2秒
        
        // 检查是否存在直接关系
        let directRelations = relationships.filter { relation in
            (relation.fromPerson == selfPerson.id && relation.toPerson == relative.id) ||
            (relation.fromPerson == relative.id && relation.toPerson == selfPerson.id)
        }
        
       
        // 直接检查父子关系
        if let fatherRelation = directRelations.first(where: { 
            $0.type == .father && $0.fromPerson == relative.id && $0.toPerson == selfPerson.id 
        }) {
            let title = RelationshipTitleMapper.getParentTitle(gender: .male)
            titleCache[key] = title
            return title
        }
        
        if let motherRelation = directRelations.first(where: { 
            $0.type == .mother && $0.fromPerson == relative.id && $0.toPerson == selfPerson.id 
        }) {
            let title = RelationshipTitleMapper.getParentTitle(gender: .female)
            titleCache[key] = title
            return title
        }
        
        if let childRelation = directRelations.first(where: { 
            $0.type == .child && $0.fromPerson == selfPerson.id && $0.toPerson == relative.id 
        }) {
            let title = RelationshipTitleMapper.getChildTitle(gender: relative.gender)
            titleCache[key] = title
            return title
        }
        
        // 尝试查找最简单的称谓
        let baseTitle: String
        
        // 调整处理器调用顺序，优先处理直系关系
        if let title = directHandler.findDirectTitle(from: selfPerson, to: relative) {
            // 直接关系（父母、子女、兄弟姐妹）
            baseTitle = title
        } else if let title = ancestorHandler.findAncestorTitle(from: selfPerson, to: relative) {
            // 祖辈关系（爷爷辈、外公外婆等）
            baseTitle = title
        } else if let title = descendantHandler.findDescendantTitle(from: selfPerson, to: relative) {
            // 后代关系（孙子孙女等）
            baseTitle = title
        } else if let title = collateralHandler.findCollateralTitle(from: selfPerson, to: relative) {
            // 旁系关系（堂/表兄弟姐妹、侄子女等）
            baseTitle = title
        } else if let title = marriageHandler.findMarriageTitle(from: selfPerson, to: relative) {
            // 姻亲关系
            baseTitle = title
        } else {
            // 检查是否处理时间过长
            if Date().timeIntervalSince(startTime) > maxProcessTime {
                return "关系复杂"
            }
//            
//            // 尝试生成简化的关系描述
//            if let simplifiedTitle = findSimplifiedTitle(from: selfPerson, to: relative) {
//                print("✅ 找到简化称谓: \(simplifiedTitle)")
//                return simplifiedTitle
//            }
            
            // 如果简化称谓也找不到，返回名字
            return "\(relative.name)"
        }
        
        // 组合最终称谓
        let finalTitle = baseTitle
        titleCache[key] = finalTitle
        
        return finalTitle
    }
    
//    // 尝试生成简化的称谓
//    private func findSimplifiedTitle(from source: Person, to target: Person) -> String? {
//        // 计算辈分差异
//        let generationDiff = calculateGenerationDifference(from: source, to: target)
//        
//        // 根据辈分差异生成简化称谓
//        if generationDiff != 0 {
//            return RelationshipTitleMapper.getSimplifiedGenerationTitle(
//                generationDiff: generationDiff, 
//                gender: target.gender
//            )
//        }
//        
//        return nil
//    }
    
    // 计算辈分差异
    private func calculateGenerationDifference(from source: Person, to target: Person) -> Int {
        
        // 尝试直接判断是否为祖父母关系
        let grandparents = directHandler.getGrandparents(source.id)
        if grandparents.contains(where: { $0.id == target.id }) {
            return 2  // 祖父母比自己大两辈
        }
        
        // 尝试直接判断是否为孙辈关系
        let grandchildren = directHandler.getGrandchildren(source.id)
        if grandchildren.contains(where: { $0.id == target.id }) {
            return -2  // 孙辈比自己小两辈
        }
        
        // 如果没有直接关系，再使用原来的算法
        var sourceGeneration = 0
        var targetGeneration = 0
        
        // 计算源的辈分（向上查找祖先）
        var currentPerson: Person? = source
        while currentPerson != nil {
            if let father = directHandler.getFather(currentPerson!.id) {
                sourceGeneration -= 1
                currentPerson = father
            } else {
                break
            }
        }
        
        // 计算目标的辈分（向上查找祖先）
        currentPerson = target
        while currentPerson != nil {
            if let father = directHandler.getFather(currentPerson!.id) {
                targetGeneration -= 1
                currentPerson = father
            } else {
                break
            }
        }
        
        // 辈分差异 = 目标辈分 - 源辈分
        let diff = targetGeneration - sourceGeneration
        
        return diff
    }
}
