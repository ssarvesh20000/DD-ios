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

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "car.side")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                Text("DamageDoctor")
                    .font(.largeTitle.bold())

                Text("Take or select a photo of your car\nto detect damage")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Import from Files", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .fullScreenCover(isPresented: $showCamera) {
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
        }
    }
}

#Preview {
    HomeView()
}
