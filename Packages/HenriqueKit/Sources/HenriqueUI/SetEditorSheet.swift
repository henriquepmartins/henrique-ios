import SwiftUI

struct WeightStepper: View {
  @Binding var weightKg: Double
  var body: some View {
    HStack {
      TextField("carga", value: $weightKg, format: .number.precision(.fractionLength(0...2)))
        #if os(iOS)
        .keyboardType(.decimalPad)
        #endif
        .accessibilityLabel("Carga em kg")
      Text("kg").foregroundStyle(Color.mutedInk)
      Stepper("Ajustar carga", value: $weightKg, in: 0...1_000, step: 2.5).labelsHidden()
    }
  }
}
