import SwiftUI

/// View for displaying suggested questions
struct SuggestedQuestionsView: View {
    let questions: [SuggestedQuestion]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Suggested Questions")
                    .font(.headline)
                
                Spacer()
                
                Text("Ask next →")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if questions.isEmpty {
                Text("No suggestions yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                VStack(spacing: 10) {
                    ForEach(sortedQuestions) { question in
                        QuestionRow(question: question)
                    }
                }
            }
        }
    }
    
    private var sortedQuestions: [SuggestedQuestion] {
        questions.sorted { $0.priority < $1.priority }
    }
}

/// Individual question row
struct QuestionRow: View {
    let question: SuggestedQuestion
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                // Priority indicator
                priorityBadge
                
                // Question text
                Text(question.question)
                    .font(.subheadline)
                    .textSelection(.enabled)
                
                Spacer()
                
                // Copy button
                Button {
                    copyToClipboard()
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Copy to clipboard")
            }
            
            // Rationale
            Text(question.why)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 28)
        }
        .padding(10)
        .background(priorityColor.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(priorityColor.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var priorityBadge: some View {
        Text("\(question.priority)")
            .font(.caption.bold())
            .frame(width: 20, height: 20)
            .background(priorityColor)
            .foregroundStyle(.white)
            .clipShape(Circle())
    }
    
    private var priorityColor: Color {
        switch question.priority {
        case 1: return .red
        case 2: return .orange
        case 3: return .blue
        default: return .gray
        }
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(question.question, forType: .string)
        
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCopied = false
        }
    }
}

#Preview {
    SuggestedQuestionsView(questions: [
        SuggestedQuestion(question: "What's your timeline for making a decision?", why: "Need to understand decision process", priority: 1),
        SuggestedQuestion(question: "Who else is involved in the evaluation?", why: "Identify additional stakeholders", priority: 2),
        SuggestedQuestion(question: "What would success look like for you?", why: "Clarify metrics and expectations", priority: 3)
    ])
    .padding()
    .frame(width: 350)
}

