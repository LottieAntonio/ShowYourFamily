import Foundation

struct FamilyGraphData: Equatable {
    struct RelationNode: Equatable {
        let person: Person
        let relationType: RelationType
        let level: Int
        var subNodes: FamilyGraphData
    }
    
    let centerPerson: Person
    var parents: [RelationNode]
    var children: [RelationNode]
    var spouses: [RelationNode]
    var siblings: [RelationNode]
    
    // 由于 Person 和 RelationType 已经遵循 Equatable，
    // Swift 会自动生成 Equatable 的实现
}
