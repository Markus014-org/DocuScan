#!/usr/bin/env python3
"""Statische Schutzprüfungen für die opt-in-Erweiterung; ersetzen keinen iOS-Build."""
from pathlib import Path
r = Path(__file__).resolve().parents[1]
read = lambda name: (r / 'DokuScan' / name).read_text(encoding='utf-8')

preferences = read('ExtendedModels.swift')
for name in ('routingEnabled', 'tagsEnabled', 'redactionEnabled', 'remindersEnabled', 'presetsEnabled'):
    assert f'var {name} = false' in preferences, f'{name} muss standardmäßig ausgeschaltet sein'

home = read('HomeView.swift')
review = read('ReviewView.swift')
settings = read('SettingsView.swift')
archive = read('ArchiveView.swift')
checks = {
    '01 OCR-Belegpositionen': 'parse(segmentsByPage:' in read('FileNaming.swift'),
    '02 OCR korrigieren': 'applyOCRCorrection(' in review,
    '03 Scan-Qualität': 'ImageQuality.warnings(' in review,
    '04 PDF-Import': 'DocumentImport.load(urls:' in home,
    '05 Dubletten': 'duplicateWarning' in review,
    '06 Archiv': 'record.ocrText' in archive and 'PDFDocument(url:' in archive,
    '07 Ablageregeln': 'Beleg mit Ablageregeln' in home and 'if model.preferences.routingEnabled' in home,
    '08 Schlagwörter': 'if model.preferences.tagsEnabled' in review,
    '09 Komprimierung': 'preparedImage' in read('PDFCreator.swift'),
    '10 Schwärzung': 'if model.preferences.redactionEnabled' in review,
    '11 CSV': 'ArchiveStore.csvFile' in archive,
    '12 Erinnerung': 'if model.preferences.remindersEnabled' in review,
    '13 Händler merken': 'rememberMerchant(' in review,
    '14 Schnellvorlage': 'if model.preferences.presetsEnabled' in home,
    'Scanchris Bundle ID': 'de.markus014.scanchris' in (r / 'project.yml').read_text(),
    'GitHub Fastlane Secrets': 'FASTLANE_KEY_ID' in (r / '.github/workflows/testflight.yml').read_text(),
}
for name, passed in checks.items():
    assert passed, f'Fehlende Verbindung: {name}'
for name in ('routingEnabled', 'tagsEnabled', 'redactionEnabled', 'remindersEnabled', 'presetsEnabled'):
    assert f'$model.preferences.{name}' in settings, f'Fehlender Einstellungs-Schalter: {name}'
print(f'OK: {len(checks)} Funktions-Verknüpfungen und 5 Einstellungen geprüft')
