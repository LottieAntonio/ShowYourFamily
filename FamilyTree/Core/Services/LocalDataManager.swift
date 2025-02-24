import Foundation

class LocalDataManager: DataManaging {
    private let familiesFileName = "families.json"
    
    // 添加获取文档目录的方法
    private func getDocumentsDirectory() throws -> URL {
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw NSError(
                domain: "LocalDataManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "无法获取文档目录"]
            )
        }
        print("📁 文档目录：\(documentsDirectory.path)")
        return documentsDirectory
    }
    
    // 添加同步加载方法
    func loadPersonsSync() throws -> [Person] {
        // 实现同步加载逻辑
        let fileURL = try getDocumentsDirectory().appendingPathComponent("persons.json")
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Person].self, from: data)
    }
    
    func loadRelationshipsSync() throws -> [Relationship] {
        // 实现同步加载逻辑
        let fileURL = try getDocumentsDirectory().appendingPathComponent("relationships.json")
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Relationship].self, from: data)
    }
    
 
    private func getPersonsFileName(for familyId: UUID) -> String {
        return "persons_\(familyId.uuidString).json"
    }
        
    private func getRelationshipsFileName(for familyId: UUID) -> String {
        return "relationships_\(familyId.uuidString).json"
    }
    
    func loadPersons(familyId: UUID) async throws -> [Person] {
        let fileName = getPersonsFileName(for: familyId)
        do {
            print("📝 尝试加载 \(fileName)...")
            let persons = try FileManager.load([Person].self, from: fileName)
            print("✅ 成功加载 \(persons.count) 个成员")
            return persons
        } catch {
            print("⚠️ 加载 \(fileName) 失败：\(error.localizedDescription)")
            if (error as? FileError) == .fileNotFound {
                print("📝 文件不存在，返回空数组")
                return []
            }
            throw error
        }
    }

    
    
    func savePerson(_ person: Person) async throws {
        let fileName = getPersonsFileName(for: person.familyId)
        print("💾 保存成员到 \(fileName)：\(person.firstName) \(person.lastName)")
        
        var persons: [Person] = []
        do {
            persons = try await loadPersons(familyId: person.familyId)
        } catch {
            print("📝 \(fileName) 不存在，创建新文件")
        }
        
        if let index = persons.firstIndex(where: { $0.id == person.id }) {
            persons[index] = person
        } else {
            persons.append(person)
        }
        
        try FileManager.save(persons, to: fileName)
        print("✅ 成功保存到 \(fileName)")
    }
    
    func saveRelationship(_ relationship: Relationship) async throws {
        // 需要先获取这个关系所属的家谱 ID
        guard let person = try await getPerson(by: relationship.fromPerson) else {
            throw DataError.personNotFound
        }
        
        let fileName = getRelationshipsFileName(for: person.familyId)
        print("💾 保存关系到 \(fileName)：\(relationship.type.rawValue)")
        
        var relationships: [Relationship] = []
        do {
            relationships = try await loadRelationships(familyId: person.familyId)
        } catch {
            print("📝 \(fileName) 不存在，创建新文件")
        }
        
        if let index = relationships.firstIndex(where: { $0.id == relationship.id }) {
            relationships[index] = relationship
        } else {
            relationships.append(relationship)
        }
        
        try FileManager.save(relationships, to: fileName)
        print("✅ 成功保存到 \(fileName)")
    }
    
    func deletePerson(_ personId: UUID) async throws {
        // 先从所有家谱中查找这个人
        let families = try await loadFamilies()
        for family in families {
            var persons = try await loadPersons(familyId: family.id)
            if persons.contains(where: { $0.id == personId }) {
                persons.removeAll { $0.id == personId }
                try FileManager.save(persons, to: getPersonsFileName(for: family.id))
                return
            }
        }
        throw DataError.personNotFound
    }
    
    func deleteRelationship(_ relationshipId: UUID) async throws {
        // 遍历所有家谱查找关系
        let families = try await loadFamilies()
        for family in families {
            var relationships = try await loadRelationships(familyId: family.id)
            if relationships.contains(where: { $0.id == relationshipId }) {
                relationships.removeAll { $0.id == relationshipId }
                try FileManager.save(relationships, to: getRelationshipsFileName(for: family.id))
                return
            }
        }
        throw DataError.relationshipNotFound
    }
    
    // 加载所有家谱
    func loadFamilies() async throws -> [Family] {
        print("\n=== loadFamilies 开始执行 ===")
        
        // 检查文件状态
        let familiesUrl = FileManager.documentsDirectory.appendingPathComponent(familiesFileName)
        
        // 如果 families.json 不存在，返回空数组
        if !FileManager.default.fileExists(atPath: familiesUrl.path) {
            // 只在第一次启动时创建示例家谱
            if !UserDefaults.standard.bool(forKey: "hasInitializedFamilyTree") {
                print("\n🔄 首次启动，创建示例家谱...")
                
                // 清除所有数据和缓存
                print("🗑 清除现有数据...")
                try? FileManager.delete(familiesFileName)
                FileManager.clearCache()
                
                // 加载示例数据
                print("\n📥 加载示例数据...")
                let (family, persons, relationships) = ExampleData.loadExampleData()
                
                // 保存家谱
                print("\n💾 保存数据到文件...")
                try FileManager.save([family], to: familiesFileName)
                
                // 保存所有数据
                let updatedPersons = persons.map { person -> Person in
                    var updatedPerson = person
                    updatedPerson.familyId = family.id
                    return updatedPerson
                }
                try FileManager.save(updatedPersons, to: getPersonsFileName(for: family.id))
                try FileManager.save(relationships, to: getRelationshipsFileName(for: family.id))
                
                // 标记已初始化
                UserDefaults.standard.set(true, forKey: "hasInitializedFamilyTree")
                
                print("\n✅ 初始化完成")
                return [family]
            }
            
            print("📝 families.json 不存在，返回空数组")
            return []
        }
        
        // 正常加载逻辑
        print("\n📖 执行正常加载流程...")
        let families = try FileManager.load([Family].self, from: familiesFileName)
        print("✅ 成功加载 \(families.count) 个家谱")
        return families
    }


   
    
    func savePersons(_ persons: [Person]) async throws {
        print("📝 开始保存 \(persons.count) 个人物...")
        for person in persons {
            try await savePerson(person)
        }
        print("✅ 人物保存完成")
    }
    
    // 保存家谱
    func saveFamily(_ family: Family) async throws {
        var families = try await loadFamilies()
        if let index = families.firstIndex(where: { $0.id == family.id }) {
            families[index] = family
        } else {
            families.append(family)
        }
        try FileManager.save(families, to: familiesFileName)
    }
    

    
    // 根据家谱 ID 加载关系
    func loadRelationships(familyId: UUID) async throws -> [Relationship] {
        let fileName = getRelationshipsFileName(for: familyId)
        do {
            print("📝 尝试加载 \(fileName)...")
            let relationships = try FileManager.load([Relationship].self, from: fileName)
            print("✅ 成功加载 \(relationships.count) 个关系")
            return relationships
        } catch {
            print("⚠️ 加载 \(fileName) 失败：\(error.localizedDescription)")
            if (error as? FileError) == .fileNotFound {
                print("📝 文件不存在，返回空数组")
                return []
            }
            throw error
        }
    }
    
    // 实现缺少的协议方法
    func getPerson(by id: UUID) async throws -> Person? {
        let families = try await loadFamilies()
        for family in families {
            let persons = try await loadPersons(familyId: family.id)
            if let person = persons.first(where: { $0.id == id }) {
                return person
            }
        }
        return nil
    }
    
    func getAllPersons() async throws -> [Person] {
        let families = try await loadFamilies()
        var allPersons: [Person] = []
        for family in families {
            let persons = try await loadPersons(familyId: family.id)
            allPersons.append(contentsOf: persons)
        }
        return allPersons
    }
    
    func getRelationships(for personId: UUID) async throws -> [Relationship] {
        // 先找到这个人所属的家谱
        guard let person = try await getPerson(by: personId) else {
            throw DataError.personNotFound
        }
        
        let relationships = try await loadRelationships(familyId: person.familyId)
        return relationships.filter {
            $0.fromPerson == personId || $0.toPerson == personId
        }
    }
    
    func getAllRelationships() async throws -> [Relationship] {
        let families = try await loadFamilies()
        var allRelationships: [Relationship] = []
        for family in families {
            let relationships = try await loadRelationships(familyId: family.id)
            allRelationships.append(contentsOf: relationships)
        }
        return allRelationships
    }
    

}
