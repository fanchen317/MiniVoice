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
    @Binding var sidebarVisible: Bool
    let toolsLeadingInset: CGFloat
    let sidebarInset: CGFloat
    private var focusLeadingInset: CGFloat { sidebarInset }
    let sidebarBlocksWall: Bool
    let title: String
    let sortingControls: AnyView
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
    @State private var reloadOpacity = 1.0
    @State private var reloadTask: Task<Void, Never>?
    @State private var focusedInstance: MusicWallInstance?
    @State private var focusedTrack: Track?
    @State private var immersive = false
    @State private var sidebarBeforeImmersive: Bool?
    @State private var expansionTransitioning = false
    @State private var expansionTask: Task<Void, Never>?
    @State private var chromeVisible = true
    @State private var cameraBeforeImmersive: CGSize?
    @State private var immersiveSourceID: String?
    @State private var expandedPosterSide: CGFloat = 480
    @State private var hoveredID: String?
    @State private var pressingID: String?
    @StateObject private var cameraMotion = MusicWallCameraMotion()
    private var drag: CGSize {
        get { cameraMotion.dragOffset }
        nonmutating set { cameraMotion.dragOffset = newValue }
    }
    @State private var scene: MusicWallScene?
    @State private var sceneRevision = 0
    @State private var mountedInstances: [MusicWallInstance] = []
    @State private var lastTapped: MusicWallInstance?
    @State private var lastTapPoint: CGPoint?
    @State private var pressedPoint: CGPoint?
    @State private var pressedInstance: MusicWallInstance?
    @State private var controlRegionStore = MusicWallControlRegionStore()
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
    private var posters: [Track] { isGrouping ? groups.compactMap { $0.tracks.first } : tracks }

    var body: some View {
        GeometryReader { geometry in
            let offset = CGSize(width: camera.width + drag.width, height: camera.height + drag.height)
            let readyScene = scene?.count == posters.count ? scene! : MusicWallScene(count: posters.count, viewport: geometry.size, density: 1)
            let chrome = MusicWallChromeMetrics(width: geometry.size.width, leadingInset: sidebarInset, toolsLeadingInset: toolsLeadingInset)
            let zoom = cameraMotion.scale
            let sourceViewport = CGSize(width: geometry.size.width / zoom, height: geometry.size.height / zoom)
            let sourceOffset = CGSize(width: offset.width / zoom, height: offset.height / zoom)
            // Keep mounted SwiftUI geometry near the viewport. Very distant world
            // coordinates can be culled before the outer translation is applied.
            let renderOrigin = CGSize(width: floor(sourceOffset.width / 192) * 192 * zoom,
                                      height: floor(sourceOffset.height / 192) * 192 * zoom)
            let mountKey = WallMountKey(x: Int(floor(sourceOffset.width / 192)), y: Int(floor(sourceOffset.height / 192)),
                viewport: sourceViewport, count: readyScene.count, focus: focusedInstance?.id,
                settledRevision: cameraMotion.settledRevision)
            let instances = mountedInstances.isEmpty ? readyScene.visibleInstances(
                viewport: sourceViewport, offset: sourceOffset, focusedID: focusedInstance?.id) : mountedInstances
            ZStack(alignment: .topLeading) {
                Color(red: 0.09, green: 0.08, blue: 0.08)
                WallPosterLayer(key: WallPosterLayerKey(ids: instances.map(\.id), songOrder: posters.map(\.id), focus: focusedInstance?.id,
                    hovered: hoveredID, pressed: pressingID, playing: library.playingID,
                    revision: library.tracksRevision, sceneRevision: sceneRevision,
                    settledRevision: cameraMotion.settledRevision, viewport: geometry.size, scale: zoom,
                    expansion: expansionSize(viewport: geometry.size), renderOrigin: renderOrigin,
                    blocked: sidebarBlocksWall, reducedMotion: reduceMotion, grouping: isGrouping)) {
                  MusicWallReflowContent(motion: cameraMotion.reflow) { _ in
                   ZStack(alignment: .topLeading) {
                    ForEach(instances) { instance in
                        let rect = MusicWallReflow.mosaicFrame(instance.frame, focus: focusedInstance?.frame,
                                                         size: expansionSize(viewport: geometry.size))
                        let displayed = renderedFrame(instance, viewport: geometry.size)
                            .applying(CGAffineTransform(scaleX: zoom, y: zoom))
                            .offsetBy(dx: renderOrigin.width, dy: renderOrigin.height)
                        stagedPoster(instance, displayed: displayed, target: rect, viewport: geometry.size)
                            .position(x: displayed.midX, y: displayed.midY)
                            .zIndex(focusedInstance?.id == instance.id ? 2 : hoveredID == instance.id ? 1 : 0)
                            .accessibilityHidden(sidebarBlocksWall)
                    }
                  }
                  .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                  }
                }
                .equatable()
                .opacity(reloadOpacity)
                .modifier(MusicWallTranslationModifier(translation: cameraMotion.translation, relativeTo: renderOrigin))
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .contentShape(Rectangle())
                .background {
                    MusicWallScrollInput(onPointer: { point in
                        guard let point, allowsPan(from: point, viewport: geometry.size) else {
                            if hoveredID != nil { hoveredID = nil }; return
                        }
                        let liveOffset = CGSize(width: camera.width + drag.width, height: camera.height + drag.height)
                        let next = hitInstance(at: point, instances: instances, viewport: geometry.size, offset: liveOffset)?.id
                        if hoveredID != next { hoveredID = next }
                    }, onScroll: { delta, point, precise in
                        guard allowsPan(from: point, viewport: geometry.size, includingButtons: true) else { return false }
                        if precise { cameraMotion.pan(by: delta) }
                        else { cameraMotion.wheel(by: delta) }
                        return true
                    }, onMagnify: { amount, point in
                        guard allowsPan(from: point, viewport: geometry.size, includingButtons: true) else { return false }
                        cameraMotion.zoom(to: cameraMotion.scale * (1 + amount), anchor: point, animated: false)
                        return true
                    }, onDown: { point, clicks in
                        let repeated = MusicWallClickTarget.isContinuation(clicks: clicks, point: point, previous: lastTapPoint)
                            ? lastTapped : nil
                        guard !immersive, !sidebarBlocksWall, point.x >= sidebarInset,
                              repeated != nil || allowsPan(from: point, viewport: geometry.size, includingButtons: true) else { return .none }
                        let buttonDown = repeated == nil && controlRegionStore.draggableRegions.contains { $0.contains(point) }
                        if repeated == nil { cameraMotion.freezeForInteraction() }
                        let liveOffset = CGSize(width: camera.width + drag.width, height: camera.height + drag.height)
                        let hit = repeated ?? hitInstance(at: point, instances: instances, viewport: geometry.size, offset: liveOffset)
                        pressedInstance = hit
                        pressedPoint = point
                        pressingID = buttonDown ? nil : hit?.id
                        return buttonDown ? .button : .wall
                    }, onDrag: { delta in
                        if drag == .zero { cameraMotion.freezeForInteraction() }
                        pressingID = nil; drag = delta
                    }, onUp: { point, clicks, dragged, velocity in
                        pressingID = nil
                        let hit = pressedInstance
                        pressedInstance = nil
                        if dragged {
                            lastTapped = nil; lastTapPoint = nil
                            camera = CGSize(width: camera.width + drag.width, height: camera.height + drag.height)
                            drag = .zero
                            if !reduceMotion { cameraMotion.coast(velocity: velocity) }
                            return
                        }
                        guard let hit else { return }
                        let doubleClick = clicks > 1 && lastTapped?.id == hit.id
                        let index = displayIndex(hit)
                        guard posters.indices.contains(index) else { return }
                        lastTapped = hit
                        lastTapPoint = pressedPoint
                        if isGrouping { onOpenGroup(groups[index].name); return }
                        if !doubleClick || focusedInstance?.id != hit.id {
                            focus(hit, track: posters[index], viewport: geometry.size)
                        }
                        if doubleClick { startPlayback(posters[index]) }
                    })
                }
                // Interactive content lives in viewport coordinates. World-space posters
                // can be visible outside their original layout bounds after camera travel;
                // putting buttons there makes native hit testing miss the visible controls.
                if !isGrouping, let instance = focusedInstance {
                    let index = displayIndex(instance)
                    if posters.indices.contains(index), posters[index].id == focusedTrack?.id {
                        let track = posters[index]
                        MusicWallReflowContent(motion: cameraMotion.reflow) { _ in
                        let rect = renderedFrame(instance, viewport: geometry.size)
                            .applying(CGAffineTransform(scaleX: zoom, y: zoom))
                            .offsetBy(dx: renderOrigin.width, dy: renderOrigin.height)
                        let playerSize = immersive ? geometry.size : CGSize(
                            width: expansionSize(viewport: geometry.size).width * zoom,
                            height: expansionSize(viewport: geometry.size).height * zoom)
                        Group {
                            if immersive || expansionTransitioning || library.playingID == track.id {
                                MusicWallPlayer(track: library.playingID == track.id ? (library.playingTrack ?? track) : (focusedTrack ?? track),
                                    onPlay: { play(track) }, onExpand: { setImmersive(!immersive, viewport: geometry.size) },
                                    isFavorite: isFavorite(track), onFavorite: { onFavorite(track) },
                                    showsArtwork: immersive || expansionTransitioning, isExpanded: immersive)
                            } else {
                                MusicWallPreview(track: focusedTrack ?? track, onPlay: { startPlayback(track) })
                            }
                        }
                        // Keep one mounted player for both directions. Removing the full
                        // player made its return fade out while the card target was moving.
                        // Lay out lyrics and controls once at their destination size.
                        // Reflow only transforms them, avoiding text layout every frame.
                        .frame(width: playerSize.width, height: playerSize.height)
                        .scaleEffect(x: immersive ? 1 : rect.width / playerSize.width,
                                     y: immersive ? 1 : rect.height / playerSize.height)
                        .frame(width: immersive ? geometry.size.width : rect.width,
                               height: immersive ? geometry.size.height : rect.height)
                        .contentShape(Rectangle())
                        .contextMenu { posterMenu(instance, track: track, index: index, viewport: geometry.size) }
                        .position(x: immersive ? geometry.size.width / 2 : rect.midX,
                                  y: immersive ? geometry.size.height / 2 : rect.midY)
                        .modifier(MusicWallTranslationModifier(translation: cameraMotion.translation, enabled: !immersive, relativeTo: renderOrigin))
                        .zIndex(immersive || expansionTransitioning ? 10 : 0)
                        .allowsHitTesting(immersive || !sidebarBlocksWall)
                        }
                        .zIndex(immersive || expansionTransitioning ? 10 : 0)
                    }
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
                    .allowsHitTesting(chromeVisible)
                HStack(spacing: 8) {
                    wallButton("slider.horizontal.3", "音乐墙设置", isActive: showingTools) { showingTools.toggle() }
                        .popover(isPresented: $showingTools, arrowEdge: .bottom) {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack {
                                        Text("音乐墙").font(.headline)
                                        Spacer()
                                        Button { showingTools = false } label: {
                                            Image(systemName: "xmark").frame(width: 24, height: 24)
                                        }.buttonStyle(MusicWallControlStyle()).help("关闭设置")
                                    }
                                    HStack {
                                        Text("显示比例").foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(Int((zoom * 100).rounded()))%")
                                            .monospacedDigit().fontWeight(.semibold)
                                    }.font(.subheadline)
                                    HStack(spacing: 12) {
                                        Button { self.zoom(to: zoom / 1.2, viewport: geometry.size) } label: {
                                            Image(systemName: "minus.magnifyingglass").frame(width: 28, height: 28)
                                        }.buttonStyle(MusicWallControlStyle()).disabled(zoom <= 0.801).help("缩小")
                                        Slider(value: Binding(get: { cameraMotion.scale }, set: {
                                            cameraMotion.zoom(to: $0, anchor: zoomAnchor(viewport: geometry.size), animated: false)
                                        }), in: 0.8...1.2).tint(.mint).help("显示比例")
                                        Button { self.zoom(to: zoom * 1.2, viewport: geometry.size) } label: {
                                            Image(systemName: "plus.magnifyingglass").frame(width: 28, height: 28)
                                        }.buttonStyle(MusicWallControlStyle()).disabled(zoom >= 1.199).help("放大")
                                    }
                                    Button { self.zoom(to: 1, viewport: geometry.size) } label: {
                                        Label("恢复 100%", systemImage: "arrow.counterclockwise")
                                            .font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 5)
                                    }.buttonStyle(MusicWallControlStyle()).disabled(abs(zoom - 1) < 0.001)
                                    Divider().padding(.vertical, 2)
                                    Label("列表排序", systemImage: "arrow.up.arrow.down").font(.headline)
                                    sortingControls
                                }.padding(18)
                            }
                            .frame(width: min(300, max(240, geometry.size.width - 32)),
                                   height: min(520, max(280, geometry.size.height - 90)))
                            .background(Color(red: 0.12, green: 0.14, blue: 0.14))
                            .environment(\.colorScheme, .dark).foregroundStyle(.white)
                            .onExitCommand { showingTools = false }
                        }
                }
                .padding(.trailing, 16).padding(.bottom, chrome.toolsBottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86), value: chrome.toolsAboveDock)
                .offset(y: chromeVisible ? 0 : 120)
                .opacity(chromeVisible ? 1 : 0)
                .allowsHitTesting(chromeVisible)
                .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88), value: chromeVisible)
                MusicWallDock(track: library.playingTrack ?? focusedTrack,
                              onPlay: { playFromDock() }, onLocate: {
                    if let track = library.playingTrack ?? focusedTrack { focusTrack(track, viewport: geometry.size) }
                })
                    .frame(width: chrome.dockWidth)
                    .padding(.bottom, 18).padding(.leading, sidebarInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(y: chromeVisible ? 0 : 110)
                    .opacity(chromeVisible ? 1 : 0)
                    .allowsHitTesting(chromeVisible)
                    .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88), value: chromeVisible)

            }
            .coordinateSpace(name: "musicWallViewport")
            .onPreferenceChange(MusicWallControlRegions.self) { regions in
                let visible = regions.filter { !$0.isEmpty && !$0.isNull && $0.intersects(CGRect(origin: .zero, size: geometry.size)) }
                controlRegionStore.regions = visible
            }
            .onPreferenceChange(MusicWallDraggableControlRegions.self) { regions in
                controlRegionStore.draggableRegions = regions.filter { !$0.isEmpty && !$0.isNull }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .ignoresSafeArea()
            .clipped().environment(\.colorScheme, .dark)
            .onChange(of: mountKey) { _ in
                let next = readyScene.visibleInstances(
                    viewport: sourceViewport, offset: sourceOffset, focusedID: focusedInstance?.id)
                if mountedInstances.map(\.id) != next.map(\.id) {
                    mountedInstances = next
                }
            }
            .onAppear { reloadOpacity = 1; rebuild(viewport: geometry.size) }
            .onChange(of: geometry.size) { size in rebuild(viewport: size) }
            .onChange(of: sidebarInset) { newInset in
                guard !immersive, !expansionTransitioning, let current = focusedInstance else { return }
                // Use the value delivered by onChange. Re-entering focus through
                // the captured view can use the previous sidebar layout on its first toggle.
                let target = MusicWallCamera.centeredOffset(frame: current.frame, viewport: geometry.size,
                    leadingInset: newInset, scale: cameraMotion.scale)
                if reduceMotion { camera = target }
                else { cameraMotion.travel(to: target, duration: 0.32) }
            }
            .onChange(of: posters.map(\.id)) { _ in
                reloadTask?.cancel()
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { reloadOpacity = 0.55 }
                rebuild(viewport: geometry.size)
                reloadTask = Task { @MainActor in
                    do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { reloadOpacity = 1 }
                }
            }
            .onChange(of: library.playingID) { _ in
                if let track = library.playingTrack, focusedTrack?.id != track.id {
                    focusTrack(track, viewport: geometry.size)
                }
            }
            .onChange(of: library.tracksRevision) { _ in
                if let id = focusedTrack?.id, let updated = library.track(for: id) { focusedTrack = updated }
            }
            .onDisappear {
                expansionTask?.cancel()
                reloadTask?.cancel()
                if let previous = sidebarBeforeImmersive { sidebarVisible = previous; sidebarBeforeImmersive = nil }
            }
            .onExitCommand {
                if immersive { setImmersive(false, viewport: geometry.size) }
                else if sidebarVisible { onToggleSidebar() }
                else {
                    focusedInstance = nil; focusedTrack = nil; showingTools = false
                }
            }
            .background(MusicWallEscapeHandler(isActive: immersive) {
                setImmersive(false, viewport: geometry.size)
            })
        }
    }

    private func setImmersive(_ expanded: Bool, viewport: CGSize) {
        guard immersive != expanded else { return }
        expansionTask?.cancel()
        expansionTransitioning = true
        if expanded { chromeVisible = false }
        cameraMotion.stop()
        withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.9)) {
            if expanded {
                cameraBeforeImmersive = camera
                immersiveSourceID = focusedInstance?.id
                sidebarBeforeImmersive = sidebarVisible
                sidebarVisible = false
            } else if let previous = sidebarBeforeImmersive {
                sidebarVisible = previous
                sidebarBeforeImmersive = nil
                if let previousCamera = cameraBeforeImmersive {
                    let sideWidth = min(260, max(230, viewport.width * 0.25))
                    let restoredInset: CGFloat = previous && viewport.width >= sideWidth + 640 + 48 ? sideWidth + 24 : 0
                    cameraMotion.jump(to: MusicWallCamera.restoredPlayerOffset(original: previousCamera,
                        sourceID: immersiveSourceID, targetID: focusedInstance?.id, targetFrame: focusedInstance?.frame,
                        viewport: viewport, leadingInset: restoredInset, scale: cameraMotion.scale))
                }
                cameraBeforeImmersive = nil
                immersiveSourceID = nil
            }
            immersive = expanded
        }
        expansionTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 1 : 600)) } catch { return }
            expansionTransitioning = false
            if !immersive { chromeVisible = true }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
          HStack(spacing: 10) {
            wallButton("sidebar.left", "打开侧边栏", isActive: sidebarVisible, action: onToggleSidebar)
            if title != "音乐库" {
                Text(title).font(.headline).lineLimit(1).padding(.horizontal, 14).padding(.vertical, 10)
                    .modifier(MusicWallGlass())
            }
            if canGoBack { wallButton("chevron.left", "返回", action: onBack) }
          }
          .offset(x: chromeVisible ? 0 : -90).opacity(chromeVisible ? 1 : 0)
          .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88), value: chromeVisible)
            Spacer(minLength: 0)
            MusicWallSearchField(query: $query)
                .offset(x: chromeVisible ? 0 : 90).opacity(chromeVisible ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88), value: chromeVisible)
        }
    }

    @ViewBuilder private func stagedPoster(_ instance: MusicWallInstance, displayed: CGRect, target: CGRect, viewport: CGSize) -> some View {
        let index = displayIndex(instance)
        if posters.indices.contains(index) {
            ZStack {
                // The artwork follows the actual intermediate bounds, always using
                // aspect fill. Only the lightweight chrome transforms during reflow.
                MusicWallCover(track: posters[index], prefersThumbnail: focusedInstance?.id != instance.id).equatable()
                    .id(posters[index].id)
                    .frame(width: displayed.width, height: displayed.height).clipped()
                canvasPoster(instance, frame: target, viewport: viewport)
                    .scaleEffect(x: displayed.width / target.width, y: displayed.height / target.height)
                    .frame(width: displayed.width, height: displayed.height)
            }
            .frame(width: displayed.width, height: displayed.height).clipped()
            // Stroke the final visible bounds after artwork clipping. A stroke inside
            // the scaled chrome is cropped whenever its layout bounds differ in reflow.
            .overlay {
                Rectangle().strokeBorder(library.playingID == posters[index].id ? Color.mint.opacity(0.85)
                    : .white.opacity(hoveredID == instance.id ? 0.95 : 0),
                    lineWidth: library.playingID == posters[index].id ? 3 : 1.5)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .contextMenu { posterMenu(instance, track: posters[index], index: index, viewport: viewport) }
            .brightness(!isGrouping && library.playingID != nil && library.playingID != posters[index].id ? -0.12 : 0)
            .shadow(color: library.playingID == posters[index].id ? .mint.opacity(0.5) : .clear, radius: 14)
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

            }
            .frame(width: size.width, height: size.height).clipped()

            .brightness(hoveredID == instance.id && !expanded ? 0.12 : 0)
            
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78), value: hoveredID == instance.id)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: pressingID == instance.id)
            .contentShape(Rectangle())
            .accessibilityElement(children: .contain)
            .accessibilityLabel("聚焦 \(track.title)，双击播放")
            .accessibilityAction(named: "聚焦") { focus(instance, track: track, viewport: viewport) }
            .accessibilityAction(named: "播放") { focus(instance, track: track, viewport: viewport); startPlayback(track) }

            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: expanded)
        }
    }

    @ViewBuilder private func posterMenu(_ instance: MusicWallInstance, track: Track, index: Int, viewport: CGSize) -> some View {
        if isGrouping {
            Button("打开") { onOpenGroup(groups[index].name) }
        } else {
            Button("聚焦") { focus(instance, track: track, viewport: viewport) }
            Button("播放") { focus(instance, track: track, viewport: viewport); startPlayback(track) }
            Button(isFavorite(track) ? "取消收藏" : "收藏") { onFavorite(track) }
            Button("添加到歌单") { onAddToPlaylist(track) }
            Button("歌曲信息") { onEdit(track) }
        }
    }

    private func zoomAnchor(viewport: CGSize) -> CGPoint {
        CGPoint(x: (viewport.width + focusLeadingInset) / 2, y: viewport.height / 2)
    }
    private func zoom(to scale: CGFloat, viewport: CGSize) {
        cameraMotion.zoom(to: scale, anchor: zoomAnchor(viewport: viewport), animated: !reduceMotion)
    }

    private func renderedFrame(_ instance: MusicWallInstance, viewport: CGSize) -> CGRect {
        let target = MusicWallReflow.mosaicFrame(instance.frame, focus: focusedInstance?.frame, size: expansionSize(viewport: viewport))
        guard cameraMotion.reflowProgress < 1 else { return target }
        let origin = reflowOriginFrames[instance.id] ?? MusicWallReflow.mosaicFrame(instance.frame,
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
        sceneRevision += 1
        mountedInstances = []
        if let id = focusedTrack?.id, posters.contains(where: { $0.id == id }), let track = focusedTrack {
            focusTrack(track, viewport: viewport)
        } else {
            focusedTrack = nil; focusedInstance = nil
            camera = CGSize(width: sidebarInset + 12, height: 80)
        }
    }

    private func focus(_ instance: MusicWallInstance, track: Track, viewport: CGSize) {
        let changesFocus = focusedInstance?.id != instance.id || cameraMotion.reflowProgress < 1
        cameraMotion.freezeForInteraction()
        if changesFocus {
            let scale = cameraMotion.scale
            let mounted = scene?.visibleInstances(
                viewport: CGSize(width: viewport.width / scale, height: viewport.height / scale),
                offset: CGSize(width: camera.width / scale, height: camera.height / scale), focusedID: focusedInstance?.id) ?? []
            // Include every currently drawn card, even when culling has not caught
            // up with the last camera frame, plus the incoming focus instance.
            var previous = Dictionary(uniqueKeysWithValues: mounted.map { ($0.id, renderedFrame($0, viewport: viewport)) })
            for visible in mountedInstances + [instance] {
                previous[visible.id] = renderedFrame(visible, viewport: viewport)
            }
            reflowOriginFrames = previous
            reflowPreviousFocus = focusedInstance?.frame
            reflowPreviousSize = expansionSize(viewport: viewport)
            expandedPosterSide = min(520, max(320, (viewport.height - 150) * 0.85))
        }
        if changesFocus { cameraMotion.beginReflow(animated: !reduceMotion) }
        focusedInstance = instance; focusedTrack = track
        let target = MusicWallCamera.centeredOffset(frame: instance.frame, viewport: viewport, leadingInset: focusLeadingInset, scale: cameraMotion.scale)
        // Make destination neighbours available before the camera gets there.
        if let scene {
            let scale = cameraMotion.scale
            let destination = scene.visibleInstances(
                viewport: CGSize(width: viewport.width / scale, height: viewport.height / scale),
                offset: CGSize(width: target.width / scale, height: target.height / scale), focusedID: instance.id)
            var reserved = Dictionary(uniqueKeysWithValues: mountedInstances.map { ($0.id, $0) })
            for card in destination { reserved[card.id] = card }
            mountedInstances = reserved.values.sorted { $0.id < $1.id }
        }
        if reduceMotion { camera = target } else { cameraMotion.travel(to: target, duration: 0.48) }
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
        let center = CGPoint(x: ((viewport.width + focusLeadingInset) / 2 - camera.width) / cameraMotion.scale,
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
    private func allowsPan(from point: CGPoint, viewport: CGSize, includingButtons: Bool = false) -> Bool {
        guard !immersive else { return false }
        guard !controlRegionStore.regions.contains(where: { $0.contains(point) }) else { return false }
        guard includingButtons || !controlRegionStore.draggableRegions.contains(where: { $0.contains(point) }) else { return false }
        guard !sidebarBlocksWall, point.x >= sidebarInset, point.y > 28 else { return false }
        let chrome = MusicWallChromeMetrics(width: viewport.width, leadingInset: sidebarInset)
        let dock = CGRect(x: (viewport.width + sidebarInset - chrome.dockWidth) / 2,
                          y: viewport.height - 82, width: chrome.dockWidth, height: 64)
        if dock.contains(point) { return false }
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
    private func wallButton(_ symbol: String, _ help: String, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 22, weight: .medium))
                .frame(width: 38, height: 38).modifier(MusicWallGlass())
        }.buttonStyle(MusicWallFloatingButtonStyle(isActive: isActive))
            .background(MusicWallInputExclusion()).help(help).accessibilityLabel(help)
    }
}

/// Search owns its hover animation so expanding the field does not rebuild the wall.
private struct MusicWallSearchField: View {
    @Binding var query: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false
    @State private var expanded = false
    @State private var revealTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 0) {
            Button {
                revealTask?.cancel()
                expanded = true
                focused = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22)).frame(width: 38, height: 38)
            }
            .buttonStyle(MusicWallFloatingButtonStyle(isActive: hovered))
            .accessibilityLabel("搜索音乐")
            TextField("搜索音乐", text: $query)
                .textFieldStyle(.plain).focused($focused)
                .frame(width: expanded ? 126 : 0)
                .opacity(expanded ? 1 : 0)
                .clipped().allowsHitTesting(expanded).accessibilityHidden(!expanded)
            if !query.isEmpty && expanded {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).padding(.trailing, 10)
            }
        }
        .padding(.trailing, expanded ? 12 : 0)
        .modifier(MusicWallGlass())
        .background(MusicWallInputExclusion())
        .onHover { inside in
            guard hovered != inside else { return }
            hovered = inside
            revealTask?.cancel()
            if inside {
                revealTask = Task { @MainActor in
                    do { try await Task.sleep(for: .milliseconds(reduceMotion ? 1 : 140)) } catch { return }
                    expanded = true
                }
            } else {
                focused = false
                expanded = false
            }
        }
        .onDisappear { revealTask?.cancel() }
        .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.94), value: expanded)
    }
}


// Camera translation deliberately stays outside this subtree. Cover geometry,
// captions and context menus only rebuild when their own inputs change.
private struct WallPosterLayer<Content: View>: View, @MainActor Equatable {
    let key: WallPosterLayerKey
    @ViewBuilder let content: () -> Content
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.key == rhs.key }
    var body: some View { content() }
}

private struct WallPosterLayerKey: Equatable {
    let ids: [String]
    let songOrder: [UUID]
    let focus: String?
    let hovered: String?
    let pressed: String?
    let playing: UUID?
    let revision: Int
    let sceneRevision: Int
    let settledRevision: Int
    let viewport: CGSize
    let scale: CGFloat
    let expansion: CGSize
    let renderOrigin: CGSize
    let blocked: Bool
    let reducedMotion: Bool
    let grouping: Bool
}

private struct WallMountKey: Equatable {
    let x: Int
    let y: Int
    let viewport: CGSize
    let count: Int
    let focus: String?
    let settledRevision: Int
}
