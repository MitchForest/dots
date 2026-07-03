import ComposableArchitecture2

extension DebugSnapshotConvertible {
    /// Cross-module snapshot construction: the macro's memberwise snapshot
    /// init is internal, so tests convert a real State instead.
    var testSnapshot: DebugSnapshot {
        var visitor = _DebugSnapshotVisitor()
        return Self._debugSnapshot(self, visitor: &visitor)
    }
}
