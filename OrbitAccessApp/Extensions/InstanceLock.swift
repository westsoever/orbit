import Darwin
import Foundation

enum InstanceLock {
    private static var fd: Int32 = -1

    /// Returns false when another process already holds the lock.
    static func acquire(at url: URL = OrbitPaths.accessAppLockURL) -> Bool {
        try? OrbitPaths.ensureOrbitDirectoryExists()
        let newFD = open(url.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard newFD >= 0 else { return true }
        if flock(newFD, LOCK_EX | LOCK_NB) != 0 {
            close(newFD)
            return false
        }
        fd = newFD
        return true
    }

    static func release() {
        guard fd >= 0 else { return }
        flock(fd, LOCK_UN)
        close(fd)
        fd = -1
    }
}
