import SwiftUI

/// Vertical timeline showing all sales process stages with progression indicators
struct ProcessTimelineView: View {
    let checklist: ProcessChecklist
    let currentStage: StageInfo?
    
    private var currentStageIndex: Int? {
        guard let currentStage = currentStage else { return nil }
        return checklist.stages.firstIndex { stage in
            stage.name.lowercased() == currentStage.name.lowercased()
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(checklist.stages.enumerated()), id: \.element.id) { index, stage in
                TimelineStageRow(
                    stage: stage,
                    state: stageState(for: index),
                    confidence: stageConfidence(for: index),
                    isLast: index == checklist.stages.count - 1
                )
            }
        }
        .padding(.vertical, 8)
    }
    
    private func stageState(for index: Int) -> StageState {
        guard let currentIndex = currentStageIndex else {
            return index == 0 ? .next : .upcoming
        }
        
        if index < currentIndex {
            return .completed
        } else if index == currentIndex {
            return .current
        } else if index == currentIndex + 1 {
            return .next
        } else {
            return .upcoming
        }
    }
    
    private func stageConfidence(for index: Int) -> Double? {
        guard let currentIndex = currentStageIndex,
              index == currentIndex,
              let currentStage = currentStage else {
            return nil
        }
        return currentStage.confidence
    }
}

/// Visual state for a timeline stage
enum StageState {
    case completed
    case current
    case next
    case upcoming
}

/// Individual row in the timeline
struct TimelineStageRow: View {
    let stage: ProcessStage
    let state: StageState
    let confidence: Double?
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator column
            VStack(spacing: 0) {
                stageIndicator
                
                if !isLast {
                    connectingLine
                }
            }
            .frame(width: 24)
            
            // Stage content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(stage.name)
                        .font(state == .current ? .subheadline.bold() : .subheadline)
                        .foregroundStyle(textColor)
                    
                    if state == .next {
                        Text("NEXT")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.8))
                            .clipShape(Capsule())
                    }
                }
                
                if state == .current, let confidence = confidence {
                    HStack(spacing: 6) {
                        // Mini confidence bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.2))
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(stageColor)
                                    .frame(width: geo.size.width * confidence)
                            }
                        }
                        .frame(width: 50, height: 4)
                        
                        Text("\(Int(confidence * 100))%")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(stage.description)
                    .font(.caption)
                    .foregroundStyle(descriptionColor)
                    .lineLimit(2)
            }
            .padding(.bottom, isLast ? 0 : 16)
            
            Spacer(minLength: 0)
        }
    }
    
    @ViewBuilder
    private var stageIndicator: some View {
        ZStack {
            Circle()
                .fill(indicatorFillColor)
                .frame(width: 20, height: 20)
            
            Circle()
                .strokeBorder(indicatorBorderColor, lineWidth: state == .current ? 2 : 1)
                .frame(width: 20, height: 20)
            
            switch state {
            case .completed:
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            case .current:
                Circle()
                    .fill(stageColor)
                    .frame(width: 8, height: 8)
            case .next:
                Circle()
                    .fill(Color.orange.opacity(0.5))
                    .frame(width: 6, height: 6)
            case .upcoming:
                EmptyView()
            }
        }
    }
    
    private var connectingLine: some View {
        Rectangle()
            .fill(lineColor)
            .frame(width: 2)
            .frame(maxHeight: .infinity)
    }
    
    // MARK: - Colors
    
    private var stageColor: Color {
        let stageName = stage.name.lowercased()
        if stageName.contains("opening") || stageName.contains("intro") {
            return .blue
        } else if stageName.contains("discovery") {
            return .purple
        } else if stageName.contains("qualification") {
            return .orange
        } else if stageName.contains("value") || stageName.contains("demo") {
            return .green
        } else if stageName.contains("objection") {
            return .red
        } else if stageName.contains("closing") || stageName.contains("close") {
            return .teal
        }
        return .gray
    }
    
    private var indicatorFillColor: Color {
        switch state {
        case .completed:
            return .green
        case .current:
            return stageColor.opacity(0.15)
        case .next:
            return Color.orange.opacity(0.1)
        case .upcoming:
            return Color(nsColor: .controlBackgroundColor)
        }
    }
    
    private var indicatorBorderColor: Color {
        switch state {
        case .completed:
            return .green
        case .current:
            return stageColor
        case .next:
            return .orange.opacity(0.5)
        case .upcoming:
            return .gray.opacity(0.3)
        }
    }
    
    private var textColor: Color {
        switch state {
        case .completed:
            return .secondary
        case .current:
            return .primary
        case .next:
            return .primary.opacity(0.8)
        case .upcoming:
            return .secondary.opacity(0.6)
        }
    }
    
    private var descriptionColor: Color {
        switch state {
        case .completed:
            return .secondary.opacity(0.6)
        case .current:
            return .secondary
        case .next:
            return .secondary.opacity(0.8)
        case .upcoming:
            return .secondary.opacity(0.4)
        }
    }
    
    private var lineColor: Color {
        switch state {
        case .completed:
            return .green.opacity(0.5)
        case .current:
            return stageColor.opacity(0.3)
        case .next, .upcoming:
            return .gray.opacity(0.2)
        }
    }
}

#Preview {
    ProcessTimelineView(
        checklist: .defaultChecklist,
        currentStage: StageInfo(
            name: "Discovery",
            confidence: 0.75,
            rationale: "Currently exploring pain points"
        )
    )
    .frame(width: 250)
    .padding()
    .background(Color(nsColor: .controlBackgroundColor))
}

