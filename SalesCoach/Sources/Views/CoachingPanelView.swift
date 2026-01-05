import SwiftUI

/// Coaching insights panel
struct CoachingPanelView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left side - Process Timeline
            ScrollView {
                ProcessTimelineView(
                    checklist: appState.processChecklist,
                    currentStage: appState.coachingState.stage
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(width: 200)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Right side - Coaching content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Suggested questions
                    SuggestedQuestionsView(questions: appState.coachingState.suggestedQuestions)
                    
                    Divider()
                    
                    // MEDDIC table
                    MEDDICTableView(meddic: appState.coachingState.meddic)
                }
                .padding()
            }
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
}

/// Stage indicator with confidence
struct StageIndicatorView: View {
    let stage: StageInfo?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current Stage")
                    .font(.headline)
                
                Spacer()
                
                if let stage = stage {
                    Text("\(Int(stage.confidence * 100))% confident")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let stage = stage {
                HStack(spacing: 12) {
                    // Stage name badge
                    Text(stage.name)
                        .font(.title3.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(stageColor.opacity(0.2))
                        .foregroundStyle(stageColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Confidence bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(stageColor)
                                .frame(width: geo.size.width * stage.confidence)
                        }
                    }
                    .frame(height: 8)
                }
                
                // Rationale
                Text(stage.rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                Text("Waiting for analysis...")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
    }
    
    private var stageColor: Color {
        guard let stage = stage else { return .gray }
        
        // Color based on stage name
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
}

#Preview {
    CoachingPanelView()
        .environmentObject(AppState())
        .frame(width: 400, height: 800)
}

