import SwiftUI
import AppKit

struct BugReportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var attachedImages: [(id: UUID, image: NSImage, name: String)] = []
    @State private var includeSystemInfo = true
    @State private var showError = false
    @State private var errorMessage = ""

    private let maxImages = 3

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "ladybug")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
                Text("Bug Report")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Constants.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider().background(Color.white.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Constants.Colors.textSecondary)
                        TextField("Brief summary of the issue", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundColor(Constants.Colors.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)
                            .onHover { h in if h { NSCursor.iBeam.push() } else { NSCursor.pop() } }
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Constants.Colors.textSecondary)
                        TextEditor(text: $description)
                            .font(.system(size: 13))
                            .foregroundColor(Constants.Colors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 100, maxHeight: 160)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)
                    }

                    // Screenshots
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Screenshots")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Constants.Colors.textSecondary)

                        // Attached images
                        if !attachedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(attachedImages, id: \.id) { item in
                                        imagePreview(item)
                                    }
                                }
                            }
                        }

                        if attachedImages.count < maxImages {
                            Button(action: chooseImage) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 13))
                                    Text("Add Image")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .hoverCursor()
                        }
                    }

                    // System info toggle
                    HStack {
                        Toggle(isOn: $includeSystemInfo) {
                            Text("Include system info")
                                .font(.system(size: 13))
                                .foregroundColor(Constants.Colors.textPrimary)
                        }
                        .toggleStyle(.checkbox)

                        Spacer()

                        if includeSystemInfo {
                            Text("v\(appVersion), \(Foundation.ProcessInfo.processInfo.operatingSystemVersionString)")
                                .font(.system(size: 10))
                                .foregroundColor(Constants.Colors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }

            Divider().background(Color.white.opacity(0.1))

            // Footer buttons
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                    .hoverCursor()

                Spacer()

                Button(action: submitReport) {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 11))
                        Text("Submit")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(title.isEmpty ? Color.blue.opacity(0.3) : Color.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(title.isEmpty)
                .hoverCursor()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 420, height: 480)
        .background(Constants.Colors.background)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onDrop(of: [.image], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Image Preview

    private func imagePreview(_ item: (id: UUID, image: NSImage, name: String)) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: item.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 60)
                .clipped()
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

            Button(action: {
                attachedImages.removeAll { $0.id == item.id }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.6)).frame(width: 16, height: 16))
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
            .hoverCursor()
        }
    }

    // MARK: - Actions

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.title = "Select Screenshot"
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp, .gif]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            guard attachedImages.count < maxImages else { break }
            if let image = NSImage(contentsOf: url) {
                attachedImages.append((id: UUID(), image: image, name: url.lastPathComponent))
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            guard attachedImages.count < maxImages else { break }
            provider.loadObject(ofClass: NSImage.self) { object, _ in
                if let image = object as? NSImage {
                    DispatchQueue.main.async {
                        attachedImages.append((id: UUID(), image: image, name: "dropped_image.png"))
                    }
                }
            }
        }
        return true
    }

    private func submitReport() {
        guard let service = NSSharingService(named: .composeEmail) else {
            errorMessage = "No email client configured. Please set up Mail.app or another email client."
            showError = true
            return
        }

        service.recipients = ["clover4282@gmail.com"]
        service.subject = "[Seeport Bug] \(title)"

        var body = description
        if includeSystemInfo {
            body += "\n\n---\nApp Version: v\(appVersion)\nmacOS: \(Foundation.ProcessInfo.processInfo.operatingSystemVersionString)"
        }

        var items: [Any] = [body]

        // Save images to temp files for attachment
        for (i, item) in attachedImages.enumerated() {
            if let tiff = item.image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let png = bitmap.representation(using: .png, properties: [:]) {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("seeport_bug_\(i).png")
                try? png.write(to: url)
                items.append(url)
            }
        }

        if service.canPerform(withItems: items) {
            service.perform(withItems: items)
            dismiss()
        } else {
            errorMessage = "Unable to compose email. Please check your email client setup."
            showError = true
        }
    }
}
