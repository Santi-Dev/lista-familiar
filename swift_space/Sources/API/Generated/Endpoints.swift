import Foundation

extension APIClient {
    func login(body: LoginDto) async throws -> AuthResponseDto {
        try await request(path: "/api/auth/login", method: "POST", body: body)
    }

    func me() async throws -> MeResponseDto {
        try await request(path: "/api/auth/me", method: "GET")
    }

    func create(body: CreateGroupDto) async throws -> FamilyGroupDto {
        try await request(path: "/api/family-groups", method: "POST", body: body)
    }

    func join(body: JoinGroupDto) async throws -> FamilyGroupDto {
        try await request(path: "/api/family-groups/join", method: "POST", body: body)
    }

    func leave() async throws -> SuccessDto {
        try await request(path: "/api/family-groups/leave", method: "POST")
    }

    func me() async throws -> FamilyGroupDto {
        try await request(path: "/api/family-groups/me", method: "GET")
    }

    func updateItem(id: String, body: UpdateItemDto) async throws -> ListItemDto {
        try await request(path: "/api/items/\(id)", method: "PATCH", body: body)
    }

    func deleteItem(id: String) async throws -> SuccessDto {
        try await request(path: "/api/items/\(id)", method: "DELETE")
    }

    func getLists(archived: String? = nil) async throws -> ListsResponseDto {
        try await request(path: "/api/lists", method: "GET", query: ["archived": archived])
    }

    func create(body: CreateListDto) async throws -> ShoppingListSummaryDto {
        try await request(path: "/api/lists", method: "POST", body: body)
    }

    func update(id: String, body: UpdateListDto) async throws -> ShoppingListSummaryDto {
        try await request(path: "/api/lists/\(id)", method: "PATCH", body: body)
    }

    func delete(id: String) async throws -> SuccessResponseDto {
        try await request(path: "/api/lists/\(id)", method: "DELETE")
    }

    func getListItems(id: String) async throws -> ListItemsResponseDto {
        try await request(path: "/api/lists/\(id)/items", method: "GET")
    }

    func createItem(id: String, body: CreateItemDto) async throws -> ListItemDto {
        try await request(path: "/api/lists/\(id)/items", method: "POST", body: body)
    }

    func signup(body: SignupDto) async throws -> AuthResponseDto {
        try await request(path: "/api/signup", method: "POST", body: body)
    }
}
