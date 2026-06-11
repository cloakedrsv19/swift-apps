import SwiftUI

struct ContentView: View {
    @State private var selectedItems: [(image: UIImage, filename: String)] = []
    @State private var isPickerPresented = false
    @State private var isProcessing = false
    @State private var results: [ImageResult] = []
    @State private var shareURL: URL?
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    imageSelectionSection
                    if isProcessing { processingIndicator }
                    if !results.isEmpty { resultsSection }
                }
                .padding()
            }
            .navigationTitle("Image Text Extractor")
            .toolbar { toolbarContent }
            .sheet(isPresented: $isPickerPresented) {
                ImagePicker(selectedItems: $selectedItems)
            }
            .sheet(item: $shareURL) { url in
                ShareSheet(url: url)
            }
        }
    }

    // MARK: - Sections

    private var imageSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Selected Images", systemImage: "photo.on.rectangle.angled")
                .font(.headline)

            if selectedItems.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(selectedItems.enumerated()), id: \.offset) { _, item in
                        Image(uiImage: item.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipped()
                            .cornerRadius(8)
                    }
                }
            }

            HStack {
                Button(selectedItems.isEmpty ? "Select Images" : "Change Selection") {
                    isPickerPresented = true
                }
                .buttonStyle(.bordered)

                if !selectedItems.isEmpty {
                    Spacer()
                    Button("Extract Text") {
                        Task { await runExtraction() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Images Selected",
            systemImage: "photo.badge.plus",
            description: Text("Tap \"Select Images\" to choose one or more images from your library.")
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var processingIndicator: some View {
        HStack {
            ProgressView()
            Text("Extracting text from \(selectedItems.count) image(s)…")
                .foregroundStyle(.secondary)
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Extracted Text", systemImage: "text.alignleft")
                    .font(.headline)
                Spacer()
                Button("Save & Share", systemImage: "square.and.arrow.up") {
                    saveAndShare()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
            }

            ForEach(results, id: \.filename) { result in
                ResultCard(result: result)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !results.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save & Share") { saveAndShare() }
            }
        }
    }

    // MARK: - Actions

    private func runExtraction() async {
        isProcessing = true
        results = []
        errorMessage = nil
        let processor = OCRProcessor()
        results = await processor.extractText(from: selectedItems)
        isProcessing = false
    }

    private func saveAndShare() {
        let body = results.map { result -> String in
            let divider = String(repeating: "=", count: 60)
            var block = "\(divider)\nFile: \(result.filename)\n\(divider)\n"
            if let error = result.error {
                block += "(extraction failed: \(error))"
            } else {
                block += result.text.isEmpty ? "(no text detected)" : result.text
            }
            return block
        }.joined(separator: "\n\n")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "extracted_text_\(formatter.string(from: Date())).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try body.write(to: url, atomically: true, encoding: .utf8)
            shareURL = url
        } catch {
            errorMessage = "Could not save file: \(error.localizedDescription)"
        }
    }
}

// MARK: - Result Card

struct ResultCard: View {
    let result: ImageResult
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                    Text(result.filename)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                if let error = result.error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if result.text.isEmpty {
                    Text("(no text detected)")
                        .italic()
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    Text(result.text)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
