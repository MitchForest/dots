public import DotsDomain
public import Foundation
import DotsEngine

// MARK: - Proposals

/// Idea proposals live as committed JSON sidecars under
/// `.dots/proposals/` (see `.docs/target.md`); writes announce themselves
/// with a distributed notification so review surfaces — in this process or
/// another — update live.
extension VaultClient {
    static func addProposalEndpoints(to client: inout Self) {
        client.createProposal = { vault, sourceId, ideas in
            var generator = SystemRandomNumberGenerator()
            let now = Date()
            let id = ULID.generate(timestamp: now, using: &generator)
            let proposal = IdeaProposal(
                id: IdeaProposal.ID(id),
                sourceId: sourceId,
                ideas: ideas.enumerated().map { ProposedIdea(id: $0.offset + 1, text: $0.element) },
                createdAt: now
            )
            try Self.write(proposal: proposal, vault: vault)
            Self.postProposalsChanged()
            return proposal
        }
        client.listProposals = { vault in
            let directory = Self.proposalsDirectory(vault: vault)
            let urls = (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )) ?? []
            return urls.filter { $0.pathExtension == "json" }
                .compactMap { url in
                    (try? Data(contentsOf: url)).flatMap(ProposalFile.parse)
                }
                .sorted { $0.createdAt > $1.createdAt }
        }
        client.updateProposal = { vault, proposal in
            try Self.write(proposal: proposal, vault: vault)
            Self.postProposalsChanged()
        }
    }

    private static func proposalsDirectory(vault: URL) -> URL {
        vault.appending(path: VaultLayout.metadataDirectory).appending(path: "proposals")
    }

    private static func write(proposal: IdeaProposal, vault: URL) throws {
        let directory = proposalsDirectory(vault: vault)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try ProposalFile.render(proposal).write(
            to: directory.appending(path: "\(proposal.id.rawValue).json"),
            options: .atomic
        )
    }

    private static func postProposalsChanged() {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("blog.dots.proposals-changed"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
}
