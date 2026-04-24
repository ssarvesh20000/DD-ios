import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

struct HomeView: View {
    @State private var selectedImage: UIImage?
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false
    @State private var navigateToResults = false
    @State private var navigateToHistory = false

    @Environment(\.colorScheme) private var scheme
    private var theme: DDTheme { DDTheme(scheme: scheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Brand row
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.accent)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white)
                            )
                        Text("DamageDoctor")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(theme.text)
                        Spacer()
                    }
                    .padding(.bottom, 22)

                    // Headline
                    Text("Document damage\nwith confidence.")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-0.6)
                        .lineSpacing(-4)
                        .foregroundStyle(theme.text)

                    Text("AI-verified photos, ready to share with your insurer or buyer.")
                        .font(.system(size: 15))
                        .foregroundStyle(theme.secondary)
                        .lineSpacing(15 * 0.4)
                        .padding(.top, 10)

                    // History card
                    HistoryCard {
                        navigateToHistory = true
                    }
                    .padding(.top, 20)

                    // Primary CTA
                    Button {
                        showCamera = true
                    } label: {
                        Label("Start new inspection", systemImage: "camera.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(theme.accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: theme.accent.opacity(scheme == .dark ? 0 : 0.22),
                                    radius: 14, x: 0, y: 4)
                    }
                    .padding(.top, 16)

                    // Secondary row
                    HStack(spacing: 10) {
                        Button {
                            showPhotoPicker = true
                        } label: {
                            Text("Library")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .foregroundStyle(theme.text)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.border, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Button {
                            showFileImporter = true
                        } label: {
                            Text("Files")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .foregroundStyle(theme.text)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.border, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.top, 10)

                    TrustSignalRow()
                        .padding(.top, 22)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .background(theme.bg.ignoresSafeArea())
            .fullScreenCover(isPresented: $showCamera) {
                // TODO: move the "close-up in good lighting" framing tip into CameraView
                // as an overlay (previously a Home subheading).
                CameraView(image: $selectedImage)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPicker(image: $selectedImage)
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image]) { result in
                if case .success(let url) = result,
                   url.startAccessingSecurityScopedResource(),
                   let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    url.stopAccessingSecurityScopedResource()
                    selectedImage = image
                }
            }
            .onChange(of: selectedImage) {
                if selectedImage != nil {
                    navigateToResults = true
                }
            }
            .navigationDestination(isPresented: $navigateToResults) {
                if let image = selectedImage {
                    ResultsView(image: image)
                }
            }
            .navigationDestination(isPresented: $navigateToHistory) {
                HistoryView()
            }
        }
    }
}

#Preview {
    HomeView()
}
