import Foundation

enum RoutineStorage {
    private static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".orbit/routines.json")
    }

    static func load() -> [RoutineBlock] {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([RoutineBlock].self, from: data),
              !decoded.isEmpty else {
            return defaults
        }
        return decoded
    }

    static func save(_ routines: [RoutineBlock]) {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(routines) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private static var defaults: [RoutineBlock] {
        [
            RoutineBlock(id: "deep-work", title: "Deep work", startTime: "09:00", endTime: "12:00"),
            RoutineBlock(id: "admin", title: "Admin & email", startTime: "13:00", endTime: "14:00"),
            RoutineBlock(id: "collab", title: "Meetings", startTime: "14:00", endTime: "17:00"),
        ]
    }
}
