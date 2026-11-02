import Foundation

extension JSONValue {
    var asUserPublic: UserPublicDto? {
        guard case .object(let dict) = self,
              case .string(let id) = dict["id"],
              case .string(let name) = dict["name"] else { return nil }
        return UserPublicDto(id: id, name: name)
    }
}
