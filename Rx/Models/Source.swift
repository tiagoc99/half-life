// One saved isotope source, the record the source list calls a bunker entry.
// The struct is Codable, so SourceManager can write the whole list to UserDefaults as JSON. Identifiable and Hashable both use the UUID only.
// name is the label typed by the user. isotope is the Isotope raw-value string, such as Iridium-192, stored as text so the JSON does not depend on the enum layout.
// initialActivity is the activity at initialDate, in curies (Ci). The screens convert becquerels for display and typing, and this struct always keeps curies.
// initialDate starts the decay clock. Equality and hashing ignore the name, activity, and date: two sources match only when their ids match.

import Foundation

// Struct para uma fonte de isótopo no "bunker" (armazenável via Codable para UserDefaults).
// Inclui UUID para Identifiable/Hashable (único), e data inicial para decay tracking.
// A new source gets a fresh UUID. Decoding keeps the id that was saved.
struct Source: Identifiable, Codable, Hashable {
    var id = UUID()  // UUID único para lists e hashing.
    let name: String  // Nome custom (ex.: "Site A Ir-192").
    let isotope: String  // RawValue do enum para Codable (não enum direto).
    let initialActivity: Double  // Atividade inicial em Ci.
    let initialDate: Date  // Data de fabricação/instalação para calcular decay.
    
    // Hashable: Baseado em ID para igualdade (UUIDs únicos evitam colisões).
    static func == (lhs: Source, rhs: Source) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
