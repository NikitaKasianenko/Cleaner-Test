
import SwiftUI

@Observable
final class AppEnvironment {

    let mediaService: any MediaServiceProtocol
    let router: AppRouter

    static let live = AppEnvironment(
        mediaService: MediaService(
            libraryService: PhotoLibraryService(),
            cacheManager: CacheManager(),
            duplicateAnalyzer: DuplicateAnalyzerService(),
            similarAnalyzer: SimilarAnalyzerService(),
            fileSizeService: FileSizeService()
        )
    )

    private init(mediaService: any MediaServiceProtocol) {
        self.mediaService = mediaService
        self.router = AppRouter()
    }
}
