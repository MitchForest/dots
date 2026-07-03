import DotsUI
import SwiftUI

/// The organizing column: All · Inbox · the writer's folders. Folders are
/// real vault directories; this is just a lens onto them. Model-blind.
struct FolderColumnView: View {
    let folders: [String]
    @Binding var selection: Ideas.FolderSelection
    let onCreateFolder: (String) -> Void

    @State private var isNamingFolder = false
    @State private var newFolderName = ""

    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    row(title: "All ideas", icon: "tray.full", target: .all)
                    row(title: "Inbox", icon: "tray", target: .inbox)

                    if !folders.isEmpty {
                        DotsMetaLabel("FOLDERS")
                            .padding(.horizontal, DotsSpacing.sm)
                            .padding(.top, DotsSpacing.lg)
                            .padding(.bottom, DotsSpacing.xs)

                        ForEach(folders, id: \.self) { folder in
                            row(title: folder, icon: "folder", target: .folder(folder))
                        }
                    }
                }
                .padding(DotsSpacing.sm)
            }

            Spacer(minLength: 0)

            newFolderControl
                .padding(DotsSpacing.sm)
        }
        .frame(width: 176)
        .background(DotsColor.Background.elevated)
    }

    private func row(title: String, icon: String, target: Ideas.FolderSelection) -> some View {
        let isActive = selection == target
        return Button {
            selection = target
        } label: {
            HStack(spacing: DotsSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isActive ? DotsColor.brand : DotsColor.Ink.muted)
                    .frame(width: 14)
                Text(title)
                    .font(DotsTypography.callout)
                    .foregroundStyle(DotsColor.Ink.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DotsSpacing.sm)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: DotsRadius.Semantic.control, style: .continuous)
                    .fill(isActive ? DotsColor.Surface.pressed : .clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: DotsRadius.Semantic.control, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var newFolderControl: some View {
        if isNamingFolder {
            TextField("Folder name", text: $newFolderName)
                .textFieldStyle(.plain)
                .font(DotsTypography.callout)
                .foregroundStyle(DotsColor.Ink.primary)
                .focused($isNameFocused)
                .padding(.horizontal, DotsSpacing.sm)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: DotsRadius.Semantic.control, style: .continuous)
                        .fill(DotsColor.Surface.control)
                )
                .onSubmit {
                    let name = newFolderName.trimmingCharacters(in: .whitespaces)
                    isNamingFolder = false
                    newFolderName = ""
                    if !name.isEmpty {
                        onCreateFolder(name)
                    }
                }
                .onKeyPress(.escape) {
                    isNamingFolder = false
                    newFolderName = ""
                    return .handled
                }
        } else {
            Button {
                isNamingFolder = true
                isNameFocused = true
            } label: {
                Label("New folder", systemImage: "plus")
                    .font(DotsTypography.footnote)
                    .foregroundStyle(DotsColor.Ink.muted)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DotsSpacing.sm)
            .help("Create a folder (a real directory in your vault)")
        }
    }
}
