import Foundation

// 添加父母缓存结构体
struct ParentCache {
    var father: Person?
    var mother: Person?
}

class BaseRelationHandler {
    var relationships: [Relationship]
    var persons: [Person]
    
    // 缓存
    private var parentCache: [UUID: ParentCache] = [:]
    private var childrenCache: [UUID: [Person]] = [:]
    private var spouseCache: [UUID: [Person]] = [:]
    private var siblingCache: [UUID: [Person]] = [:]
    
    init(relationships: [Relationship], persons: [Person]) {
        self.relationships = relationships
        self.persons = persons
        // 初始化缓存
        buildCache()
    }
    
    // 添加updateData方法到基类
    func updateData(relationships: [Relationship], persons: [Person]) {
        self.relationships = relationships
        self.persons = persons
        // 清除并重建缓存
        clearCache()
        buildCache()
    }
    
    // 清除缓存
    private func clearCache() {
        parentCache.removeAll()
        childrenCache.removeAll()
        spouseCache.removeAll()
        siblingCache.removeAll()
    }
    
    // 构建缓存
    private func buildCache() {
        // 预先计算并缓存常用关系
        for person in persons {
            // 缓存父母关系
            let (father, mother) = findParents(person.id)
            let parentCacheItem = ParentCache(father: father, mother: mother)
            parentCache[person.id] = parentCacheItem
            
            // 缓存子女关系 - 使用已有的getChildren方法但跳过缓存检查
            childrenCache[person.id] = findChildrenDirectly(person.id)
            
            // 缓存配偶关系 - 使用已有的getSpouses方法但跳过缓存检查
            spouseCache[person.id] = findSpousesDirectly(person.id)
            
            // 缓存兄弟姐妹关系 - 使用已有的getSiblings方法但跳过缓存检查
            siblingCache[person.id] = findSiblingsDirectly(person.id)
        }
    }
    
    // 直接查找子女（不使用缓存）
    private func findChildrenDirectly(_ personId: UUID) -> [Person] {
        // 查找子女关系
        let childRelations = relationships.filter { 
            $0.fromPerson == personId && $0.type == .child 
        }
        
        let children = childRelations.compactMap { relation in
            persons.first(where: { $0.id == relation.toPerson })
        }
        
        return children
    }
    
    // 直接查找配偶（不使用缓存）
    private func findSpousesDirectly(_ personId: UUID) -> [Person] {
        // 查找配偶关系
        let spouseRelations = relationships.filter {
            ($0.fromPerson == personId && $0.type == .spouse) ||
            ($0.toPerson == personId && $0.type == .spouse)
        }
        
        let spouses = spouseRelations.compactMap { relation in
            let spouseId = relation.fromPerson == personId ? relation.toPerson : relation.fromPerson
            return persons.first(where: { $0.id == spouseId })
        }
        
        return spouses
    }
    
    // 直接查找兄弟姐妹（不使用缓存）
    private func findSiblingsDirectly(_ personId: UUID) -> [Person] {
        var siblings: [Person] = []
        
        // 通过父母查找兄弟姐妹
        if let father = getFather(personId) {
            let fatherChildren = findChildrenDirectly(father.id)
            siblings.append(contentsOf: fatherChildren.filter { $0.id != personId })
        }
        
        if let mother = getMother(personId) {
            let motherChildren = findChildrenDirectly(mother.id)
            // 添加不重复的母亲的子女
            for child in motherChildren {
                if child.id != personId && !siblings.contains(where: { $0.id == child.id }) {
                    siblings.append(child)
                }
            }
        }
        
        // 直接的兄弟姐妹关系
        let directSiblingRelations = relationships.filter {
            ($0.fromPerson == personId && ($0.type == .brother || $0.type == .sister)) ||
            ($0.toPerson == personId && ($0.type == .brother || $0.type == .sister))
        }
        
        for relation in directSiblingRelations {
            let siblingId = relation.fromPerson == personId ? relation.toPerson : relation.fromPerson
            if let sibling = persons.first(where: { $0.id == siblingId }),
               !siblings.contains(where: { $0.id == sibling.id }) {
                siblings.append(sibling)
            }
        }
        
        return siblings
    }
    
    // 获取指定类型的关系
    func findRelations(from personId: UUID, ofType type: RelationType) -> [Relationship] {
        return relationships.filter { relation in
            (relation.fromPerson == personId || relation.toPerson == personId) && relation.type == type
        }
    }
    
    // 获取关系中的另一个人
    func getOtherPerson(in relation: Relationship, from personId: UUID) -> UUID? {
        if relation.fromPerson == personId {
            return relation.toPerson
        } else if relation.toPerson == personId {
            return relation.fromPerson
        }
        return nil
    }
    
    // ===== 直接关系查询方法 =====
    
    // 查找一个人的父亲
    func getFather(_ personId: UUID) -> Person? {
        // 检查缓存
        if let cached = parentCache[personId]?.father {
            return cached
        }
        
        
        // 检查所有关系，查找可能的父亲关系
        for (index, relation) in relationships.enumerated() {
            
            // 检查是否是父子关系
            if relation.fromPerson == personId && relation.type == .father {
                if let father = persons.first(where: { $0.id == relation.toPerson }) {
                    return father
                }
            }
            
            if relation.toPerson == personId && relation.type == .father {
                if let father = persons.first(where: { $0.id == relation.fromPerson }) {
                    return father
                }
            }
            
            // 检查是否是子女关系
            if relation.fromPerson == personId && relation.type == .child {
                if let potentialFather = persons.first(where: { $0.id == relation.toPerson && $0.gender == .male }) {
                    return potentialFather
                }
            }
            
            if relation.toPerson == personId && relation.type == .child {
                if let potentialFather = persons.first(where: { $0.id == relation.fromPerson && $0.gender == .male }) {
                    return potentialFather
                }
            }
        }
        
        return nil
    }
    
    // 辅助方法：根据ID获取人名
    private func getPersonName(_ personId: UUID) -> String {
        if let person = persons.first(where: { $0.id == personId }) {
            return person.name
        }
        return personId.uuidString
    }
    
    // 查找一个人的母亲
    func getMother(_ personId: UUID) -> Person? {
        // 检查缓存
        if let cached = parentCache[personId]?.mother {
            return cached
        }
        
        
        // 查找母亲关系 - 考虑两种方向
        // 1. 母亲指向子女的关系
        let motherRelations = relationships.filter { relation in
            // 子女指向母亲的关系
            (relation.fromPerson == personId && relation.type == .mother) ||
            // 母亲指向子女的关系
            (relation.toPerson == personId && relation.type == .child && 
             persons.first(where: { $0.id == relation.fromPerson })?.gender == .female)
        }
        
        for (index, relation) in motherRelations.enumerated() {
            let motherName = relation.type == .mother ? 
                getPersonName(relation.toPerson) : getPersonName(relation.fromPerson)
        }
        
        if let motherRelation = motherRelations.first {
            let motherId = motherRelation.type == .mother ? 
                           motherRelation.toPerson : motherRelation.fromPerson
            if let mother = persons.first(where: { $0.id == motherId }) {
                
                // 添加到缓存
                if parentCache[personId] == nil {
                    parentCache[personId] = ParentCache()
                }
                parentCache[personId]?.mother = mother
                
                return mother
            }
        }
        
        return nil
    }
    
    // 查找一个人的父母
    func findParents(_ personId: UUID) -> (father: Person?, mother: Person?) {
        let father = getFather(personId)
        let mother = getMother(personId)
        return (father, mother)
    }
    
    // 查找一个人的所有子女
    func getChildren(_ personId: UUID) -> [Person] {
        // 检查缓存
        if let cached = childrenCache[personId] {
            return cached
        }
        
        // 查找子女关系
        let childRelations = relationships.filter { 
            $0.fromPerson == personId && $0.type == .child 
        }
        
        let children = childRelations.compactMap { relation in
            persons.first(where: { $0.id == relation.toPerson })
        }
        
        return children
    }
    
    // 查找一个人的所有兄弟姐妹
    func getSiblings(_ personId: UUID) -> [Person] {
        // 检查缓存
        if let cached = siblingCache[personId] {
            return cached
        }
        
        var siblings: [Person] = []
        
        // 通过父母查找兄弟姐妹
        if let father = getFather(personId) {
            let fatherChildren = getChildren(father.id)
            siblings.append(contentsOf: fatherChildren.filter { $0.id != personId })
        }
        
        if let mother = getMother(personId) {
            let motherChildren = getChildren(mother.id)
            // 添加不重复的母亲的子女
            for child in motherChildren {
                if child.id != personId && !siblings.contains(where: { $0.id == child.id }) {
                    siblings.append(child)
                }
            }
        }
        
        // 直接的兄弟姐妹关系
        let directSiblingRelations = relationships.filter {
            ($0.fromPerson == personId && ($0.type == .brother || $0.type == .sister)) ||
            ($0.toPerson == personId && ($0.type == .brother || $0.type == .sister))
        }
        
        for relation in directSiblingRelations {
            let siblingId = relation.fromPerson == personId ? relation.toPerson : relation.fromPerson
            if let sibling = persons.first(where: { $0.id == siblingId }),
               !siblings.contains(where: { $0.id == sibling.id }) {
                siblings.append(sibling)
            }
        }
        
        return siblings
    }
    
    // 查找一个人的配偶
    func getSpouses(_ personId: UUID) -> [Person] {
        // 检查缓存
        if let cached = spouseCache[personId] {
            return cached
        }
        
        // 查找配偶关系
        let spouseRelations = relationships.filter {
            ($0.fromPerson == personId && $0.type == .spouse) ||
            ($0.toPerson == personId && $0.type == .spouse)
        }
        
        let spouses = spouseRelations.compactMap { relation in
            let spouseId = relation.fromPerson == personId ? relation.toPerson : relation.fromPerson
            return persons.first(where: { $0.id == spouseId })
        }
        
        return spouses
    }
    
    // 查找一个人的祖父母
    // 获取一个人的所有祖父母
    func getGrandparents(_ personId: UUID) -> [Person] {
        var grandparents: [Person] = []
        
        // 通过父亲查找祖父母
        if let father = getFather(personId) {
            
            if let grandfather = getFather(father.id) {
                grandparents.append(grandfather)
            }
            
            if let grandmother = getMother(father.id) {
                grandparents.append(grandmother)
            }
        }
        // 通过母亲查找祖父母
        if let mother = getMother(personId) {
            
            if let grandfather = getFather(mother.id) {
                grandparents.append(grandfather)
            }
            if let grandmother = getMother(mother.id) {
                grandparents.append(grandmother)
            }
        } 
        return grandparents
    }
    
    // 查找一个人的叔伯姑姨
    func getUnclesAunts(_ personId: UUID) -> [Person] {
        var unclesAunts: [Person] = []
        
        // 通过父亲查找叔伯
        if let father = getFather(personId) {
            let fatherSiblings = getSiblings(father.id)
            unclesAunts.append(contentsOf: fatherSiblings)
        }
        
        // 通过母亲查找舅姨
        if let mother = getMother(personId) {
            let motherSiblings = getSiblings(mother.id)
            unclesAunts.append(contentsOf: motherSiblings)
        }
        
        return unclesAunts
    }
    
    // 查找一个人的堂表兄弟姐妹
    func getCousins(_ personId: UUID) -> [Person] {
        var cousins: [Person] = []
        
        // 获取所有叔伯姑姨
        let unclesAunts = getUnclesAunts(personId)
        
        // 获取叔伯姑姨的子女
        for uncleAunt in unclesAunts {
            let children = getChildren(uncleAunt.id)
            cousins.append(contentsOf: children)
        }
        
        return cousins
    }
    
    // 查找一个人的侄子女/外甥
    func getNephewsNieces(_ personId: UUID) -> [Person] {
        var nephewsNieces: [Person] = []
        
        // 获取所有兄弟姐妹
        let siblings = getSiblings(personId)
        
        // 获取兄弟姐妹的子女
        for sibling in siblings {
            let children = getChildren(sibling.id)
            nephewsNieces.append(contentsOf: children)
        }
        
        return nephewsNieces
    }
    
    // 查找一个人的孙子女
    func getGrandchildren(_ personId: UUID) -> [Person] {
        var grandchildren: [Person] = []
        
        // 获取所有子女
        let children = getChildren(personId)
        
        // 获取子女的子女
        for child in children {
            let childrenOfChild = getChildren(child.id)
            grandchildren.append(contentsOf: childrenOfChild)
        }
        
        return grandchildren
    }
    
    // 辅助方法：判断两个人是否有直接关系
    func hasDirectRelation(from sourceId: UUID, to targetId: UUID) -> Bool {
        return relationships.contains { relation in
            (relation.fromPerson == sourceId && relation.toPerson == targetId) ||
            (relation.fromPerson == targetId && relation.toPerson == sourceId)
        }
    }
    
    // 辅助方法：获取两个人之间的直接关系类型
    func getDirectRelationType(from sourceId: UUID, to targetId: UUID) -> RelationType? {
        if let relation = relationships.first(where: { 
            ($0.fromPerson == sourceId && $0.toPerson == targetId) ||
            ($0.fromPerson == targetId && $0.toPerson == sourceId)
        }) {
            if relation.fromPerson == sourceId {
                return relation.type
            } else {
                return relation.type.opposite
            }
        }
        return nil
    }
    
    // 辅助方法：判断一个人是否比另一个人年长
    func isOlder(_ person1: Person, than person2: Person) -> Bool? {
        // 如果有出生日期，直接比较
        if let birth1 = person1.birthDate, let birth2 = person2.birthDate {
            return birth1 < birth2
        }
        
        // 否则返回nil表示无法确定
        return nil
    }
    
    // 查找侄子/侄女称谓（基类提供默认实现）
    func findNephewTitle(from source: Person, to target: Person, isFromBrother: Bool) -> String? {
        if target.gender == .male {
            return isFromBrother ? "侄子" : "外甥"
        } else {
            return isFromBrother ? "侄女" : "外甥女"
        }
    }
}
