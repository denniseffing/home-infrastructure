# Plan: Hörbuch-Downloads mit Shelfmark Lite automatisieren

Stand: 21.11.2026 · Status: Code umgesetzt und lokal validiert, nicht deployed

Die Manifeste, der Scan-Hook und Tests liegen unter
`kubernetes/apps/default/shelfmark/`; die Inbetriebnahme ist in
[`README.md`](kubernetes/apps/default/shelfmark/README.md) dokumentiert.
Es wurde nichts gepusht oder deployed und keine Laufzeitkonfiguration verändert.
Abgehakte Punkte beziehen sich auf Code bzw. ausdrücklich genannte Prüfungen;
die Laufzeitabnahme und Secret-/Kategorie-Erstellung bleiben offen.

Verifiziert: Shelfmark Lite `1.7.0` mit Digest
`sha256:b8bbc8ae26282c9cc765162719d2090142edf6c93c01c1eb430e51b1fa746ef2`,
SABnzbd-Downloadwurzel `/media-2/downloads/usenet/complete`,
Audiobookshelf-Library-ID `8715fc43-44c6-4843-9e94-96c056873511`.
Der neue Kategorieordner ist geplant, aber noch nicht angelegt; sein vollständiger
API-Pfad muss nach einem Testjob erneut geprüft werden.

Lokale Validierung: 30 Hook-/Konfigurationstests erfolgreich, beide
Kustomize-Builds erfolgreich, 112 Flux-Local-Tests inklusive Helm-Rendering
erfolgreich. Keine realen Downloads oder Scans ausgelöst.

## 1. Ziel und Entscheidung

Hörbücher über eine Weboberfläche suchen und herunterladen. Fertige Downloads
werden ohne manuelles Verschieben in die vorhandene Audiobookshelf-Bibliothek
einsortiert und dort automatisch eingelesen.

**Shelfmark Lite** wird als einziger zusätzlicher App-Dienst eingesetzt:

- Vorhandenes **Prowlarr** für die Suche auf den konfigurierten Indexern verwenden.
- Vorhandenes **SABnzbd** für Usenet-Downloads und das Entpacken verwenden.
- **Audiobookshelf** bleibt Bibliothek und Player.
- Shelfmarks lokale **SQLite-Datenbank** auf einem Longhorn-PVC speichern.
- **Kein zusätzliches PostgreSQL, Redis oder Valkey** erforderlich.
- Kein Chromium, FlareSolverr, Torrent-Client, VPN oder zusätzlicher Import-Dienst.

Nicht Teil der ersten Umsetzung: E-Books, Autoren-/Serienüberwachung, automatische
Qualitäts-Upgrades und M4B-Konvertierung. Shelfmark ist primär ein Such- und
Download-Werkzeug; noch nicht verfügbare Titel werden im normalen Workflow nicht
dauerhaft weiterverfolgt. Bei Anfragen anderer Nutzer kann eine Admin-Freigabe bzw.
Release-Auswahl erforderlich sein. Das ist nicht vollständig identisch mit Seerr.

## 2. Vorhandener Stand im Repository

Die Ausgangsangaben stammen aus den Manifesten. Downloadwurzel, Indexer-Fähigkeiten
und Bibliotheks-ID wurden bei der Umsetzung zusätzlich lesend geprüft; Details
stehen in der Shelfmark-README. Kein Shelfmark-Pod wurde gestartet.

| Komponente | Bestehende Konfiguration |
| --- | --- |
| Deployment-Muster | Flux-Kustomization, HelmRelease und OCIRepository für `bjw-s-labs/app-template`; Audiobookshelf verwendet Chart `5.3.0` |
| Namespace | `default` für Audiobookshelf, Prowlarr und SABnzbd |
| Audiobook-Bibliothek | NFS `192.168.178.52:/nfs/storage-2/audiobooks`, in Audiobookshelf unter `/audiobooks` |
| SABnzbd | Auf Node `rachel`; u. a. Hostpfad `/mnt/storage-2/plex` unter `/media` und `/media-2` |
| SABnzbd-Downloadordner | Lesend verifiziert: `/media-2/downloads/usenet/complete` |
| Dateirechte | Die vorhandenen Medien-Dienste verwenden UID/GID `1000:1000` |
| Secrets | External Secrets mit `ClusterSecretStore/onepassword-connect` |
| Interner Zugriff | `envoy-internal` mit bestehendem Pocket-ID/OIDC-Schutz auf Gateway-Ebene |
| Persistenz/Backups | Longhorn; bestehende Config-PVCs verwenden teils `longhorn-encrypted` und Labels für wöchentliche Backups |

Referenzen:

- `kubernetes/apps/default/audiobookshelf/app/helmrelease.yaml`
- `kubernetes/apps/default/audiobookshelf/app/pvc.yaml`
- `kubernetes/apps/default/prowlarr/app/helmrelease.yaml`
- `kubernetes/apps/default/sabnzbd/app/helmrelease.yaml`
- `kubernetes/infrastructure/network/envoy-gateway/app/envoy.yaml`

## 3. Zielarchitektur

```text
Browser → interner Envoy-Gateway → Shelfmark Lite
                                      │
                                      ├─ Prowlarr: Releases suchen
                                      ├─ SABnzbd: Download beauftragen und überwachen
                                      ├─ fertige Dateien aus Downloadordner importieren
                                      └─ nach Import Audiobookshelf-Scan auslösen

SABnzbd → separater Downloadordner → Shelfmark → /audiobooks/Autor/Titel/Dateien
                                                        │
                                                 Audiobookshelf
```

Der Scan wird durch ein kleines Skript **im Shelfmark-Container** ausgelöst.
Es gibt dafür keinen Sidecar, CronJob oder weiteren dauerhaft laufenden Dienst.

## 4. Voraussetzungen vor der Implementierung prüfen

- [x] Tatsächlichen fertigen Downloadordner und die vorhandenen Kategorien in
  SABnzbd auslesen. Die neue Kategorie fehlt noch; ihren Job-Pfad später verifizieren.
- [x] Zugehörigen NAS-Pfad/NFS-Export aus den Mounts bestimmen. Nicht annehmen, dass ein Download
  unter `/media` liegt, nur weil dieser Mount vorhanden ist.
- [x] Dedizierte SABnzbd-Kategorie **`shelfmark-audiobooks`** planen, einschließlich
  eines separaten Unterordners unter dem bestehenden fertigen Downloadordner.
  Die Kategorien und Pfade von Sonarr/Radarr unverändert lassen.
- [x] Hörbuch-Kategorien der drei vorhandenen Usenet-Indexer prüfen; sie unterstützen
  `Audio/Audiobook`. Suchergebnisse und Releases bleiben Teil der Laufzeitabnahme.
- [x] Audiobookshelf-Library-ID bestimmen; im HelmRelease hinterlegt.
- [ ] Dedizierte Audiobookshelf-Zugangsdaten für die API erstellen.
- [ ] NFS-Lese-/Schreibrechte für UID/GID `1000:1000` prüfen. Nicht pauschal die
  vorhandene Bibliothek rekursiv mit `chown` oder `chmod` verändern.
- [x] Für `ghcr.io/calibrain/shelfmark-lite` eine verfügbare stabile Version und
  den passenden Image-Digest ermitteln. Kein dauerhaftes `latest` einsetzen.
  Die unten genannten Optionen gegen **diese Version** prüfen.

Downloadwurzel, Library-ID und Image-Digest sind verifiziert und im HelmRelease
hinterlegt. Kategorieordner, tatsächlicher Job-Pfad, NFS-Schreibtests und der
dedizierte Admin-Token sind noch offene Inbetriebnahmewerte.

## 5. Geplante Dateien

```text
kubernetes/apps/default/shelfmark/
├── README.md
├── ks.yaml
├── app/
│   ├── kustomization.yaml
│   ├── ocirepository.yaml
│   ├── helmrelease.yaml
│   ├── pvc.yaml
│   ├── externalsecret.yaml
│   └── configmap.yaml          # Helm-Werte mit Post-Import-Scan-Skript
└── tests/
    └── test_post_import_scan.py
```

- [x] Neue App in `kubernetes/apps/default/kustomization.yaml` mit
  `shelfmark/ks.yaml` zwischen Seerr und Sonarr registrieren.
- [x] Flux-Kustomization nach dem Audiobookshelf-Muster anlegen, mit Namespace
  `default`, Label `denniseffing.de/source: "public"` sowie Longhorn-/SecretStore-Abhängigkeiten.
- [x] OCIRepository und HelmRelease nach dem bestehenden App-Template-Muster anlegen.
- [x] Vorhandene PostgreSQL-/Redis-/Valkey-Manifeste nicht verändern.

## 6. Deployment, Persistenz und Dateipfade

### App

- [x] Ein Replica; Update-Strategie `Recreate` für SQLite und den RWO-Config-PVC.
- [x] Container-Port `8084`; Service `shelfmark` auf diesem Port.
- [x] Liveness/Readiness auf `/api/health`; Startup-Probe mit bis zu 300 Sekunden.
- [x] Rootless mit `runAsNonRoot`, UID/GID/fsGroup `1000`,
  `allowPrivilegeEscalation: false`, entfernten Capabilities und RuntimeDefault-seccomp.
- [ ] Read-only Root-Dateisystem testen. Erforderliche Schreibpfade separat mounten;
  nicht wegen eines fehlenden Temp-Verzeichnisses auf Root-Betrieb wechseln.
- [ ] Ressourcen zunächst mit etwa `100m` CPU/`128Mi` RAM Requests und `512Mi`
  RAM Limit beginnen. Das sind Startwerte, keine gemessenen Anforderungen;
  Entpacken und größere Importe testen und bei Bedarf anpassen.

### Mounts

| Containerpfad | Quelle | Zweck |
| --- | --- | --- |
| `/config` | Neuer `shelfmark-config`-PVC, zunächst `2Gi`, `ReadWriteOnce`, `longhorn-encrypted` | SQLite, Einstellungen, Credentials und Cover-Cache |
| `/audiobooks` | Bestehendes NFS `192.168.178.52:/nfs/storage-2/audiobooks`, schreibbar | Finale Audiobookshelf-Bibliothek |
| `/downloads` | NFS `192.168.178.52:/nfs/storage-2/plex/downloads/usenet/complete/shelfmark-audiobooks`, read-only; neuer Ordner noch anzulegen | Ausschließlich Shelfmarks abgeschlossene Downloads |
| `/tmp` | Disk-basiertes `emptyDir`, nicht RAM-basiert | Temporäre Dateien und ggf. Entpacken |
| `/home/shelfmark` | `emptyDir`, `256Mi` | Vom non-root Entrypoint verlangter beschreibbarer Home-Pfad |
| `/scripts` | ConfigMap, read-only, Skript ausführbar | Scan nach erfolgreichem Import |

- [x] SQLite **nicht auf NFS** ablegen.
- [ ] Für `/tmp` ausreichend temporären Speicher einschließlich Entpackoverhead
  vorsehen. Limit anhand der erwarteten Hörbuchgrößen festlegen.
- [ ] Nur den dedizierten Download-Unterordner sichtbar machen, nicht sämtliche
  Plex-Medien mit Schreibzugriff. Bei Bedarf den vorhandenen Export mit `subPath`
  auf diesen Ordner beschränken; Ordner und NFS-Zugriff vorher prüfen.
- [x] Download-Mount read-only konfigurieren; Usenet-Copy-Verhalten gegen den Quellcode
  von `1.7.0` geprüft. Funktion im laufenden Container noch abnehmen.
- [ ] Da `/downloads` vom SABnzbd-Containerpfad abweichen kann, in Shelfmark unter
  **Advanced → Remote Path Mappings** den tatsächlich gemeldeten Kategoriepfad
  auf `/downloads` abbilden. Beide Seiten müssen dieselben Dateien sehen.
- [x] Keine Node-Bindung an `rachel` konfiguriert, sofern beide Medienpfade über NFS
  erreichbar sind. Bestehende NAS-Toleration bei Bedarf übernehmen.

SABnzbd lädt **nicht direkt in die Bibliothek**. Erst abgeschlossene Downloads
werden importiert. Dadurch erscheinen keine unvollständigen Bücher während des Downloads.

## 7. Shelfmark konfigurieren und Secrets anbinden

### Nicht geheime Ausgangskonfiguration

Diese Vorlage wurde gegen Version `1.7.0` geprüft; maßgeblich ist das HelmRelease.
Zusätzlich ist `OPENLIBRARY_ENABLED: "true"` gesetzt (Provider sonst standardmäßig aus).

```yaml
TZ: Europe/Berlin
FLASK_PORT: "8084"
CONFIG_DIR: /config
TMP_DIR: /tmp/shelfmark
ENABLE_LOGGING: "false" # Container-Logs statt Dateien im Root-Dateisystem
UMASK: "0022"
AUTH_METHOD: builtin
DEFAULT_CONTENT_TYPE: audiobook
SHOW_COMBINED_SELECTOR: "false"
SEARCH_MODE: universal
METADATA_PROVIDER_AUDIOBOOK: openlibrary
PROWLARR_ENABLED: "true"
PROWLARR_URL: http://prowlarr.default.svc.cluster.local
PROWLARR_USENET_CLIENT: sabnzbd
PROWLARR_AUTO_EXPAND: "false"
SABNZBD_URL: http://sabnzbd.default.svc.cluster.local
SABNZBD_CATEGORY: shelfmark-audiobooks
SABNZBD_CATEGORY_AUDIOBOOK: shelfmark-audiobooks
PROWLARR_USENET_ACTION: copy
INGEST_DIR: /audiobooks
DESTINATION_AUDIOBOOK: /audiobooks
FILE_ORGANIZATION_AUDIOBOOK: organize
TEMPLATE_AUDIOBOOK_ORGANIZE: "{Author}/{Title}/{OriginalName}"
HARDLINK_TORRENTS: "false"
HARDLINK_TORRENTS_AUDIOBOOK: "false"
MAX_CONCURRENT_DOWNLOADS: "1"
DIRECT_DOWNLOAD_ENABLED: "false"
USING_TOR: "false"
USING_WIREGUARD: "false"
LIBRARY_CHECK_AUDIOBOOKSHELF_ENABLED: "true"
AUDIOBOOKSHELF_URL: http://audiobookshelf.default.svc.cluster.local
AUDIOBOOK_LIBRARY_URL: https://audiobookshelf.internal.denniseffing.de
CUSTOM_SCRIPT: /scripts/post-import-scan.py
CUSTOM_SCRIPT_PATH_MODE: absolute
CUSTOM_SCRIPT_JSON_PAYLOAD: "true"
```

- [x] `AUDIOBOOKSHELF_LIBRARY_IDS` und die eigene Skriptvariable
  `ABS_SCAN_LIBRARY_ID` mit der verifizierten Library-ID ergänzen.
- [ ] Passende Prowlarr-Indexer auswählen, unnötige Quellen/Torrent-Clients deaktiviert
  lassen und deutsche Releases zunächst gezielt testen. Sprache aus Metadaten
  ist kein verlässlicher Nachweis für die Sprache jedes Releases.
- [x] Open Library benötigt für diesen Einstieg keinen neuen API-Key und ist aktiviert.
  Falls der Titel dort nicht gefunden wird, die direkte Prowlarr-Suche verwenden.
- [ ] Template mit einem einzelnen M4B und einem mehrteiligen MP3-Hörbuch prüfen:
  ein Ordner pro Buch, eindeutige Dateinamen und korrekte Kapitelreihenfolge.
- [ ] Zunächst Copy-Modus und keine automatische Download-Bereinigung verwenden.
  Tatsächliches Kopier-/Löschverhalten der Version testen. Bereinigung erst nach
  erfolgreicher Abnahme separat konfigurieren, ausschließlich für Shelfmark-Jobs.

In `1.7.0` haben gesetzte Env-Werte Vorrang und sind in der UI gesperrt.
Remote Path Mappings sind ausdrücklich UI-only und werden auf `/config` gespeichert.
Einmalige UI-Schritte sind dokumentiert; nutzerspezifische Overrides und UI-only
Einstellungen bleiben außerhalb vollständiger GitOps-Steuerung.

### Secrets

- [x] Neues `ExternalSecret/shelfmark` mit folgenden Zuordnungen anlegen:

  | 1Password-Item / Property | Shelfmark-Variable |
  | --- | --- |
  | `prowlarr` / `api-key` | `PROWLARR_API_KEY` |
  | `sabnzbd` / `api-key` | `SABNZBD_API_KEY` |
  | Neues Item `shelfmark` / `audiobookshelf-api-token` | `AUDIOBOOKSHELF_TOKEN` |

- [x] Nicht die bestehenden Secrets unverändert per `envFrom` übernehmen:
  Prowlarr/SABnzbd verwenden dort andere Variablennamen mit doppelten Unterstrichen.
- [ ] API-Token für ein dediziertes Audiobookshelf-Integrationskonto erstellen.
  **Der Scan-Endpunkt verlangt in Audiobookshelf 2.38.0 Admin-Rechte**; ein rein
  lesender Token reicht für diesen Hook nicht. Rechteumfang bewusst akzeptieren
  und den Token ausschließlich als Secret speichern.
- [x] Keine Schlüssel, Passwörter oder Token in Git, ConfigMaps oder Logs schreiben.

## 8. Bibliothek nach dem Import automatisch scannen

Shelfmarks eingebauter Library Check liest den vorhandenen Bestand. Er ist **kein**
automatischer Scan-Trigger. Bei NFS außerdem nicht allein auf Dateisystem-Watcher vertrauen.

- [x] Kleines Python-Skript in `configmap.yaml` bereitstellen und als ausführbare
  Datei `/scripts/post-import-scan.py` mounten. Python ist Teil der App;
  kein eigenes Image oder zusätzliches Paket voraussetzen.
- [x] Hook nur nach `phase=post_transfer` und für ein Ziel innerhalb von
  `/audiobooks` ausführen; JSON-Payload robust prüfen, keine Dateinamen als Befehle ausführen.
- [x] Mit Bearer-Token aus der Umgebung im Hook aufrufen (nur gemockt getestet):
  `POST http://audiobookshelf.default.svc.cluster.local/api/libraries/<ID>/scan`.
  Kein `force=1` und kein pauschales Neu-Matching vorhandener Metadaten.
- [x] HTTP-Zeitlimit und begrenzte Wiederholungen vorsehen: drei Versuche à 60 Sekunden,
  5/10 Sekunden Pause, globale Deadline 240 Sekunden. ABS `2.38.0` bestätigt den
  Auftrag sofort; Scan-Abschluss anschließend prüfen.
- [x] Bei Scan-Ausfall eine tokenfreie Warnung loggen und den bereits erfolgreichen
  Dateiimport **nicht** als fehlgeschlagen markieren: Exit-Code `0`, Dateien behalten,
  keinen erneuten Download oder Löschvorgang anstoßen. Ein manueller Bibliotheksscan
  bleibt der Notfallweg; manuelles Dateiverschieben ist nicht nötig.
- [x] Bei Skriptänderungen einen Pod-Rollout über Helm-ConfigMap-Checksum sicherstellen.

## 9. Zugriff und einmalige Inbetriebnahme

- [x] Ausschließlich `shelfmark.internal.denniseffing.de` am bestehenden
  `envoy-internal` als Route konfigurieren. Keine externe Route erstellt.
- [x] Bestehenden Gateway-OIDC-Schutz erben; im Minimalsetup keine Auth-Ausnahme
  per leerer SecurityPolicy anlegen.
- [ ] Lokalen Shelfmark-Admin im Einrichtungsdialog anlegen. `builtin` schützt
  zusätzlich direkte App-Zugriffe und ermöglicht Shelfmarks Nutzerrollen.
  Gateway-Login und Shelfmark-Login sind zunächst zwei getrennte Anmeldungen.
- [ ] Prowlarr-, SABnzbd- und Audiobookshelf-Verbindungen testen, Library-ID und
  Remote Path Mapping setzen, anschließend einen Testdownload starten.
- [ ] Für weitere Nutzer bei Bedarf Request-/Freigaberegeln einrichten. Für den
  eigenen Admin-Account reicht direkte Release-Auswahl mit anschließendem Download.

Optional nach der Abnahme: Shelfmarks natives OIDC an das vorhandene Pocket ID
anbinden, um den zusätzlichen lokalen Login abzulösen. Dann eigenen OIDC-Client,
Callback und gezielte Envoy-Auth-Ausnahme planen. Das ist keine Voraussetzung für
die Download-Automatisierung und führt keinen neuen Identity-Dienst ein.

## 10. Validierung und Abnahmekriterien

### Vor dem Deployment

- [x] `kustomize build kubernetes/apps/default/shelfmark/app` prüfen.
- [x] `kustomize build kubernetes/apps/default` prüfen.
- [x] Bestehenden Flux-Local-Test mit Helm-Rendering verwenden
  (`.github/workflows/flux-local.yaml`, Einstieg `kubernetes/cluster`).
- [x] Scan-Skript auf Syntax, ungültige Payloads, Pfadbegrenzung und Fehlerfälle prüfen.
- [x] Gerenderte Mounts, Secret-Namen, HTTPRoute und Replica-Zahl kontrollieren.

### Nach Deployment über Flux

- [ ] Config-PVC ist gebunden, ExternalSecret ist bereit, HelmRelease und Pod sind gesund.
- [ ] Interne HTTPS-Route ist erreichbar und geschützt; kein unautorisierter Zugriff
  auf Shelfmarks Einstellungen oder API.
- [ ] Rootless/read-only Betrieb funktioniert ohne Rechtefehler.
- [ ] Suche findet geeignete Hörbuch-Releases über die ausgewählten Indexer.
- [ ] Rechtmäßig verfügbarer Testdownload landet ausschließlich in der neuen
  SABnzbd-Kategorie und wird vollständig entpackt.
- [ ] Shelfmark erkennt den Downloadpfad und importiert die Dateien automatisch
  in die bestehende Bibliothek, ohne andere Medien zu verändern.
- [ ] Tests mit Einzeldatei, mehrteiligen Audiodateien und Archiv erfolgreich.
- [ ] Audiobookshelf zeigt das neue Buch nach dem Hook ohne manuelles Verschieben
  oder manuelles Scannen; Wiedergabe und Reihenfolge stimmen.
- [ ] Bereits vorhandene Titel werden bestmöglich erkannt. Doppelanfragen dürfen
  vorhandene Dateien nicht still überschreiben; das Verhalten gezielt testen.
- [ ] Pod-Neustart erhält Nutzer, Einstellungen und Download-Historie.
- [ ] Ausfall von SABnzbd, NFS oder Audiobookshelf führt zu verständlichen Fehlern,
  nicht zu Datenverlust oder Veränderungen an Sonarr/Radarr-Jobs.

**Abnahme:** Suchen bzw. Release auswählen → herunterladen → automatisch in
Audiobookshelf verfügbar. Genau ein zusätzlicher App-Pod, ohne neuen Datenbankdienst.

## 11. Backups und Rücknahme

- [x] `shelfmark-config` mit den vorhandenen Longhorn-Labels für wöchentliche Backups
  versehen. Config enthält auch Zugangsdaten und ist entsprechend zu schützen.
- [x] Für den neuen Config-PVC `kustomize.toolkit.fluxcd.io/prune: disabled` vorsehen,
  damit das Entfernen der App aus Git nicht automatisch ihre Konfiguration löscht.
- [ ] Nach Inbetriebnahme Backup/Restore der SQLite-Konfiguration prüfen.
  Die Hörbuchdateien liegen separat auf dem NAS; der Config-PVC sichert sie nicht.
- [ ] Bei Problemen zunächst Shelfmark über Git auf null Replicas setzen.
  Prowlarr, SABnzbd und Audiobookshelf bleiben bestehen und benutzbar.
- [ ] Bei vollständiger Rücknahme nur Shelfmark-Route, App und dedizierte Kategorie
  entfernen; Config-PVC und importierte Hörbücher ohne ausdrückliche Freigabe behalten.

## Quellen für die Umsetzung

- [Shelfmark README, Umfang und Rootless-Betrieb](https://github.com/calibrain/shelfmark)
- [Shelfmark Lite Image](https://github.com/calibrain/shelfmark/blob/main/compose/docker-compose.lite.yml)
- [Mounts und Remote Path Mappings](https://github.com/calibrain/shelfmark/blob/main/docs/configuration.md)
- [Konfigurationsvariablen](https://github.com/calibrain/shelfmark/blob/main/docs/environment-variables.md)
- [Post-Download-Skripte](https://github.com/calibrain/shelfmark/blob/main/docs/custom-scripts.md)
- [Audiobookshelf API](https://api.audiobookshelf.org/)
