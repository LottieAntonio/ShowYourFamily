import Foundation

struct FamilyGraphData: Equatable {
    struct RelationNode: Equatable {
        let person: Person
        let relationType: RelationType
        let level: Int
        let subNodes: FamilyGraphData?
    }
    
    let centerPerson: Person
    let parents: [RelationNode]
    let children: [RelationNode]
    let spouses: [RelationNode]
    let siblings: [RelationNode]
    
    // 由于 Person 和 RelationType 已经遵循 Equatable，
    // Swift 会自动生成 Equatable 的实现
}