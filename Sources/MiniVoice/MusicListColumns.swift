import Foundation

/// Prioritize names, then album, then duration; favorites always remain at the edge.
struct MusicListColumns: Equatable {
    let isCompact: Bool
    let showsAlbum: Bool
    let showsDuration: Bool
    let width: CGFloat
    let selection: CGRect
    let artwork: CGRect
    let title: CGRect
    let artist: CGRect
    let album: CGRect
    let duration: CGRect
    let favorite: CGRect

    init(width panelWidth: CGFloat, multiSelecting: Bool) {
        isCompact = panelWidth < 480
        showsAlbum = panelWidth >= 620
        showsDuration = panelWidth >= 700
        // Card padding: 24; scrollbar gutter: 16; row padding: 14.
        width = max(0, panelWidth - 54)
        let selectionWidth: CGFloat = multiSelecting ? 30 : 0
        selection = CGRect(x: 0, y: 11, width: 22, height: 22)
        artwork = CGRect(x: selectionWidth, y: 0, width: 44, height: 44)
        favorite = CGRect(x: width - 28, y: 8, width: 28, height: 28)
        let durationWidth: CGFloat = showsDuration ? 48 : 0
        duration = CGRect(x: favorite.minX - 8 - 40, y: 12, width: 40, height: 20)
        let textStart = artwork.maxX + 8
        let textEnd = favorite.minX - 8 - durationWidth
        let gaps: CGFloat = isCompact ? 0 : (showsAlbum ? 16 : 8)
        let budget = max(0, textEnd - textStart - gaps)
        let albumWidth = showsAlbum ? budget * 0.27 : 0
        let artistWidth = isCompact ? 0 : budget * (showsAlbum ? 0.30 : 0.40)
        let titleWidth = budget - artistWidth - albumWidth
        title = CGRect(x: textStart, y: isCompact ? 3 : 12, width: titleWidth, height: 20)
        artist = CGRect(x: isCompact ? textStart : title.maxX + 8, y: isCompact ? 25 : 12,
                        width: isCompact ? titleWidth : artistWidth, height: isCompact ? 16 : 20)
        album = CGRect(x: showsAlbum ? artist.maxX + 8 : textEnd, y: 12, width: albumWidth, height: 20)
    }
}
