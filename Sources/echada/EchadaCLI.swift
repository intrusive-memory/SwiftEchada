import ArgumentParser
import EchadaCLICore

@main
struct EchadaCLIEntry: AsyncParsableCommand {
  static let configuration = EchadaCLI.configuration
}
