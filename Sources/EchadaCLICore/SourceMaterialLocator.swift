import Foundation
import SwiftProyecto

/// Locates the screenplay source files a project's cast is drawn from.
///
/// Resolves `episodesDir` (default `episodes`) relative to the PROJECT.md
/// directory and returns every readable text script whose file name matches the
/// project's `filePattern` glob(s) (default `*.fountain`). The search recurses so
/// season subfolders are covered.
enum SourceMaterialLocator {

  /// Text extensions we can parse as Fountain-flavored screenplays. `.highland`
  /// files are zip bundles and are intentionally excluded (see ``highlandFiles``).
  private static let textExtensions: Set<String> = [
    "fountain", "txt", "text", "md", "markdown", "fic", "spmd",
  ]

  /// Whether a `*.ext` glob (e.g. from `ProjectAnalysis.discoveredFiles`) targets
  /// an extension the locator can actually parse as a screenplay. Used by the
  /// `cast` bootstrap so it only ever writes a `filePattern` the pipeline can act
  /// on, rather than pinning an inapplicable default.
  static func isParseableScriptPattern(_ pattern: String) -> Bool {
    textExtensions.contains((pattern as NSString).pathExtension.lowercased())
  }

  /// Screenplay source files for the project, sorted by path for deterministic order.
  ///
  /// - Parameters:
  ///   - projectDirectory: Directory containing PROJECT.md.
  ///   - frontMatter: Parsed project front matter (for `episodesDir`/`filePattern`).
  /// - Returns: Absolute URLs of matching, readable text scripts.
  static func episodeFiles(
    projectDirectory: URL,
    frontMatter: ProjectFrontMatter
  ) -> [URL] {
    let episodesDir = projectDirectory.appending(
      path: frontMatter.resolvedEpisodesDir, directoryHint: .isDirectory)
    let patterns = frontMatter.resolvedFilePatterns

    return enumerateFiles(under: episodesDir)
      .filter { textExtensions.contains($0.pathExtension.lowercased()) }
      .filter { url in matchesAnyPattern(url.lastPathComponent, patterns: patterns) }
      .sorted { $0.path < $1.path }
  }

  /// `.highland` bundles found under `episodesDir` (surfaced so the command can
  /// warn that they are present but not yet parsed).
  static func highlandFiles(
    projectDirectory: URL,
    frontMatter: ProjectFrontMatter
  ) -> [URL] {
    let episodesDir = projectDirectory.appending(
      path: frontMatter.resolvedEpisodesDir, directoryHint: .isDirectory)
    return enumerateFiles(under: episodesDir)
      .filter { $0.pathExtension.lowercased() == "highland" }
      .sorted { $0.path < $1.path }
  }

  // MARK: - Private helpers

  /// Recursively enumerate regular files under `directory` (empty if absent).
  private static func enumerateFiles(under directory: URL) -> [URL] {
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDir),
      isDir.boolValue
    else {
      return []
    }
    guard
      let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }

    var results: [URL] = []
    for case let url as URL in enumerator {
      let isRegular = (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile
      if isRegular == true {
        results.append(url)
      }
    }
    return results
  }

  /// Whether `fileName` matches any glob in `patterns` (via `fnmatch`, or exact
  /// match as a fallback). An empty pattern list matches nothing.
  private static func matchesAnyPattern(_ fileName: String, patterns: [String]) -> Bool {
    guard !patterns.isEmpty else { return false }
    return patterns.contains { pattern in
      pattern.withCString { patternC in
        fileName.withCString { nameC in
          fnmatch(patternC, nameC, 0) == 0
        }
      } || pattern == fileName
    }
  }
}
