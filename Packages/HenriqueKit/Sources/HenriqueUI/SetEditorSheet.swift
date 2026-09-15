import HenriqueCore
import SwiftUI

struct WeightStepper: View {
  @Binding var weightKg: Double
  var range: ClosedRange<Double> = Limits.setWeightKg

  var body: some View {
    HStack(spacing: 8) {
      Text("carga").font(.body)
      Spacer(minLength: 8)
      TextField("0", value: $weightKg, format: .number.precision(.fractionLength(0...2)))
        .submitLabel(.done)
        #if os(iOS)
        .keyboardType(.decimalPad)
        #endif
        .multilineTextAlignment(.trailing)
        .font(.body.weight(.semibold)).monospacedDigit()
        .frame(minWidth: 64)
        .accessibilityLabel("Carga em kg")
      Text("kg").font(.callout).foregroundStyle(Color.mutedInk)
      Stepper("Ajustar carga", value: $weightKg, in: range, step: 2.5)
        .labelsHidden()
        .accessibilityLabel("Ajustar carga em kg")
    }
    .frame(minHeight: 48)
    .onChange(of: weightKg) { _, new in
      let clamped = new.isFinite ? new.clamped(to: range) : range.lowerBound
      if clamped != new { weightKg = clamped }
    }
  }
}
