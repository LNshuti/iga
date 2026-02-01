// IGA/Features/Tools/CalculatorView.swift

import SwiftUI

// MARK: - Calculator View

/// GRE-style on-screen calculator
struct CalculatorView: View {
    @State private var display = "0"
    @State private var currentOperation: Operation?
    @State private var previousValue: Double = 0
    @State private var shouldResetDisplay = false
    @State private var memory: Double = 0
    @State private var hasMemory = false

    enum Operation {
        case add, subtract, multiply, divide, sqrt, percent
    }

    var body: some View {
        VStack(spacing: 0) {
            // Display
            displayArea

            // Memory row
            memoryRow

            Divider()

            // Calculator buttons
            calculatorButtons
        }
        .navigationTitle("Calculator")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Display

    private var displayArea: some View {
        VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
            if let op = currentOperation {
                Text(operationSymbol(op))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(display)
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.secondaryBackground)
    }

    private var memoryRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(hasMemory ? "M" : "")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 20)

            Spacer()

            Button("MC") { memory = 0; hasMemory = false }
                .disabled(!hasMemory)
            Button("MR") { if hasMemory { display = formatNumber(memory); shouldResetDisplay = true } }
                .disabled(!hasMemory)
            Button("M+") { memory += currentValue; hasMemory = true }
            Button("M-") { memory -= currentValue; hasMemory = true }
        }
        .font(Theme.Typography.caption)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Calculator Buttons

    private var calculatorButtons: some View {
        VStack(spacing: 1) {
            // Row 1: Clear, sqrt, %, ÷
            HStack(spacing: 1) {
                calcButton("C", style: .function) { clear() }
                calcButton("√", style: .function) { calculateSqrt() }
                calcButton("%", style: .function) { calculatePercent() }
                calcButton("÷", style: .operation) { setOperation(.divide) }
            }

            // Row 2: 7, 8, 9, ×
            HStack(spacing: 1) {
                calcButton("7", style: .number) { appendDigit("7") }
                calcButton("8", style: .number) { appendDigit("8") }
                calcButton("9", style: .number) { appendDigit("9") }
                calcButton("×", style: .operation) { setOperation(.multiply) }
            }

            // Row 3: 4, 5, 6, -
            HStack(spacing: 1) {
                calcButton("4", style: .number) { appendDigit("4") }
                calcButton("5", style: .number) { appendDigit("5") }
                calcButton("6", style: .number) { appendDigit("6") }
                calcButton("-", style: .operation) { setOperation(.subtract) }
            }

            // Row 4: 1, 2, 3, +
            HStack(spacing: 1) {
                calcButton("1", style: .number) { appendDigit("1") }
                calcButton("2", style: .number) { appendDigit("2") }
                calcButton("3", style: .number) { appendDigit("3") }
                calcButton("+", style: .operation) { setOperation(.add) }
            }

            // Row 5: +/-, 0, ., =
            HStack(spacing: 1) {
                calcButton("±", style: .function) { toggleSign() }
                calcButton("0", style: .number) { appendDigit("0") }
                calcButton(".", style: .number) { appendDecimal() }
                calcButton("=", style: .equals) { calculate() }
            }
        }
        .background(Theme.Colors.secondaryBackground)
    }

    private enum ButtonStyle {
        case number, operation, function, equals
    }

    private func calcButton(_ label: String, style: ButtonStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 24, weight: style == .number ? .regular : .medium))
                .foregroundStyle(buttonForeground(style))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(buttonBackground(style))
        }
        .frame(height: 70)
    }

    private func buttonBackground(_ style: ButtonStyle) -> Color {
        switch style {
        case .number: return Theme.Colors.background
        case .operation: return Theme.Colors.primary.opacity(0.15)
        case .function: return Theme.Colors.secondaryBackground
        case .equals: return Theme.Colors.primary
        }
    }

    private func buttonForeground(_ style: ButtonStyle) -> Color {
        switch style {
        case .equals: return .white
        case .operation: return Theme.Colors.primary
        default: return .primary
        }
    }

    // MARK: - Calculator Logic

    private var currentValue: Double {
        Double(display) ?? 0
    }

    private func appendDigit(_ digit: String) {
        if shouldResetDisplay || display == "0" {
            display = digit
            shouldResetDisplay = false
        } else if display.count < 12 {
            display += digit
        }
    }

    private func appendDecimal() {
        if shouldResetDisplay {
            display = "0."
            shouldResetDisplay = false
        } else if !display.contains(".") {
            display += "."
        }
    }

    private func clear() {
        display = "0"
        currentOperation = nil
        previousValue = 0
        shouldResetDisplay = false
    }

    private func toggleSign() {
        if let value = Double(display) {
            display = formatNumber(-value)
        }
    }

    private func setOperation(_ op: Operation) {
        if currentOperation != nil {
            calculate()
        }
        previousValue = currentValue
        currentOperation = op
        shouldResetDisplay = true
    }

    private func calculateSqrt() {
        let value = currentValue
        if value >= 0 {
            display = formatNumber(sqrt(value))
        } else {
            display = "Error"
        }
        shouldResetDisplay = true
    }

    private func calculatePercent() {
        let value = currentValue
        display = formatNumber(value / 100)
        shouldResetDisplay = true
    }

    private func calculate() {
        guard let op = currentOperation else { return }

        let current = currentValue
        var result: Double

        switch op {
        case .add:
            result = previousValue + current
        case .subtract:
            result = previousValue - current
        case .multiply:
            result = previousValue * current
        case .divide:
            if current == 0 {
                display = "Error"
                currentOperation = nil
                shouldResetDisplay = true
                return
            }
            result = previousValue / current
        case .sqrt, .percent:
            return
        }

        display = formatNumber(result)
        currentOperation = nil
        shouldResetDisplay = true
    }

    private func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 && abs(value) < 1e10 {
            return String(format: "%.0f", value)
        } else if abs(value) < 0.0001 || abs(value) >= 1e10 {
            return String(format: "%.4e", value)
        } else {
            let formatter = NumberFormatter()
            formatter.maximumFractionDigits = 8
            formatter.minimumFractionDigits = 0
            return formatter.string(from: NSNumber(value: value)) ?? String(value)
        }
    }

    private func operationSymbol(_ op: Operation) -> String {
        switch op {
        case .add: return "+"
        case .subtract: return "−"
        case .multiply: return "×"
        case .divide: return "÷"
        case .sqrt: return "√"
        case .percent: return "%"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CalculatorView()
    }
}
