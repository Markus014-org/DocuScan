import SwiftUI
import VisionKit
import PhotosUI
import UniformTypeIdentifiers

/// Eine abgeschlossene Aufnahme bleibt bis zur Anzeige vollständig erhalten.
/// So kann SwiftUI keine leere Review-Ansicht mit veralteten @State-Daten öffnen.
private struct ScanSession: Identifiable {
    let id = UUID()
    let images: [UIImage]
    let kind: ScanKind
    let folderID: UUID?
    let ruleMode: Bool
    let presetCategory: String
    let filenameTemplate: String
}

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var scanKind: ScanKind = .document
    @State private var ruleMode = false
    @State private var presetCategory = ""
    @State private var filenameTemplate = ""
    @State private var showArchive = false
    @State private var showImport = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var chosenFolderID: UUID?
    @State private var showScanner = false
    @State private var pendingScan: ScanSession?
    @State private var activeScan: ScanSession?
    @State private var showSettings = false
    @State private var showInformation = false
    @State private var showFavorites = false
    @State private var showCameraError = false
    @State private var cameraError = ""
    @State private var versionResult = UpdateChecker.CheckResult(banner: nil, details: "Versionsprüfung noch nicht durchgeführt.")
    @State private var showVersionDetails = false

    var body: some View {
        NavigationStack {
            ZStack {
                DokuTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let versionBanner = versionResult.banner {
                            Button {
                                if let url = URL(string: "https://testflight.apple.com/") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Label(versionBanner, systemImage: "arrow.down.circle.fill")
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

                        if model.preferences.routingEnabled {
                            Button {
                                if model.rules.isEmpty {
                                    cameraError = "Bitte zuerst in Einstellungen → Ablageregeln eine Regel anlegen."
                                    showCameraError = true
                                } else {
                                    begin(kind: .receipt, folder: nil, useRules: true)
                                }
                            } label: {
                                Label("Beleg mit Ablageregeln", systemImage: "arrow.triangle.branch")
                            }
                            .buttonStyle(PrimaryActionStyle(tint: DokuTheme.turquoise))
                        }

                        if model.preferences.presetsEnabled && !model.presets.isEmpty {
                            Menu {
                                ForEach(model.presets) { preset in
                                    Button(preset.name) { startPreset(preset) }
                                }
                            } label: { Label("Scan-Vorlage starten", systemImage: "square.stack") }
                                .buttonStyle(.bordered)
                        }

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
                        Button("Archiv & Ausgaben", systemImage: "tray.full") { showArchive = true }
                        Button("PDF oder Bild importieren", systemImage: "doc.badge.plus") { showImport = true }
                        PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 30, matching: .images) {
                            Label("Fotos importieren", systemImage: "photo.on.rectangle")
                        }
                        Button("Favoriten", systemImage: "star") { showFavorites = true }
                        Button("TestFlight-Build prüfen", systemImage: "arrow.clockwise") {
                            Task {
                                await refreshVersion()
                                showVersionDetails = true
                            }
                        }
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
            .sheet(isPresented: $showArchive) { NavigationStack { ArchiveView() } }
            .fileImporter(isPresented: $showImport, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
                do { openImported(images: try DocumentImport.load(urls: result.get())) }
                catch { cameraError = error.localizedDescription; showCameraError = true }
            }
            .onChange(of: selectedPhotos) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    var images: [UIImage] = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) { images.append(image.pixelsUpright()) }
                    }
                    selectedPhotos = []
                    if !images.isEmpty { openImported(images: images) }
                    else { cameraError = "Keines der Fotos konnte gelesen werden."; showCameraError = true }
                }
            }
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
                            pendingScan = ScanSession(images: result, kind: scanKind, folderID: chosenFolderID, ruleMode: ruleMode, presetCategory: presetCategory, filenameTemplate: filenameTemplate)
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
                    ReviewView(initialImages: session.images, kind: session.kind, receiptFolderID: session.folderID, ruleMode: session.ruleMode, presetCategory: session.presetCategory, filenameTemplate: session.filenameTemplate)
                }
                .id(session.id)
            }
            .alert("TestFlight-Buildprüfung", isPresented: $showVersionDetails) {
                Button("OK", role: .cancel) {}
            } message: { Text(versionResult.details) }
            .alert("Scanner", isPresented: $showCameraError) {
                Button("OK", role: .cancel) {}
            } message: { Text(cameraError) }
            .task { await refreshVersion() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshVersion() } }
            }
        }
    }

    private func begin(kind: ScanKind, folder: UUID?, useRules: Bool = false, category: String = "", template: String = "") {
        guard VNDocumentCameraViewController.isSupported else {
            cameraError = "Der Dokumentenscanner wird auf diesem Gerät nicht unterstützt. Bitte auf einem iPhone mit Kamera testen."
            showCameraError = true
            return
        }
        scanKind = kind
        ruleMode = useRules
        presetCategory = category
        filenameTemplate = template
        chosenFolderID = folder
        pendingScan = nil
        showScanner = true
    }

    private func startPreset(_ preset: ScanPreset) {
        guard model.preferences.presetsEnabled else { return }
        let kind: ScanKind = preset.kind == "receipt" ? .receipt : .document
        if kind == .receipt && preset.folderID == nil {
            cameraError = "Für diese Belegvorlage muss in Einstellungen → Scan-Vorlagen ein Zielordner gewählt werden."
            showCameraError = true
            return
        }
        begin(kind: kind, folder: kind == .receipt ? preset.folderID : nil,
              category: model.preferences.tagsEnabled ? preset.category : "", template: preset.filenameTemplate)
    }

    private func openImported(images: [UIImage]) {
        guard !images.isEmpty else { return }
        activeScan = ScanSession(images: images, kind: .document, folderID: nil, ruleMode: false, presetCategory: "", filenameTemplate: "")
    }

    private func refreshVersion() async {
        let result = await UpdateChecker.check()
        versionResult = result
        model.newerTestFlightBuild = result.hasNewerBuild
    }
}
