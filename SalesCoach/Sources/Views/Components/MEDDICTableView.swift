import SwiftUI

/// MEDDIC data table view
struct MEDDICTableView: View {
    let meddic: MEDDICData
    @State private var expandedField: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with completion
            HStack {
                Text("MEDDIC Analysis")
                    .font(.headline)
                
                Spacer()
                
                // Completion indicator
                HStack(spacing: 4) {
                    Text("\(meddic.filledCount)/6")
                        .font(.caption.bold())
                    
                    // Mini progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                        
                        Circle()
                            .trim(from: 0, to: meddic.completionPercentage)
                            .stroke(completionColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 20, height: 20)
                }
            }
            
            // MEDDIC fields
            VStack(spacing: 8) {
                ForEach(meddic.allFields, id: \.name) { name, field in
                    MEDDICFieldRow(
                        name: name,
                        field: field,
                        isExpanded: expandedField == name,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedField = expandedField == name ? nil : name
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var completionColor: Color {
        let completion = meddic.completionPercentage
        if completion >= 0.8 { return .green }
        if completion >= 0.5 { return .orange }
        return .red
    }
}

/// Individual MEDDIC field row
struct MEDDICFieldRow: View {
    let name: String
    let field: MEDDICField?
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Field icon
                    Image(systemName: fieldIcon)
                        .foregroundStyle(field != nil ? fieldColor : Color.gray.opacity(0.5))
                        .font(.title3)
                        .frame(width: 24)
                    
                    // Field name
                    Text(name)
                        .font(.subheadline.bold())
                        .foregroundStyle(field != nil ? .primary : .secondary)
                    
                    Spacer()
                    
                    if let field = field {
                        // Confidence badge
                        Text("\(Int(field.confidence * 100))%")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(confidenceColor(field.confidence))
                            .clipShape(Capsule())
                        
                        // Expand chevron
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not captured")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)
            
            // Expanded content
            if isExpanded, let field = field {
                VStack(alignment: .leading, spacing: 8) {
                    // Value
                    Text(field.value)
                        .font(.subheadline)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    // Evidence
                    if let evidence = field.evidence, !evidence.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Evidence")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            
                            ForEach(evidence) { quote in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\"\(quote.quote)\"")
                                        .font(.caption)
                                        .italic()
                                    
                                    Text(quote.formattedRange)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .padding(.leading, 36)
                    }
                }
                .padding(.bottom, 8)
            }
            
            Divider()
        }
    }
    
    private var fieldIcon: String {
        switch name {
        case "Metrics": return "chart.bar.fill"
        case "Economic Buyer": return "person.crop.circle.fill.badge.checkmark"
        case "Decision Criteria": return "list.bullet.clipboard.fill"
        case "Decision Process": return "arrow.triangle.branch"
        case "Identify Pain": return "exclamationmark.bubble.fill"
        case "Champion": return "star.fill"
        default: return "circle.fill"
        }
    }
    
    private var fieldColor: Color {
        switch name {
        case "Metrics": return .blue
        case "Economic Buyer": return .purple
        case "Decision Criteria": return .orange
        case "Decision Process": return .green
        case "Identify Pain": return .red
        case "Champion": return .yellow
        default: return .gray
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 { return .green }
        if confidence >= 0.5 { return .orange }
        return .red
    }
}

#Preview {
    MEDDICTableView(meddic: MEDDICData(
        metrics: MEDDICField(value: "20% reduction in onboarding time", confidence: 0.85, evidence: [
            EvidenceQuote(quote: "We need to cut onboarding from 3 months to about 2", startMs: 45000, endMs: 52000)
        ]),
        economicBuyer: MEDDICField(value: "Sarah Chen, VP of Sales", confidence: 0.7),
        decisionCriteria: nil,
        decisionProcess: MEDDICField(value: "Needs approval from IT and Finance", confidence: 0.6),
        identifyPain: MEDDICField(value: "Current tool is too slow, reps wasting time on admin", confidence: 0.9),
        champion: nil
    ))
    .padding()
    .frame(width: 400)
}

