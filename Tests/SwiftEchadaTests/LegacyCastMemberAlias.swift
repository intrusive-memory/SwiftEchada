import SwiftProyecto

/// SwiftProyecto's legacy `CastMember`, re-exported under an unambiguous name.
///
/// The module name `SwiftProyecto` is shadowed by its own `public struct
/// SwiftProyecto`, so `SwiftProyecto.CastMember` does not resolve as a
/// module-qualified reference. Test files that import both SwiftProyecto and
/// SwiftReparto (where the bare name `CastMember` is ambiguous) use this alias
/// to build legacy PROJECT.md `cast:` fixtures. This file imports only
/// SwiftProyecto, so the bare name is unambiguous here.
typealias ProyectoCastMember = CastMember
