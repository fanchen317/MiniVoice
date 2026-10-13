import SwiftUI

struct PlaylistAddPicker: View {
    @ObservedObject var collections: LibraryCollections
    let paths: [String]
    let detail: String
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("加入歌单").font(.title2.bold())
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text(detail).font(.callout).foregroundStyle(.secondary).lineLimit(2)
            if collections.playlists.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "music.note.list").font(.largeTitle)
                    Text("还没有歌单，可在下方新建并加入。")
                }.foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(collections.playlists) { playlist in
                    let existing = Set(playlist.paths)
                    let alreadyAdded = !paths.isEmpty && paths.allSatisfy { existing.contains($0) }
                    Button {
                        collections.add(paths, to: playlist.id)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "music.note.list").foregroundStyle(Color.accentColor)
                            Text(playlist.name).lineLimit(1)
                            Spacer()
                            if alreadyAdded {
                                Label("已在歌单中", systemImage: "checkmark").font(.caption).foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "plus.circle").foregroundStyle(Color.accentColor)
                            }
                        }.frame(maxWidth: .infinity, minHeight: 32).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(alreadyAdded || paths.isEmpty)
                        .accessibilityLabel(alreadyAdded ? "\(playlist.name)，已在歌单中" : "加入\(playlist.name)")
                }
            }
            Divider()
            HStack {
                TextField("新歌单名称", text: $newName).textFieldStyle(.roundedBorder)
                    .onSubmit(createAndAdd)
                Button("新建并加入", action: createAndAdd)
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || paths.isEmpty)
            }
        }.padding(20).frame(width: 420, height: 400)
    }

    private func createAndAdd() {
        guard !paths.isEmpty, let id = collections.createPlaylist(name: newName) else { return }
        collections.add(paths, to: id)
        dismiss()
    }
}
