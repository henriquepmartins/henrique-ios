import Foundation

extension JSONDecoder {
  /// O decodificador que o app inteiro usa. Fica em um lugar só para o teste de
  /// contrato exercitar exatamente o mesmo caminho que a tela.
  public static func henrique() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let text = try decoder.singleValueContainer().decode(String.self)
      guard let date = parseTimestamp(text) else {
        throw DecodingError.dataCorrupted(
          .init(codingPath: decoder.codingPath, debugDescription: "instante inválido: \(text)"))
      }
      return date
    }
    return decoder
  }
}

/// O Postgres devolve o instante com milissegundos e o Foundation só aceita os
/// dois formatos se cada um tiver seu parser.
public func parseTimestamp(_ text: String) -> Date? {
  let withFraction = ISO8601DateFormatter()
  withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  if let date = withFraction.date(from: text) { return date }
  let plain = ISO8601DateFormatter()
  plain.formatOptions = [.withInternetDateTime]
  return plain.date(from: text)
}
