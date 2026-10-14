import SwiftUI
import AppKit

// MusicWallView.swift: native cover wall with a clock-driven player embedded in its active poster.
struct MusicWallView: View {
    @EnvironmentObject private var library: MusicLibrary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tracks: [Track]
    let groups: [(name: String, tracks: [Track])]
    let isGrouping: Bool
    let canGoBack: Bool
    let sidebarInset: CGFloat
    let sidebarBlocksWall: Bool
    let title: String
    @Binding var query: String
    let emptyMessage: String
    let isPreparing: Bool
    let onToggleSidebar: () -> Void
    let onOpenGroup: (String) -> Void
    let onBack: () -> Void
    let onEdit: (Track) -> Void
    let isFavorite: (Track) -> Bool
    let onFavorite: (Track) -> Void
    let onAddToPlaylist: (Track) -> Void
    @State private var showingTools = false
    @State private var focusedInstance: MusicWallInstance?
    @State private var focusedTrack: Track?
    @State private var immersive = false
    @State private var expandedPosterSide: CGFloat = 480
    @State private var toolsRaised = false
    @State private var hoveredID: String?
    @State private var pressingID: String?
    @StateObject private var cameraMotion = MusicWallCameraMotion()
    @State private var drag = CGSize.zero
    @State private var scene: MusicWallScene?
    @State private var mountedInstances: [MusicWallInstance] = []
    @State private var lastTapped: MusicWallInstance?
    @State private var reflowOriginFrames: [String: CGRect] = [:]
    @State private var reflowPreviousFocus: CGRect?
    @State private var reflowPreviousSize = CGSize.zero
    private var camera: CGSize {
        get { cameraMotion.offset }
        nonmutating set { cameraMotion.jump(to: newValue) }
    }
    private var tiles: [MusicWallTile] { scene?.tiles ?? [] }
    private var world: CGSize { scene?.world ?? .zero }
    private var horizontalStride: Int { scene?.horizontalStride ?? 1 }
    @State private var searchHovering = false
    @FocusState private var searchFocused: Bool

    private var posters: [Track] { isGrouping ? groups.compactMap { $0.tracks.first } : tracks }
    private var searchExpanded: Bool { searchHovering }

    var body: some View {
        GeometryReader { geometry in
            let offset = CGSize(width: camera.width + drag.width, height: camera.height + drag.height)
            let readyScene = scene?.count == posters.count ? scene! : MusicWallScene(count: posters.count, viewport: geometry.size, density: 1)
            let chrome = MusicWallChromeMetrics(width: geometry.size.width, leadingInset: sidebarInset)
            let zoom = cameraMotion.scale
            let sourceViewport = CGSize(width: geometry.size.width / zoom, height: geometry.size.height / zoom)
            let sourceOffset = CGSize(width: offset.width / zoom, height: offset.height / zoom)
            let mountKey = WallMountKey(x: Int(floor(sourceOffset.width / 192)), y: Int(floor(sourceOffset.height / 192)),
                viewport: sourceViewport, count: readyScene.count, focus: focusedInstance?.id)
            let instances = mountedInstances.isEmpty ? MusicWallCamera.visibleInstances(tiles: readyScene.tiles, world: readyScene.world,
                viewport: sourceViewport, offset: sourceOffset, focusedID: focusedInstance?.id) : mountedInstances
            ZStack(alignment: .topLeading) {
                Color(red: 0.09, green: 0.08, blue: 0.08)
                ZStack(alignment: .topLeading) {
                    ForEach(instances) { instance in
                        let rect = MusicWallReflow.frame(instance.frame, focus: focusedInstance?.frame,
                                                         size: expansionSize(viewport: geometry.size))
                        let displayed = renderedFrame(instance, viewport: geometry.size)
                        stagedPoster(instance, displayed: displayed, target: rect, viewport: geometry.size)
                            .position(x: displayed.midX, y: displayed.midY)
                            .accessibilityHidden(sidebarBlocksWall || !displayed
                                .applying(CGAffineTransform(scaleX: zoom, y: zoom))
                                .offsetBy(dx: offset.width, dy: offset.height)
                                .intersects(CGRect(x: sidebarInset, y: 80, width: max(0, geometry.size.width - sidebarInset), height: max(0, geometry.size.height - 80))))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .scaleEffect(zoom, anchor: .topLeading)
                .offset(offset)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .contentShape(Rectangle())
                .background {
                    MusicWallScrollInput(onPointer: { point in
                        guard let point, allowsPan(from: point, viewport: geometry.size, controls: false) else {
                            if hoveredID != nil { hoveredID = nil }; return
                        }
                        let next = hitInstance(at: point, instances: instances, viewport: geometry.size, offset: offset)?.id
                        if hoveredID != next { hoveredID = next }
                    }, onScroll: { delta, point in
                        guard allowsPan(from: point, viewport: geometry.size, controls: false) else { return false }
                        cameraMotion.pan(by: delta)
                        return true
                    }, onMagnify: { amount, point in
                        guard allowsPan(from: point, viewport: geometry.size) else { return false }
                        cameraMotion.zoom(to: cameraMotion.scale * (1 + amount), anchor: point, animated: false)
                        return true
                    }, onDown: { point, clicks in
                        guard allowsPan(from: point, viewport: geometry.size) else { return false }
                        cameraMotion.stop()
                        let hit = clicks > 1 ? lastTapped : hitInstance(at: point, instances: instances, viewport: geometry.size, offset: offset)
                        pressingID = hit?.id
                        return true
                    }, onDrag: { delta in
                        pressingID = nil; drag = delta
                    }, onUp: { point, clicks, dragged, velocity in
                        pressingID = nil
                        if dragged {
                            camera = CGSize(width: camera.width + drag.width, height: camera.height + drag.height)
                            drag = .zero
                            if !reduceMotion { cameraMotion.coast(velocity: velocity) }
                            return
                        }
                        let hit = clicks > 1 ? lastTapped : hitInstance(at: point, instances: instances, viewport: geometry.size, offset: offset)
                        guard let hit else { return }
                        let index = displayIndex(hit)
                        guard posters.indices.contains(index) else { return }
                        lastTapped = hit
                        if isGrouping { onOpenGroup(groups[index].name); return }
                        focus(hit, track: posters[index], viewport: geometry.size)
                        if clicks > 1 { startPlayback(posters[index]) }
                    })
                }
                if posters.isEmpty {
                    VStack(spacing: 16) {
                        if isPreparing { ProgressView().controlSize(.large) }
                        else { Image(systemName: "square.grid.3x3.fill").font(.system(size: 44)).foregroundStyle(.mint) }
                        Text(isPreparing ? "正在载入音乐库…" : emptyMessage).foregroundStyle(.white.opacity(0.7))
                        Button("打开设置") { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                header.padding(.leading, max(12, sidebarInset)).padding(.trailing, 12).padding(.top, 34)
                HStack(spacing: 8) {
                    if let track = library.playingTrack {
                        wallButton("scope", "定位正在播放") { focusTrack(track, viewport: geometry.size) }
                    }
                    wallButton("slider.horizontal.3", "音乐墙设置") { showingTools.toggle() }
                        .popover(isPresented: $showingTools) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("音乐墙").font(.headline)
                                HStack(spacing: 14) {
                                    Button { self.zoom(to: zoom / 1.2, viewport: geometry.size) } label: { Image(systemName: "minus.magnifyingglass") }
                                    Slider(value: Binding(get: { cameraMotion.scale }, set: {
                                        cameraMotion.zoom(to: $0, anchor: zoomAnchor(viewport: geometry.size), animated: false)
                                    }), in: 0.5...1.2)
                                    Button { self.zoom(to: zoom * 1.2, viewport: geometry.size) } label: { Image(systemName: "plus.magnifyingglass") }
                                }
                                Button("\(Int((zoom * 100).rounded()))% · 恢复原始比例") { self.zoom(to: 1, viewport: geometry.size) }
                                Text("拖拽或双向滚动浏览；双指捏合缩放；单击聚焦，双击播放。")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.padding(20).frame(width: 300)
                        }
                }
                .padding(.trailing, 16).padding(.bottom, toolsRaised || chrome.toolsAboveDock ? 104 : 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86), value: toolsRaised || chrome.toolsAboveDock)
                MusicWallDock(track: library.playingTrack ?? focusedTrack,
                              onPlay: { playFromDock() }, onLocate: {
                    if let track = library.playingTrack ?? focusedTrack { focusTrack(track, viewport: geometry.size) }
                })
                    .frame(width: chrome.dockWidth)
                    .padding(.bottom, 18).padding(.leading, sidebarInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                if immersive, let track = focusedTrack ?? library.playingTrack {
                    MusicWallPlayer(track: track, onPlay: { play(track) }, onExpand: { immersive = false })
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay(alignment: .topTrailing) {
                            wallButton("xmark", "返回音乐墙") { immersive = false }.padding(.top, 40).padding(.trailing, 20)
                        }.transition(.opacity)
                }
            }
            .clipped().environment(\.colorScheme, .dark)
            .onChange(of: mountKey) { _ in
                mountedInstances = MusicWallCamera.visibleInstances(tiles: readyScene.tiles, world: readyScene.world,
                    viewport: sourceViewport, offset: sourceOffset, focusedID: focusedInstance?.id)
            }
            .onAppear { rebuild(viewport: geometry.size); toolsRaised = chrome.toolsAboveDock }
            .onChange(of: chrome.toolsAboveDock) { above in toolsRaised = above }
            .onChange(of: geometry.size) { size in rebuild(viewport: size) }
            .onChange(of: sidebarInset) { _ in
                if let current = focusedInstance, let track = focusedTrack { focus(current, track: track, viewport: geometry.size) }
            }
            .onChange(of: posters.map(\.id)) { _ in rebuild(viewport: geometry.size) }
            .onChange(of: library.playingID) { _ in
                if let track = library.playingTrack { focusTrack(track, viewport: geometry.size) }
            }
            .onChange(of: library.tracksRevision) { _ in
                if let id = focusedTrack?.id, let updated = library.track(for: id) { focusedTrack = updated }
            }
            .onExitCommand {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                    immersive = false; focusedInstance = nil; focusedTrack = nil; showingTools = false
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            wallButton("sidebar.left", "打开侧边栏", action: onToggleSidebar)
            if title != "音乐库" {
                Text(title).font(.headline).lineLimit(1).padding(.horizontal, 14).padding(.vertical, 10)
                    .modifier(MusicWallGlass())
            }
            if canGoBack { wallButton("chevron.left", "返回", action: onBack) }
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                Button { searchHovering = true; searchFocused = true } label: {
                    Image(systemName: "magnifyingglass").font(.system(size: 22)).frame(width: 38, height: 38)
                }.buttonStyle(.plain).accessibilityLabel("搜索音乐")
                TextField("搜索音乐", text: $query).textFieldStyle(.plain).focused($searchFocused)
                    .frame(width: searchExpanded ? 126 : 0).opacity(searchExpanded ? 1 : 0)
                    .clipped().allowsHitTesting(searchExpanded).accessibilityHidden(!searchExpanded)
                if !query.isEmpty && searchExpanded {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).padding(.trailing, 10)
                }
            }
            .padding(.trailing, searchExpanded ? 12 : 0)
            .modifier(MusicWallGlass())
            .onHover { inside in
                searchHovering = inside
                if !inside { searchFocused = false }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86), value: searchExpanded)
        }
    }

    @ViewBuilder private func stagedPoster(_ instance: MusicWallInstance, displayed: CGRect, target: CGRect, viewport: CGSize) -> some View {
        let index = displayIndex(instance)
        if posters.indices.contains(index) {
            ZStack {
                // The artwork follows the actual intermediate bounds, always using
                // aspect fill. Only the lightweight chrome transforms during reflow.
                MusicWallCover(track: posters[index]).equatable()
                    .frame(width: displayed.width, height: displayed.height).clipped()
                canvasPoster(instance, frame: target, viewport: viewport)
                    .scaleEffect(x: displayed.width / target.width, y: displayed.height / target.height)
            }
            .frame(width: displayed.width, height: displayed.height).clipped()
            .scaleEffect(reduceMotion ? 1 : pressingID == instance.id ? 0.96 : hoveredID == instance.id && focusedInstance?.id != instance.id ? 1.025 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8), value: hoveredID == instance.id)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: pressingID == instance.id)
        }
    }

    @ViewBuilder private func canvasPoster(_ instance: MusicWallInstance, frame: CGRect, viewport: CGSize) -> some View {
        let index = displayIndex(instance)
        if posters.indices.contains(index) {
            let track = posters[index]
            let expanded = focusedInstance?.id == instance.id
            let size = frame.size
            ZStack {
                MusicWallPoster(track: track, title: isGrouping ? groups[index].name : track.title,
                                subtitle: isGrouping ? "\(groups[index].tracks.count) 首歌曲" : track.artist,
                                number: index + 1, size: size, showsArtwork: false)
                    .equatable()
                    .opacity(expanded ? 0 : 1)
                    .allowsHitTesting(!expanded)
                if expanded, !isGrouping, library.playingID == track.id {
                    MusicWallPlayer(track: track.id == library.playingID ? (library.playingTrack ?? track) : (focusedTrack ?? track),
                                    onPlay: { play(track) }, onExpand: { immersive = true }, showsArtwork: false)
                        .equatable()
                        .transition(.opacity)
                } else if expanded, !isGrouping {
                    MusicWallPreview(track: track, onPlay: { startPlayback(track) }, onExpand: { immersive = true })
                        .transition(.opacity)
                }
            }
            .frame(width: size.width, height: size.height).clipped()
            .overlay {
                Rectangle().strokeBorder(library.playingID == track.id ? Color.mint.opacity(0.85) : .white.opacity(expanded ? 0.8 : hoveredID == instance.id ? 0.95 : 0), lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
            .brightness(hoveredID == instance.id && !expanded ? 0.12 : 0)
            .shadow(color: .black.opacity(hoveredID == instance.id ? 0.4 : 0), radius: hoveredID == instance.id ? 8 : 0, y: 4)
            
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78), value: hoveredID == instance.id)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: pressingID == instance.id)
            .contentShape(Rectangle())
            .accessibilityElement(children: .contain)
            .accessibilityLabel("聚焦 \(track.title)，双击播放")
            .accessibilityAction(named: "聚焦") { focus(instance, track: track, viewport: viewport) }
            .accessibilityAction(named: "播放") { focus(instance, track: track, viewport: viewport); startPlayback(track) }
            .contextMenu {
                if isGrouping { Button("打开") { onOpenGroup(groups[index].name) } }
                else {
                    Button("聚焦") { focus(instance, track: track, viewport: viewport) }
                    Button("播放") { focus(instance, track: track, viewport: viewport); startPlayback(track) }
                    Button(isFavorite(track) ? "取消收藏" : "收藏") { onFavorite(track) }
                    Button("添加到歌单") { onAddToPlaylist(track) }
                    Button("歌曲信息") { onEdit(track) }
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: expanded)
        }
    }

    private func zoomAnchor(viewport: CGSize) -> CGPoint {
        CGPoint(x: (viewport.width + sidebarInset) / 2, y: viewport.height / 2)
    }
    private func zoom(to scale: CGFloat, viewport: CGSize) {
        cameraMotion.zoom(to: scale, anchor: zoomAnchor(viewport: viewport), animated: !reduceMotion)
    }

    private func renderedFrame(_ instance: MusicWallInstance, viewport: CGSize) -> CGRect {
        let target = MusicWallReflow.frame(instance.frame, focus: focusedInstance?.frame, size: expansionSize(viewport: viewport))
        guard cameraMotion.reflowProgress < 1 else { return target }
        let origin = reflowOriginFrames[instance.id] ?? MusicWallReflow.frame(instance.frame,
            focus: reflowPreviousFocus, size: reflowPreviousSize)
        return MusicWallReflow.interpolate(origin, target, progress: cameraMotion.reflowProgress)
    }

    private func hitInstance(at point: CGPoint, instances: [MusicWallInstance], viewport: CGSize, offset: CGSize) -> MusicWallInstance? {
        instances.first { instance in
            renderedFrame(instance, viewport: viewport)
                .applying(CGAffineTransform(scaleX: cameraMotion.scale, y: cameraMotion.scale))
                .offsetBy(dx: offset.width, dy: offset.height).contains(point)
        }
    }

    private func expansionSize(viewport: CGSize) -> CGSize {
        let side = min(expandedPosterSide, viewport.width - sidebarInset - 40, viewport.height - 150)
        return CGSize(width: max(260, side), height: max(320, side))
    }

    private func rebuild(viewport: CGSize) {
        scene = MusicWallScene(count: posters.count, viewport: viewport, density: 1)
        let width = scene?.world.width ?? viewport.width
        if let id = focusedTrack?.id, posters.contains(where: { $0.id == id }), let track = focusedTrack {
            focusTrack(track, viewport: viewport)
        } else {
            focusedTrack = nil; focusedInstance = nil
            camera = CGSize(width: -(width - viewport.width) / 2, height: -80)
        }
    }

    private func focus(_ instance: MusicWallInstance, track: Track, viewport: CGSize) {
        let changesFocus = focusedInstance?.id != instance.id
        if changesFocus {
            let scale = cameraMotion.scale
            let mounted = MusicWallCamera.visibleInstances(tiles: tiles, world: world,
                viewport: CGSize(width: viewport.width / scale, height: viewport.height / scale),
                offset: CGSize(width: camera.width / scale, height: camera.height / scale), focusedID: focusedInstance?.id)
            let previous = Dictionary(uniqueKeysWithValues: mounted.map { ($0.id, renderedFrame($0, viewport: viewport)) })
            reflowOriginFrames = previous
            reflowPreviousFocus = focusedInstance?.frame
            reflowPreviousSize = expansionSize(viewport: viewport)
            expandedPosterSide = min(520, max(320, (viewport.height - 150) * 0.85))
        }
        focusedInstance = instance; focusedTrack = track
        if changesFocus { cameraMotion.beginReflow(animated: !reduceMotion) }
        let target = MusicWallCamera.centeredOffset(frame: instance.frame, viewport: viewport, leadingInset: sidebarInset, scale: cameraMotion.scale)
        if reduceMotion { camera = target } else { cameraMotion.travel(to: target) }
        Task {
            let resolved = await library.resolveTrack(track.id)
            if focusedTrack?.id == track.id { focusedTrack = resolved ?? track }
        }
    }

    private func displayIndex(_ instance: MusicWallInstance) -> Int {
        MusicWallSequence.index(base: instance.tile.index, horizontalCopy: instance.copyX,
                                stride: horizontalStride, count: posters.count) ?? 0
    }
    private func focusTrack(_ track: Track, viewport: CGSize) {
        guard !isGrouping, let index = posters.firstIndex(where: { $0.id == track.id }) else { return }
        // Preserve the instance actually clicked, including horizontally advanced copies.
        if let current = focusedInstance, displayIndex(current) == index,
           let tile = tiles.first(where: { $0.id == current.tile.id }) {
            let frame = tile.frame.offsetBy(dx: CGFloat(current.copyX) * world.width, dy: CGFloat(current.copyY) * world.height)
            focus(MusicWallInstance(tile: tile, copyX: current.copyX, copyY: current.copyY, frame: frame), track: track, viewport: viewport)
            return
        }
        let center = CGPoint(x: ((viewport.width + sidebarInset) / 2 - camera.width) / cameraMotion.scale,
                             y: (viewport.height / 2 - camera.height) / cameraMotion.scale)
        let centralCopy = Int(floor(center.x / max(1, world.width)))
        var nearest: MusicWallInstance?
        var nearestDistance = CGFloat.infinity
        for x in (centralCopy - 1)...(centralCopy + 1) {
            for tile in tiles {
                guard MusicWallSequence.index(base: tile.index, horizontalCopy: x,
                    stride: horizontalStride, count: posters.count) == index else { continue }
                let y = Int(((center.y - tile.frame.midY) / max(1, world.height)).rounded())
                let frame = tile.frame.offsetBy(dx: CGFloat(x) * world.width, dy: CGFloat(y) * world.height)
                let distance = hypot(frame.midX - center.x, frame.midY - center.y)
                if distance < nearestDistance {
                    nearestDistance = distance
                    nearest = MusicWallInstance(tile: tile, copyX: x, copyY: y, frame: frame)
                }
            }
        }
        if let nearest { focus(nearest, track: track, viewport: viewport) }
    }
    private func allowsPan(from point: CGPoint, viewport: CGSize, controls: Bool = true) -> Bool {
        guard !immersive else { return false }
        guard !sidebarBlocksWall, point.x >= sidebarInset, point.y > 28 else { return false }
        if point.y < 80 {
            let leftControls = sidebarInset + (canGoBack ? 128 : 64)
            let rightControls = viewport.width - (searchExpanded ? 220 : 60)
            if point.x < leftControls || point.x > rightControls { return false }
        }
        let chrome = MusicWallChromeMetrics(width: viewport.width, leadingInset: sidebarInset)
        let dock = CGRect(x: (viewport.width + sidebarInset - chrome.dockWidth) / 2,
                          y: viewport.height - 82, width: chrome.dockWidth, height: 64)
        let tools = CGRect(x: viewport.width - 112, y: viewport.height - (toolsRaised || chrome.toolsAboveDock ? 104 : 20) - 44, width: 96, height: 44)
        if dock.insetBy(dx: -4, dy: -4).contains(point) || tools.insetBy(dx: -4, dy: -4).contains(point) { return false }
        if controls, let instance = focusedInstance {
            // Use the displayed bounds, including in-flight reflow and drag.
            // Leave the entire lower control region to native SwiftUI controls.
            let rect = renderedFrame(instance, viewport: viewport)
                .applying(CGAffineTransform(scaleX: cameraMotion.scale, y: cameraMotion.scale))
                .offsetBy(dx: camera.width + drag.width, dy: camera.height + drag.height)
            let controls = CGRect(x: rect.minX, y: rect.maxY - 160 * cameraMotion.scale,
                                  width: rect.width, height: 160 * cameraMotion.scale)
            if controls.contains(point) { return false }
        }
        return true
    }
    private func startPlayback(_ track: Track) {
        if library.playingID == track.id { if !library.isPlaying { library.play() } }
        else { library.play(track.id, in: tracks.map(\.id)) }
    }
    private func play(_ track: Track) {
        if library.playingID == track.id { library.togglePlayback() }
        else { library.play(track.id, in: tracks.map(\.id)) }
    }
    private func playFromDock() {
        if let playing = library.playingTrack { play(playing) }
        else if let track = focusedTrack { play(track) }
    }
    private func wallButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 22, weight: .medium))
                .frame(width: 38, height: 38).modifier(MusicWallGlass())
        }.buttonStyle(.plain).help(help).accessibilityLabel(help)
    }
}


private struct WallMountKey: Equatable {
    let x: Int
    let y: Int
    let viewport: CGSize
    let count: Int
    let focus: String?
}
