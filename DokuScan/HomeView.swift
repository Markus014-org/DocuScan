import SwiftUI
import VisionKit

/// Eine abgeschlossene Aufnahme bleibt bis zur Anzeige vollständig erhalten.
/// So kann SwiftUI keine leere Review-Ansicht mit veralteten @State-Daten öffnen.
private struct ScanSession: Identifiable {
    let id = UUID()
    let images: [UIImage]
    let kind: ScanKind
    let folderID: UUID?
}

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var scanKind: ScanKind = .document
    @State private var chosenFolderID: UUID?
    @State private var showScanner = false
    @State private var pendingScan: ScanSession?
    @State private var activeScan: ScanSession?
    @State private var showSettings = false
    @State private var showInformation = false
    @State private var showFavorites = false
    @State private var showCameraError = false
    @State private var cameraError = ""

    var body: some View {
        NavigationStack {
            ZStack {
                DokuTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if model.newerTestFlightBuild {
                            Button {
                                if let url = URL(string: "https://testflight.apple.com/") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Label("Neue Version in TestFlight verfügbar", systemImage: "arrow.down.circle.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(DokuTheme.turquoise)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityHint("TestFlight öffnen")
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .center) {
                                Image(systemName: "doc.text.viewfinder")
                                    .font(.system(size: 39, weight: .semibold))
                                    .foregroundStyle(DokuTheme.orange)
                                Text("Scanchris")
                                    .font(.system(size: 39, weight: .bold, design: .rounded))
                                    .foregroundStyle(DokuTheme.ink)
                            }
                            Text("Scannen. Erkennen. Ordnen.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 15)

                        VStack(alignment: .leading, spacing: 10) {
                            Label("Schnellstart", systemImage: "sparkles")
                                .font(.headline)
                                .foregroundStyle(DokuTheme.ink)
                            Text("Dokumente automatisch erfassen und als durchsuchbare A4-PDF speichern.")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        .surface()

                        Button {
                            begin(kind: .document, folder: nil)
                        } label: {
                            Label("Dokument scannen", systemImage: "doc.text.viewfinder")
                        }
                        .buttonStyle(PrimaryActionStyle())

                        Menu {
                            if model.folders.isEmpty {
                                Text("Noch kein Speicherort hinterlegt")
                            }
                            ForEach(model.folders) { folder in
                                Button {
                                    begin(kind: .receipt, folder: folder.id)
                                } label: {
                                    Label(folder.name, systemImage: "folder")
                                }
                            }
                            Divider()
                            Button {
                                showSettings = true
                            } label: {
                                Label("Neuer Speicherort", systemImage: "folder.badge.plus")
                            }
                        } label: {
                            Label("Beleg scannen", systemImage: "receipt")
                        }
                        .buttonStyle(PrimaryActionStyle(tint: DokuTheme.ink))

                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(DokuTheme.turquoise)
                            Text("Texterkennung auf dem iPhone. Dateien nur an deinen gewählten Speicherorten.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Speicherorte · Einstellungen", systemImage: "gearshape") { showSettings = true }
                        Button("Favoriten", systemImage: "star") { showFavorites = true }
                        Button("Information", systemImage: "info.circle") { showInformation = true }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                    }
                    .accessibilityLabel("Menü")
                }
            }
            .sheet(isPresented: $showSettings) { NavigationStack { SettingsView() } }
            .sheet(isPresented: $showFavorites) { NavigationStack { FavoritesView() } }
            .sheet(isPresented: $showInformation) { NavigationStack { InformationView() } }
            .sheet(isPresented: $showScanner, onDismiss: {
                // Erst nach dem vollständigen Schließen des Scanners präsentieren.
                // Keine starre 0,35-Sekunden-Verzögerung und kein getrenntes images-State.
                if let session = pendingScan {
                    pendingScan = nil
                    activeScan = session
                }
            }) {
                CameraScanner(
                    onScanned: { result in
                        if result.isEmpty {
                            cameraError = "Der Scanner hat keine Seiten übergeben. Bitte erneut scannen."
                            showCameraError = true
                        } else {
                            pendingScan = ScanSession(images: result, kind: scanKind, folderID: chosenFolderID)
                        }
                        showScanner = false
                    },
                    onCancel: { showScanner = false },
                    onFailure: { message in
                        showScanner = false
                        cameraError = message
                        showCameraError = true
                    }
                )
                .ignoresSafeArea()
            }
            .fullScreenCover(item: $activeScan) { session in
                NavigationStack {
                    ReviewView(initialImages: session.images, kind: session.kind, receiptFolderID: session.folderID)
                }
                .id(session.id)
            }
            .alert("Scanner", isPresented: $showCameraError) {
                Button("OK", role: .cancel) {}
            } message: { Text(cameraError) }
            .task { await refreshVersion() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshVersion() } }
            }
        }
    }

    private func begin(kind: ScanKind, folder: UUID?) {
        guard VNDocumentCameraViewController.isSupported else {
            cameraError = "Der Dokumentenscanner wird auf diesem Gerät nicht unterstützt. Bitte auf einem iPhone mit Kamera testen."
            showCameraError = true
            return
        }
        scanKind = kind
        chosenFolderID = folder
        pendingScan = nil
        showScanner = true
    }

    private func refreshVersion() async {
        model.newerTestFlightBuild = await UpdateChecker.isNewBuildAvailable()
    }
}
