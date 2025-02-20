import Foundation

class PersonDataService {
    private let dataManager: DataManager
    
    init(dataManager: DataManager) {
        self.dataManager = dataManager
    }
    
    func updatePerson(_ person: Person) async throws {
        try await dataManager.savePerson(person)
    }
    
    func deletePerson(_ personId: UUID, relationships: [Relationship]) async throws {
        // 删除相关关系
        let relatedRelationships = relationships.filter {
            $0.fromPerson == personId || $0.toPerson == personId
        }
        
        for relationship in relatedRelationships {
            try await dataManager.deleteRelationship(relationship.id)
        }
        
        // 删除人物
        try await dataManager.deletePerson(personId)
    }
    
    func addStory(_ story: Story, to person: Person) async throws {
        var updatedPerson = person
        if var stories = updatedPerson.stories {
            stories.append(story)
            updatedPerson.stories = stories
        } else {
            updatedPerson.stories = [story]
        }
        try await updatePerson(updatedPerson)
    }
}