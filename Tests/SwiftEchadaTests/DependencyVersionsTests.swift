import Foundation
import Testing

@testable import EchadaCLICore

/// `echada --version` reports the dependency versions compiled into the binary.
///
/// The table is generated at build time from `Package.swift` and
/// `Package.resolved` by `Scripts/generate-dependency-versions.py`. These tests
/// guard the two ways that can silently go wrong: the generator producing an
/// empty table (a parsing regression — the first draft matched zero direct
/// dependencies because its comment stripper ate the `//` in `https://`), and
/// the report losing the declared-vs-compiled distinction that makes it useful.
@Suite("Dependency version reporting")
struct DependencyVersionsTests {

  @Test("Direct dependencies are populated")
  func directDependenciesPresent() {
    #expect(
      !DependencyVersions.direct.isEmpty,
      "generator produced no direct dependencies — Package.swift parsing regressed")
  }

  @Test("SwiftProyecto is reported with both declared and compiled versions")
  func swiftProyectoReported() throws {
    let proyecto = DependencyVersions.direct.first { $0.name == "SwiftProyecto" }
    let dependency = try #require(proyecto, "SwiftProyecto missing from the direct list")

    #expect(!dependency.requirement.isEmpty)
    #expect(!dependency.resolved.isEmpty)
    #expect(dependency.resolved != "unresolved", "SwiftProyecto did not resolve to a version")
  }

  @Test("No direct dependency is left unresolved")
  func allDirectDependenciesResolved() {
    let unresolved = DependencyVersions.direct.filter { $0.resolved == "unresolved" }
    let names = unresolved.map(\.name).joined(separator: ", ")
    #expect(
      unresolved.isEmpty,
      "unresolved: \(names) — identity mismatch between Package.swift and Package.resolved")
  }

  @Test("The report renders both sections with a header")
  func reportRendersSections() {
    let report = DependencyVersions.report()

    #expect(report.contains("Direct dependencies (Package.swift)"))
    #expect(report.contains("DECLARED"))
    #expect(report.contains("COMPILED"))
    #expect(report.contains("SwiftProyecto"))
    if !DependencyVersions.transitive.isEmpty {
      #expect(report.contains("Transitive dependencies"))
    }
  }

  /// `--version` must still lead with the bare version string — scripts and the
  /// Homebrew formula's `test do` block parse or invoke it.
  @Test("Version report leads with the tool version")
  func versionReportLeadsWithVersion() throws {
    let report = EchadaCLI.versionReport
    let firstLine = try #require(report.components(separatedBy: "\n").first)

    #expect(!firstLine.isEmpty)
    #expect(!firstLine.contains(" "), "first line should be the bare version, got: \(firstLine)")
    #expect(report.contains("Direct dependencies"))
  }
}
