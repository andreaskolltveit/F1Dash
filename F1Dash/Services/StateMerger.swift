import Foundation

/// Recursive deep-merge for F1 Live Timing partial updates.
///
/// F1 API sends sparse updates where:
/// - Dict + Dict → recursive merge of keys
/// - Array + Dict (with numeric string keys) → update array elements at those indices
/// - Anything else → replace
enum StateMerger {

    /// Merge an update into a base value.
    /// Returns the merged result.
    static func merge(base: Any?, update: Any?) -> Any? {
        guard let update = update else { return base }
        guard let base = base else { return update }

        // Dict + Dict → recursive key merge
        if let baseDict = base as? [String: Any],
           let updateDict = update as? [String: Any] {
            return mergeDict(base: baseDict, update: updateDict)
        }

        // Array + Dict → numeric string keys as array indices
        if var baseArray = base as? [Any],
           let updateDict = update as? [String: Any] {
            return mergeArrayWithDict(base: &baseArray, update: updateDict)
        }

        // Default: replace
        return update
    }

    // MARK: - Private

    private static func mergeDict(base: [String: Any], update: [String: Any]) -> [String: Any] {
        var result = base
        for (key, updateValue) in update {
            result[key] = merge(base: base[key], update: updateValue)
        }
        return result
    }

    private static func mergeArrayWithDict(base: inout [Any], update: [String: Any]) -> [Any] {
        for (key, value) in update {
            guard let index = Int(key) else { continue }
            // Extend array if needed
            while base.count <= index {
                base.append(NSNull())
            }
            base[index] = merge(base: base[index], update: value) as Any
        }
        return base
    }
}
