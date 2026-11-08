import Foundation

// Struct para uma fonte de isótopo no "bunker" (armazenável via Codable para UserDefaults).
// Inclui UUID para Identifiable/Hashable (único), e data inicial para decay tracking.
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
