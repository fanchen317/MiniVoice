import Foundation

/// Width-driven transitions follow the window directly, without queued animations.
struct MusicListColumns: Equatable, Sendable {
    let isCompact: Bool
    let showsAlbum: Bool
    let showsDuration: Bool
    let showsEdit: Bool
    let horizontalProgress: CGFloat
    let albumOpacity: CGFloat
    let durationOpacity: CGFloat
    let editSpaceProgress: CGFloat
    let width: CGFloat
    let selection: CGRect
    let artwork: CGRect
    let title: CGRect
    let artist: CGRect
    let compactArtist: CGRect
    let album: CGRect
    let duration: CGRect
    let favorite: CGRect

    init(width panelWidth: CGFloat, multiSelecting: Bool) {
        func progress(_ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
            let t = min(1, max(0, (panelWidth - lower) / (upper - lower)))
            return t * t * (3 - 2 * t)
        }
        horizontalProgress = progress(440, 520)
        albumOpacity = progress(580, 660)
        durationOpacity = progress(660, 740)
        editSpaceProgress = progress(740, 820)
        isCompact = panelWidth < 480
        showsAlbum = albumOpacity > 0
        showsDuration = durationOpacity > 0
        showsEdit = panelWidth >= 820
        // Card padding: 24; scrollbar gutter: 16; row padding: 14.
        width = max(0, panelWidth - 54)
        let selectionWidth: CGFloat = multiSelecting ? 30 : 0
        selection = CGRect(x: 0, y: 11, width: 22, height: 22)
        artwork = CGRect(x: selectionWidth, y: 0, width: 44, height: 44)
        favorite = CGRect(x: width - 28 - 38 * editSpaceProgress, y: 8, width: 28, height: 28)
        duration = CGRect(x: favorite.minX - 48, y: 12, width: 40, height: 20)
        let textStart = artwork.maxX + 8
        let textEnd = favorite.minX - 8 - 48 * durationOpacity
        let fullBudget = max(0, textEnd - textStart)
        let gaps = 8 * horizontalProgress + 8 * albumOpacity
        let budget = max(0, fullBudget - gaps)
        let albumWidth = budget * 0.27 * albumOpacity
        let artistWidth = budget * (0.40 - 0.10 * albumOpacity) * horizontalProgress
        let titleWidth = max(0, budget - artistWidth - albumWidth)
        title = CGRect(x: textStart, y: 3 + 9 * horizontalProgress, width: titleWidth, height: 20)
        // The two artist labels crossfade in place, rather than moving diagonally
        // through the title. Their horizontal anchors remain tied to the columns.
        artist = CGRect(x: title.maxX + 8 * horizontalProgress, y: 12, width: artistWidth, height: 20)
        compactArtist = CGRect(x: textStart, y: 25, width: fullBudget, height: 16)
        album = CGRect(x: artist.maxX + 8 * albumOpacity, y: 12, width: albumWidth, height: 20)
    }
}
