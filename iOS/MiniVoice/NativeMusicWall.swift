import UIKit
import ImageIO

/// iOS-only rendering boundary. No WebKit/React callbacks occur on scroll frames.
@MainActor
final class NativeMusicWall: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    struct Item: Equatable {
        let id: String
        let title: String
        let artist: String
        let artwork: String?
        let detailArtwork: String?
        let version: String
    }
    var emit: (([String: Any]) -> Void)?
    var captureFocus: ((CGRect) -> UIView?)?
    private var movingContent: UIView?
    private var preparedContent: UIView?
    private var motionEpoch = 0
    private var motionActive = false
    private var preferredFocusSide: CGFloat = 300
    private var isPlaying = false
    private(set) var session = ""
    private(set) var active = false
    var webRegions: [CGRect] = []
    private let scroll = UIScrollView()
    private let canvas = UIView()
    private let focusPoster = NativeWallPoster()
    private let images = NativeWallImages()
    private var posters: [String: NativeWallPoster] = [:]
    private var recycled: [NativeWallPoster] = []
    private var scene = WeightedWallScene(count: 0)
    private var items: [Item] = []
    private var focus: WeightedWallScene.Instance?
    private var focusedID = ""
    private var playingID = ""
    private var expanded = false
    private var blocked = false
    private var grouped = false
    private var reduced = false
    private var configured = false
    private var applying = false
    private var locating = false
    private var focusAnimating = false
    private var focusAnimator: UIViewPropertyAnimator?
    private var previousLayout: (focus: CGRect?, size: CGSize)?
    private var viewportCenter = CGPoint.zero
    private var focusSide: CGFloat = 300
    private var lastLocation = 0
    private var lastTap: (id: String, time: TimeInterval)?
    private var savedCamera = WallCamera(offset: CGPoint(x: 12, y: 80), scale: 1)
    // Bounded, non-rasterized container; only viewport-visible image views are attached.
    private let origin: CGFloat = 100_000
    private var worldSize: CGFloat { origin * 2 }
    private var camera: WallCamera {
        WallCamera(offset: CGPoint(x: origin * scroll.zoomScale - scroll.contentOffset.x,
                                   y: origin * scroll.zoomScale - scroll.contentOffset.y), scale: scroll.zoomScale)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        backgroundColor = UIColor(red: 0.055, green: 0.098, blue: 0.082, alpha: 1)
        accessibilityIdentifier = "ios-native-wall"
        scroll.accessibilityIdentifier = "ios-native-wall-scroll"
        scroll.accessibilityLabel = "音乐墙画布"
        scroll.delegate = self
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.minimumZoomScale = 0.6
        scroll.maximumZoomScale = 1.2
        scroll.bouncesZoom = false
        scroll.isDirectionalLockEnabled = false
        scroll.decelerationRate = .normal
        canvas.frame = CGRect(x: 0, y: 0, width: worldSize, height: worldSize)
        canvas.backgroundColor = .clear
        scroll.addSubview(canvas)
        scroll.contentSize = canvas.bounds.size
        addSubview(scroll)
        focusPoster.isHidden = true
        // The focused artwork is a visual layer. Touches reach the scroll view underneath.
        focusPoster.isUserInteractionEnabled = false
        focusPoster.isAccessibilityElement = false
        addSubview(focusPoster)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.delegate = self
        addGestureRecognizer(tap)
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
        hold.delegate = self
        addGestureRecognizer(hold)
        NotificationCenter.default.addObserver(self, selector: #selector(flush), name: UIApplication.willResignActiveNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func acceptsCanvasTouch(_ point: CGPoint) -> Bool {
        // Once a finger starts on the canvas, its second finger belongs to that gesture,
        // even if it lands over a web control. New gestures still respect web hit regions.
        active && !blocked && bounds.contains(point) &&
            ((scroll.isTracking || scroll.isDragging || scroll.isZooming) || !webRegions.contains(where: { $0.contains(point) }))
    }

    func geometry(_ value: [String: Any]) {
        guard value["session"] as? String == session,
              let b = Self.rect(value["bounds"]), b.width > 0, b.height > 0 else { return }
        reduced = value["reduceMotion"] as? Bool == true || UIAccessibility.isReduceMotionEnabled
        if reduced && focusAnimating { interrupt(); render(); showFocus(animated: false) }
        // The original wall keeps dark gutters in both themes; only chrome changes theme.
        backgroundColor = UIColor(red: 14/255, green: 25/255, blue: 21/255, alpha: 1)
        let changed = bounds.size != b.size
        frame = b
        scroll.frame = bounds
        scroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webRegions = (value["regions"] as? [[String: Any]] ?? []).compactMap(Self.rect).map {
            $0.offsetBy(dx: -b.minX, dy: -b.minY)
        }
        let previousCenter = viewportCenter, previousSide = focusSide
        if let v = value["viewport"] as? [String: Any] {
            viewportCenter = CGPoint(x: Self.number(v["x"], fallback: bounds.midX), y: Self.number(v["y"], fallback: bounds.midY))
            focusSide = Self.number(v["side"], fallback: 300)
        }
        guard configured else { return }
        if changed || previousCenter != viewportCenter || previousSide != focusSide {
            interrupt()
            applyCamera(savedCamera)
            if focus != nil { preferredFocusSide = focusSide; locate(animated: false) }
        }
        render()
        publishSurface(visible: !scroll.isDragging && !scroll.isDecelerating && !focusAnimating)
    }

    func configure(_ value: [String: Any], items newItems: [Item]?) {
        let incoming = value["session"] as? String ?? ""
        let newSession = session != incoming
        if newSession { detach(); session = incoming; configured = false; lastLocation = 0 }
        active = true
        isHidden = false
        let oldID = focusedID
        let oldExpanded = expanded
        let next = newItems ?? items
        let changedItems = newItems.map { items != $0 } ?? false
        if changedItems {
            interrupt()
            items = next
            scene = WeightedWallScene(count: next.count)
            focus = nil
            for poster in posters.values { poster.removeFromSuperview() }
            posters.removeAll(); recycled.removeAll()
        }
        focusedID = value["focused"] as? Bool == true ? (value["current"] as? String ?? "") : ""
        playingID = value["playingId"] as? String ?? ""
        isPlaying = value["playing"] as? Bool == true
        expanded = value["expanded"] as? Bool == true
        grouped = value["grouped"] as? Bool == true
        reduced = value["reduceMotion"] as? Bool == true || UIAccessibility.isReduceMotionEnabled
        let wasBlocked = blocked
        blocked = value["blocked"] as? Bool == true
        scroll.isScrollEnabled = !blocked && !expanded
        if blocked && !wasBlocked { interrupt(); flush() }
        if !configured {
            let raw = value["camera"] as? [String: Any] ?? [:]
            let restoredScale = Self.number(raw["scale"], fallback: 1)
            savedCamera = WallCamera(offset: CGPoint(x: Self.number(raw["x"], fallback: 12), y: Self.number(raw["y"], fallback: 80)), scale: restoredScale > 0 ? restoredScale : 1)
            applyCamera(savedCamera)
            configured = true
            event(["kind": "scale", "scale": camera.scale])
            if let rawFocus = raw["focus"] as? [String: Any], rawFocus["songId"] as? String == focusedID,
               let index = items.firstIndex(where: { $0.id == focusedID }) {
                focus = instance(index: index, column: Int(Self.number(rawFocus["column"], fallback: 0)), row: Int(Self.number(rawFocus["row"], fallback: 0)))
            }
        }
        let location = value["location"] as? Int ?? 0
        let mustLocate = location != lastLocation
        lastLocation = location
        if focusedID.isEmpty {
            clearFocus(animated: !changedItems)
        } else if changedItems || oldID != focusedID || mustLocate || focus == nil {
            if oldID != focusedID || focus == nil {
                previousLayout = (focus?.frame, focusSize)
                preferredFocusSide = focusSide
            }
            if mustLocate { focus = nearest(id: focusedID) }
            let restored = newSession && focus != nil
            if focus == nil || focus.map({ items[$0.tile.index].id != focusedID }) == true {
                focus = nearest(id: focusedID)
            }
            if restored { render(); showFocus(animated: false) }
            else { locate(animated: !newSession && !changedItems) }
        } else if expanded != oldExpanded {
            showFocus(animated: true)
        }
        render()
        publishSurface(visible: !focusAnimating && !scroll.isDragging && !scroll.isDecelerating)
    }

    func command(_ value: [String: Any]) {
        guard value["session"] as? String == session else { return }
        switch value["kind"] as? String {
        case "interrupt": interrupt(); render(); publishSurface(visible: true); flush()
        case "zoom":
            interrupt()
            let next = camera.zoomed(to: Self.number(value["scale"], fallback: 1), around: CGPoint(x: bounds.midX, y: bounds.midY))
            applyCamera(next); render(); showFocus(animated: false); flush()
        case "surfaceReady":
            guard value["epoch"] as? Int == motionEpoch, !motionActive, !focusAnimating else { return }
            movingContent?.removeFromSuperview(); movingContent = nil
            preparedContent = focus == nil ? nil : captureFocus?(focusPoster.frame)
        case "flush": flush()
        case "detach": detach()
        default: break
        }
    }

    func detach() {
        interrupt()
        if active { flush() }
        active = false; configured = false; isHidden = true
        focus = nil; focusPoster.isHidden = true
        movingContent?.removeFromSuperview(); movingContent = nil; preparedContent = nil
        motionActive = false; motionEpoch += 1
        items.removeAll(); posters.values.forEach { $0.removeFromSuperview() }; posters.removeAll(); recycled.removeAll()
        images.cancel()
    }

    private func applyCamera(_ next: WallCamera) {
        applying = true
        let scale = min(1.2, max(0.6, next.scale))
        scroll.setZoomScale(scale, animated: false)
        scroll.setContentOffset(CGPoint(x: origin * scale - next.offset.x, y: origin * scale - next.offset.y), animated: false)
        applying = false
        savedCamera = camera
    }

    private func instance(index: Int, column: Int, row: Int) -> WeightedWallScene.Instance {
        let tile = scene.tiles[index]
        // Persisted repeat coordinates are untrusted and bounded to the scroll container.
        let c = max(-100, min(100, column)), r = max(-100, min(100, row))
        return .init(tile: tile, column: c, row: r, frame: tile.frame.offsetBy(dx: CGFloat(c) * scene.width, dy: CGFloat(r) * scene.height))
    }

    private func nearest(id: String) -> WeightedWallScene.Instance? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        let tile = scene.tiles[index], c = camera
        let world = CGPoint(x: (viewportCenter.x - c.offset.x) / c.scale, y: (viewportCenter.y - c.offset.y) / c.scale)
        return instance(index: index, column: Int(((world.x - tile.frame.midX) / scene.width).rounded()), row: Int(((world.y - tile.frame.midY) / scene.height).rounded()))
    }

    private func projected(_ frame: CGRect) -> CGRect {
        let c = camera
        return CGRect(x: c.offset.x + frame.minX * c.scale, y: c.offset.y + frame.minY * c.scale,
                      width: frame.width * c.scale, height: frame.height * c.scale)
    }

    private var focusSize: CGSize {
        let scale = camera.scale
        let side = max(min(preferredFocusSide, focusSide / max(1, scale)), min(240, focusSide) / scale)
        return CGSize(width: side, height: side)
    }

    private func reflowed(_ frame: CGRect) -> CGRect {
        NativeWallReflow.frame(frame, focus: focus?.frame, size: focusSize)
    }

    private func focusFrame() -> CGRect {
        guard let focus else { return .zero }
        return expanded ? bounds : projected(reflowed(focus.frame))
    }

    private func retainMovingContent() {
        guard movingContent == nil, !focusPoster.isHidden, !focusPoster.frame.isEmpty,
              let snapshot = captureFocus?(focusPoster.frame) ?? preparedContent else { return }
        preparedContent = nil
        snapshot.frame = focusPoster.bounds
        snapshot.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        snapshot.isUserInteractionEnabled = false
        snapshot.accessibilityElementsHidden = true
        focusPoster.addSubview(snapshot)
        movingContent = snapshot
    }

    private func locate(animated: Bool) {
        guard let focus else { publishSurface(visible: false); return }
        interrupt()
        publishSurface(visible: false)
        let c = camera
        let target = WallCamera(offset: CGPoint(x: viewportCenter.x - focus.frame.midX * c.scale,
                                                y: viewportCenter.y - focus.frame.midY * c.scale), scale: c.scale)
        // Long-distance locate is a direct jump, avoiding traversing unmounted library regions.
        let nearby = hypot(target.offset.x - c.offset.x, target.offset.y - c.offset.y) < max(bounds.width, bounds.height) * 1.5
        // Each new song starts from its own poster, never the previous song's square.
        let from = posters[focus.id].map { canvas.convert($0.frame, to: self) } ?? projected(focus.frame)
        movingContent?.removeFromSuperview(); movingContent = nil; preparedContent = nil
        configurePoster(focusPoster, index: focus.tile.index, detail: true)
        focusPoster.frame = from; focusPoster.isHidden = false
        if animated && !reduced && nearby {
            locating = true; focusAnimating = true
            let animator = UIViewPropertyAnimator(duration: 0.38, curve: .easeInOut) {
                self.applyCamera(target)
                self.render()
                self.focusPoster.frame = self.focusFrame()
            }
            focusAnimator = animator
            animator.addCompletion { [weak self, weak animator] _ in
                guard let self, self.focusAnimator === animator else { return }
                self.focusAnimator = nil; self.locating = false; self.focusAnimating = false
                self.previousLayout = nil
                self.render(); self.publishSurface(visible: true); self.flush()
            }
            animator.startAnimation()
        } else {
            applyCamera(target); previousLayout = nil; render(); showFocus(animated: false); flush()
        }
    }

    private func clearFocus(animated: Bool) {
        guard let old = focus else { return }
        interrupt()
        previousLayout = (old.frame, focusSize)
        focus = nil
        movingContent?.removeFromSuperview(); movingContent = nil
        publishSurface(visible: false)
        guard animated && !reduced else {
            previousLayout = nil; focusPoster.isHidden = true; render(); return
        }
        focusAnimating = true
        let animator = UIViewPropertyAnimator(duration: 0.3, curve: .easeInOut) {
            self.render()
            self.focusPoster.frame = self.projected(old.frame)
        }
        focusAnimator = animator
        animator.addCompletion { [weak self, weak animator] _ in
            guard let self, self.focusAnimator === animator else { return }
            self.focusAnimator = nil; self.focusAnimating = false; self.previousLayout = nil
            self.focusPoster.isHidden = true; self.render(); self.flush()
        }
        animator.startAnimation()
    }

    private func showFocus(animated: Bool) {
        guard let focus else { return }
        configurePoster(focusPoster, index: focus.tile.index, detail: true)
        focusPoster.isHidden = false
        let target = focusFrame()
        preparedContent = nil
        if animated && !reduced {
            interruptFocus()
            focusAnimating = true; publishSurface(visible: false)
            let animator = UIViewPropertyAnimator(duration: 0.36, curve: .easeInOut) { self.focusPoster.frame = target }
            focusAnimator = animator
            animator.addCompletion { [weak self, weak animator] _ in
                guard let self, self.focusAnimator === animator else { return }
                self.focusAnimator = nil; self.focusAnimating = false
                self.publishSurface(visible: true); self.flush()
            }
            animator.startAnimation()
        } else {
            focusPoster.frame = target; publishSurface(visible: true)
        }
    }

    private func interruptFocus() {
        let visibleFrame = focusPoster.layer.presentation()?.frame
        let posterFrames = focusAnimator == nil ? [:] : posters.compactMapValues { $0.layer.presentation()?.frame }
        focusAnimator?.stopAnimation(true); focusAnimator = nil
        for (id, frame) in posterFrames { posters[id]?.frame = frame }
        if let visibleFrame { focusPoster.frame = visibleFrame }
        focusAnimating = false
    }

    func interrupt() {
        // Read presentation state before cancelling: a new drag starts at the visible position.
        let visibleOffset = scroll.layer.presentation()?.bounds.origin
        interruptFocus()
        applying = true
        if locating, let visibleOffset { scroll.setContentOffset(visibleOffset, animated: false) }
        locating = false
        scroll.setContentOffset(scroll.contentOffset, animated: false)
        applying = false
        savedCamera = camera
    }

    private func render() {
        guard active, configured, !applying, bounds.width > 0 else { return }
        let c = camera
        var visible = scene.visibleReflow(camera: c, viewport: bounds.size, focus: focus?.frame, size: focusSize, overscan: max(520, min(900, max(bounds.width, bounds.height))))
        if let previousLayout {
            let previous = scene.visibleReflow(camera: c, viewport: bounds.size, focus: previousLayout.focus, size: previousLayout.size, overscan: max(520, min(900, max(bounds.width, bounds.height))))
            let ids = Set(visible.map(\.id)); visible += previous.filter { !ids.contains($0.id) }
        }
        visible.sort {
            let a = projected(reflowed($0.frame)), b = projected(reflowed($1.frame))
            if a.intersects(bounds) != b.intersects(bounds) { return a.intersects(bounds) }
            return hypot(a.midX - bounds.midX, a.midY - bounds.midY) < hypot(b.midX - bounds.midX, b.midY - bounds.midY)
        }
        let ids = Set(visible.map(\.id))
        // Retain the start viewport while UIKit interpolates to the nearby target.
        for id in Array(posters.keys) where !locating && !ids.contains(id) {
            if let view = posters.removeValue(forKey: id) {
                view.removeFromSuperview(); view.reuse(); if recycled.count < 80 { recycled.append(view) }
            }
        }
        for cell in visible {
            let view: NativeWallPoster
            if let existing = posters[cell.id] { view = existing }
            else {
                view = recycled.popLast() ?? NativeWallPoster()
                let from = NativeWallReflow.frame(cell.frame, focus: previousLayout?.focus, size: previousLayout?.size ?? focusSize)
                UIView.performWithoutAnimation {
                    view.frame = from.offsetBy(dx: origin, dy: origin)
                    canvas.addSubview(view); view.layoutIfNeeded()
                }
                posters[cell.id] = view
            }
            view.accessibilityIdentifier = "native-wall-cell-" + cell.id
            view.frame = reflowed(cell.frame).offsetBy(dx: origin, dy: origin)
            configurePoster(view, index: cell.tile.index, detail: cell.id == focus?.id)
            images.prioritize(key: view.resource, visible: projected(reflowed(cell.frame)).intersects(bounds))
            // Keep the source poster beneath the independent square; hiding a large
            // tessellation cell would leave an uncovered hole around the smaller card.
            view.isHidden = false
            view.isAccessibilityElement = cell.id != focus?.id
            view.activate = { [weak self] in self?.select(cell, double: false) }
        }
        images.retain(keys: Set(posters.values.map(\.resource)).union(focusPoster.isHidden ? [] : [focusPoster.resource]))
        if focus != nil && !focusAnimating { focusPoster.frame = focusFrame(); focusPoster.layoutIfNeeded() }
    }

    private func configurePoster(_ view: NativeWallPoster, index: Int, detail: Bool = false) {
        guard items.indices.contains(index) else { return }
        let item = items[index]
        let thumbnailKey = item.id + "|" + item.version + "|" + (item.artwork ?? "")
        let path = detail ? (item.detailArtwork ?? item.artwork) : item.artwork
        let key = detail ? thumbnailKey + "|display|" + (path ?? "") : thumbnailKey
        CATransaction.begin(); CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        if !motionActive && !focusAnimating, let ready = view.pendingImage { view.setArtwork(ready); view.pendingImage = nil }
        view.caption.text = detail ? nil : item.title
        view.artist.text = detail ? nil : item.artist
        view.shade.isHidden = detail
        view.captionGradient.isHidden = detail
        view.setNeedsLayout()
        view.accessibilityLabel = item.title + "，" + item.artist
        view.accessibilityTraits = item.id == playingID ? [.button, .selected] : .button
        view.layer.borderWidth = item.id == playingID && !(detail && expanded) ? 3 / (detail && view === focusPoster ? 1 : camera.scale) : 0
        view.layer.borderColor = UIColor(red: 50/255, green: 216/255, blue: 181/255, alpha: isPlaying ? 1 : 0.8).cgColor
        // Keep a decoded display image when the same cell stops being focused.
        // Downgrading it during a pan creates a visible texture change.
        if view.resource == key || (!detail && view.resource.hasPrefix(thumbnailKey + "|display|")) { return }
        let retained = view.resource.hasPrefix(thumbnailKey) ? view.image.image : nil
        view.resource = key
        view.pendingImage = nil
        view.setArtwork(retained ?? images.cached(key: thumbnailKey))
        guard let path else { return }
        images.load(path: path, key: key, pixels: detail ? 1280 : 384) { [weak self, weak view] image in
            guard let self, let view, view.resource == key else { return }
            if (self.motionActive || self.focusAnimating) && view.image.image != nil {
                view.pendingImage = image
            } else { view.setArtwork(image) }
        }
    }

    private func publishSurface(visible: Bool) {
        let shown = visible && focus != nil && !focusAnimating && !motionActive
        let r = focusPoster.frame
        event(["kind": "surface", "epoch": motionEpoch, "visible": shown, "id": focus.map { items[$0.tile.index].id } ?? "",
               "rect": ["x": r.minX, "y": r.minY, "width": r.width, "height": r.height], "scale": camera.scale])
    }
    private func event(_ value: [String: Any]) { var payload = value; payload["session"] = session; emit?(payload) }
    @objc func flush() {
        guard active, configured else { return }
        savedCamera = camera
        scroll.accessibilityValue = "缩放 \(Int((savedCamera.scale * 100).rounded()))%"
        var value: [String: Any] = ["x": savedCamera.offset.x, "y": savedCamera.offset.y, "scale": savedCamera.scale]
        if let focus { value["focus"] = ["songId": items[focus.tile.index].id, "column": focus.column, "row": focus.row] }
        event(["kind": "camera", "camera": value])
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { canvas }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !applying else { return }
        render()
    }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        motionEpoch += 1; motionActive = true
        retainMovingContent(); interrupt(); lastTap = nil; publishSurface(visible: false)
    }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { settled() }
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { settled() }
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        motionEpoch += 1; motionActive = true
        retainMovingContent(); interrupt(); lastTap = nil; publishSurface(visible: false)
    }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { if !applying { render() } }
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        event(["kind": "scale", "scale": scale]); settled()
    }
    private func settled() {
        guard !locating, !scroll.isZooming else { return }
        motionActive = false
        // Rebase only after a gesture ends, keeping native deceleration uninterrupted.
        var c = camera
        let limit = origin * c.scale * 0.4
        let dx = abs(c.offset.x) > limit ? Int((c.offset.x / (scene.width * c.scale)).rounded()) : 0
        let dy = abs(c.offset.y) > limit ? Int((c.offset.y / (scene.height * c.scale)).rounded()) : 0
        if dx != 0 || dy != 0 {
            c.offset.x -= CGFloat(dx) * scene.width * c.scale
            c.offset.y -= CGFloat(dy) * scene.height * c.scale
            if let old = focus { focus = instance(index: old.tile.index, column: old.column + dx, row: old.row + dy) }
            applyCamera(c)
        }
        render(); publishSurface(visible: true); flush()
    }
    private func cell(at point: CGPoint) -> WeightedWallScene.Instance? {
        let visibleFocus = focusPoster.layer.presentation()?.frame ?? focusPoster.frame
        if let focus, !focusPoster.isHidden, visibleFocus.contains(point) { return focus }
        var c = camera
        if locating, let offset = scroll.layer.presentation()?.bounds.origin {
            c.offset = CGPoint(x: origin * c.scale - offset.x, y: origin * c.scale - offset.y)
        }
        if focusAnimating {
            for (id, view) in posters where !view.isHidden {
                let frame = view.layer.presentation()?.frame ?? view.frame
                let rect = CGRect(x: c.offset.x + (frame.minX - origin) * c.scale,
                                  y: c.offset.y + (frame.minY - origin) * c.scale,
                                  width: frame.width * c.scale, height: frame.height * c.scale)
                let parts = id.split(separator: ":").compactMap { Int($0) }
                if rect.contains(point), parts.count == 3, scene.tiles.indices.contains(parts[0]) {
                    return instance(index: parts[0], column: parts[1], row: parts[2])
                }
            }
        }
        return scene.visibleReflow(camera: c, viewport: bounds.size, focus: focus?.frame, size: focusSize, overscan: 0).first {
            let r = reflowed($0.frame)
            return CGRect(x: c.offset.x + r.minX * c.scale, y: c.offset.y + r.minY * c.scale,
                          width: r.width * c.scale, height: r.height * c.scale).contains(point)
        }
    }
    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        guard !blocked, !expanded, let cell = cell(at: recognizer.location(in: self)) else { return }
        let id = items[cell.tile.index].id, now = CACurrentMediaTime()
        let double = lastTap.map { $0.id == id && now - $0.time < 0.32 } ?? false
        lastTap = (id, now)
        select(cell, double: double)
    }
    private func select(_ cell: WeightedWallScene.Instance, double: Bool) {
        UISelectionFeedbackGenerator().selectionChanged()
        let id = items[cell.tile.index].id
        if !grouped, focus?.id != cell.id {
            previousLayout = (focus?.frame, focusSize)
            preferredFocusSide = focusSide
            focus = cell; focusedID = id; locate(animated: true)
        }
        event(["kind": double ? "double" : "select", "id": id])
    }
    @objc private func held(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, !blocked, !grouped, let cell = cell(at: recognizer.location(in: self)) else { return }
        lastTap = nil; interrupt(); event(["kind": "context", "id": items[cell.tile.index].id])
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool { !blocked }
    #if targetEnvironment(simulator)
    func testProbe(_ request: [String: Any]) -> [String: Any] {
        guard ProcessInfo.processInfo.arguments.contains("--mv-ui-smoke") else { return [:] }
        switch request["operation"] as? String {
        case "stress":
            if let base = items.first {
                interrupt(); focus = nil; focusPoster.isHidden = true
                items = (0..<1037).map { Item(id: "render-fixture-\($0)", title: "合成封面 \($0)", artist: base.artist, artwork: base.artwork, detailArtwork: base.detailArtwork, version: base.version) }
                posters.values.forEach { $0.removeFromSuperview() }; posters.removeAll()
                scene = WeightedWallScene(count: items.count)
                applyCamera(WallCamera(offset: CGPoint(x: 12, y: 80), scale: 1)); render()
            }
        case "beginPan": scrollViewWillBeginDragging(scroll)
        case "endPan": settled()
        case "motionZoom":
            applyCamera(camera.zoomed(to: Self.number(request["scale"], fallback: 1), around: viewportCenter)); render()
        case "ready": command(["session": session, "kind": "surfaceReady", "epoch": request["epoch"] ?? -1])
        case "pan":
            scrollViewWillBeginDragging(scroll)
            scroll.contentOffset.x += Self.number(request["dx"], fallback: 0)
            scroll.contentOffset.y += Self.number(request["dy"], fallback: 0)
            settled()
        case "select":
            let index = request["index"] as? Int ?? 0
            if items.indices.contains(index), let cell = nearest(id: items[index].id) { select(cell, double: false) }
        case "interrupt": interrupt(); settled()
        default: break
        }
        let c = camera
        return ["active": active, "count": items.count, "mounted": posters.count,
                "decoded": posters.values.filter { $0.image.image != nil }.count,
                "x": c.offset.x, "y": c.offset.y, "scale": c.scale,
                "focused": focus.map { items[$0.tile.index].id } ?? "",
                "square": abs(focusPoster.frame.width - focusPoster.frame.height) < 1,
                "animating": focusAnimating, "expanded": expanded, "retainedContent": movingContent != nil, "motionEpoch": motionEpoch, "motionActive": motionActive, "contentAligned": (movingContent as? NativeWallContentSnapshot)?.contentAligned ?? false,
                "frame": ["x": focusPoster.frame.minX, "y": focusPoster.frame.minY, "width": focusPoster.frame.width, "height": focusPoster.frame.height]]
    }
    #endif

    private static func number(_ raw: Any?, fallback: CGFloat) -> CGFloat {
        guard let number = raw as? NSNumber, number.doubleValue.isFinite, abs(number.doubleValue) < 1_000_000 else { return fallback }
        return CGFloat(number.doubleValue)
    }
    private static func rect(_ raw: Any?) -> CGRect? {
        guard let r = raw as? [String: Any] else { return nil }
        return CGRect(x: number(r["x"], fallback: 0), y: number(r["y"], fallback: 0), width: max(0, number(r["width"], fallback: 0)), height: max(0, number(r["height"], fallback: 0)))
    }
}

@MainActor
private final class NativeWallPoster: UIView {
    let image = UIImageView()
    let caption = UILabel()
    let artist = UILabel()
    let shade = UIView()
    let captionGradient = CAGradientLayer()
    var resource = ""
    var pendingImage: UIImage?
    var activate: (() -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true; backgroundColor = UIColor(red: 0.14, green: 0.23, blue: 0.19, alpha: 1)
        image.contentMode = .scaleAspectFill; addSubview(image)
        shade.backgroundColor = UIColor.black.withAlphaComponent(0.34); shade.isUserInteractionEnabled = false; addSubview(shade)
        captionGradient.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.73).cgColor]
        layer.addSublayer(captionGradient)
        caption.textColor = .white; caption.font = .systemFont(ofSize: 16, weight: .bold)
        artist.textColor = UIColor.white.withAlphaComponent(0.8); artist.font = .systemFont(ofSize: 11)
        caption.lineBreakMode = .byTruncatingTail; artist.lineBreakMode = .byTruncatingTail
        addSubview(caption); addSubview(artist)
        isAccessibilityElement = true; accessibilityTraits = .button
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews(); image.frame = bounds; shade.frame = bounds
        CATransaction.begin(); CATransaction.setDisableActions(true)
        captionGradient.frame = CGRect(x: 0, y: max(0, bounds.height - 70), width: bounds.width, height: min(70, bounds.height))
        CATransaction.commit()
        caption.frame = CGRect(x: 10, y: bounds.height - 46, width: max(0, bounds.width - 20), height: 22)
        artist.frame = CGRect(x: 10, y: bounds.height - 24, width: max(0, bounds.width - 20), height: 15)
        caption.isHidden = caption.text == nil; artist.isHidden = artist.text == nil
        for snapshot in subviews.compactMap({ $0 as? NativeWallContentSnapshot }) {
            snapshot.frame = bounds; snapshot.layoutIfNeeded()
        }
    }
    override func accessibilityActivate() -> Bool { activate?(); return activate != nil }
    func setArtwork(_ value: UIImage?) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        image.image = value
        CATransaction.commit()
    }
    func reuse() { resource = ""; setArtwork(nil); pendingImage = nil; activate = nil }
}

/// Decode thumbnails off the main thread. Versioned identities prevent late reuse writes.
@MainActor
private final class NativeWallImages {
    private let cache = NSCache<NSString, UIImage>()
    private let queue: OperationQueue = { let q = OperationQueue(); q.maxConcurrentOperationCount = 2; q.qualityOfService = .userInitiated; return q }()
    private var pending: [String: [(UIImage?) -> Void]] = [:]
    private var generation = 0
    private var operations: [String: BlockOperation] = [:]
    init() { cache.totalCostLimit = 64 * 1024 * 1024; cache.countLimit = 384 }
    func cached(key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func load(path: String, key: String, pixels: Int = 768, completion: @escaping (UIImage?) -> Void) {
        if let value = cache.object(forKey: key as NSString) { completion(value); return }
        if pending[key] != nil { pending[key]?.append(completion); return }
        pending[key] = [completion]
        let token = generation
        let operation = BlockOperation()
        operations[key] = operation
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let operation, !operation.isCancelled else { return }
            let result: UIImage? = autoreleasepool {
                guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
                      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: pixels, kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return nil }
                return UIImage(cgImage: image)
            }
            Task { @MainActor [weak self] in
                guard let self, token == self.generation, !operation.isCancelled,
                      self.operations[key] === operation else { return }
                self.operations.removeValue(forKey: key)
                if let result { self.cache.setObject(result, forKey: key as NSString, cost: (result.cgImage?.bytesPerRow ?? 0) * (result.cgImage?.height ?? 0)) }
                let callbacks = self.pending.removeValue(forKey: key) ?? []
                callbacks.forEach { $0(result) }
            }
        }
        queue.addOperation(operation)
    }
    func prioritize(key: String, visible: Bool) {
        operations[key]?.queuePriority = visible ? .veryHigh : .low
    }
    func retain(keys: Set<String>) {
        for key in Array(operations.keys) where !keys.contains(key) {
            operations.removeValue(forKey: key)?.cancel()
            pending.removeValue(forKey: key)
        }
    }
    func cancel() { generation += 1; queue.cancelAllOperations(); operations.removeAll(); pending.removeAll() }
}

/// The captured web content is cropped in source coordinates. Resize both its
/// size and crop origin with the native card, including during a live pinch.
@MainActor
final class NativeWallContentSnapshot: UIView {
    private let content: UIView
    private let sourceSize: CGSize
    private let sourceFrame: CGRect
    init(content: UIView, sourceSize: CGSize, sourceFrame: CGRect) {
        self.content = content; self.sourceSize = sourceSize; self.sourceFrame = sourceFrame
        super.init(frame: CGRect(origin: .zero, size: sourceSize))
        backgroundColor = .clear; isUserInteractionEnabled = false
        addSubview(content)
        layoutIfNeeded()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private var projected: CGRect {
        let x = bounds.width / max(1, sourceSize.width), y = bounds.height / max(1, sourceSize.height)
        return CGRect(x: sourceFrame.minX * x, y: sourceFrame.minY * y, width: sourceFrame.width * x, height: sourceFrame.height * y)
    }
    override func layoutSubviews() { super.layoutSubviews(); content.frame = projected }
    var contentAligned: Bool {
        abs(content.frame.minX - projected.minX) < 0.5 && abs(content.frame.minY - projected.minY) < 0.5 &&
        abs(content.frame.width - projected.width) < 0.5 && abs(content.frame.height - projected.height) < 0.5
    }
}
