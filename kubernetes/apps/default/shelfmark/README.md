# Shelfmark Lite

Hörbücher suchen und über die vorhandenen Prowlarr-Indexer und SABnzbd laden.
Shelfmark kopiert abgeschlossene Downloads nach `/audiobooks/Autor/Titel/Dateien`
und stößt anschließend einen Audiobookshelf-Scan an. Es wird nur ein zusätzlicher
App-Pod angelegt; SQLite und Einstellungen liegen auf dem Longhorn-Config-PVC.

**Stand: Code vorbereitet, nicht deployed.** Die folgenden Inbetriebnahmeschritte
sind bewusst nicht automatisiert und wurden nicht ausgeführt. Keine Änderungen
an bestehenden Sonarr-/Radarr-Kategorien, keine Download-Bereinigung.

## Verwendete Versionen und geprüfte Werte

- App-Template `5.3.0`, wie bei Audiobookshelf.
- Shelfmark Lite `1.7.0`, stabiler Release vom 13.11.2026, Multiarch-Digest
  `sha256:b8bbc8ae26282c9cc765162719d2090142edf6c93c01c1eb430e51b1fa746ef2`.
  Konfigurationsoptionen und Hook-Payload sind gegen diesen Release geprüft.
- SABnzbd meldet `/media-2/downloads/usenet/complete` als fertigen Downloadordner.
  `/media-2` stammt aus `/mnt/storage-2/plex` auf `rachel`; der bestehende
  NFS-Bind-Mount laut `k3s/cluster.yaml` ist `/nfs/storage-2`.
- Audiobookshelf-Bibliothek `Audiobooks`:
  `8715fc43-44c6-4843-9e94-96c056873511`, Ordner `/audiobooks`.
  ID und Ordner wurden lesend aus der laufenden SQLite-Datenbank geprüft.
- Prowlarr-Indexer `1` (NZBgeek), `2` (Scene NZBs), `3` (DrunkenSlug) sind aktiv,
  verwenden Usenet und bieten Hörbuch-Kategorien an. Scene NZBs bietet außerdem
  `Audio/Audiobook - DE`. Shelfmark sucht standardmäßig mit Kategorie `3030`;
  Prowlarr bildet sie auf die indexerspezifischen Kategorien ab.
- SABnzbd läuft als `1000:1000`; der fertige Downloadordner gehört `1000:1000`
  und ist beschreibbar. Audiobookshelfs Bibliothekswurzel gehört ebenfalls
  `1000:1000`. Ein echter Schreibtest über Shelfmarks NFS-Mounts steht noch aus.

## Vor der Inbetriebnahme erforderlich

1. **Dedizierte SABnzbd-Kategorie anlegen:**

   | Einstellung | Wert |
   | --- | --- |
   | Name | `shelfmark-audiobooks` |
   | Folder/Path, relativ zum fertigen Downloadordner | `shelfmark-audiobooks` |
   | Processing | `+Delete` / `3` (Reparieren, Entpacken, Archive entfernen) |
   | Script | keines |

   Der erwartete vollständige Client-Pfad ist danach
   `/media-2/downloads/usenet/complete/shelfmark-audiobooks/<Job>`.
   Die API-Pfade eines abgeschlossenen Testjobs nochmals überprüfen. Bestehende
   Kategorien und den globalen fertigen Downloadordner unverändert lassen.

2. **Nur den neuen Kategorieordner vorbereiten:**

   - NAS-/Hostpfad: `/mnt/storage-2/plex/downloads/usenet/complete/shelfmark-audiobooks`.
   - NFS-Pfad: `192.168.178.52:/nfs/storage-2/plex/downloads/usenet/complete/shelfmark-audiobooks`.
   - Den Ordner vor dem Deployment mit Eigentümer `1000:1000` anlegen und den
     Zugriff über den vorhandenen NFS-Export prüfen. Er existierte beim Auslesen
     noch nicht. Keine rekursiven Rechteänderungen an Downloads oder Bibliothek.
   - Das HelmRelease mountet **nur diesen Ordner**, read-only, nach `/downloads`.
     Falls der Server den direkten Unterordner-Mount nicht erlaubt, den
     bestehenden Export `/nfs/storage-2` mit `subPath:
     plex/downloads/usenet/complete/shelfmark-audiobooks` verwenden; die sichtbare
     Dateiauswahl nicht auf sämtliche Plex-Medien erweitern.
   - Bibliothek: `192.168.178.52:/nfs/storage-2/audiobooks` nach `/audiobooks`,
     schreibbar. Lese-/Schreibrechte für `1000:1000` vor einem Import testen.

3. **Audiobookshelf-Integrationskonto und Secret erstellen:**

   - Dediziertes Konto für Shelfmark mit Admin-Rechten. Audiobookshelf `2.38.0`
     verlangt `isAdminOrUp` für `POST /api/libraries/<ID>/scan`; ein lesender
     Token reicht nicht. Dieser Token besitzt mehr Rechte als nur Bibliothekslesen.
   - In 1Password ein Item `shelfmark` mit Property
     `audiobookshelf-api-token` anlegen. Keine Zugangsdaten in Git oder ConfigMaps.
   - `ExternalSecret/shelfmark` ordnet vorhandene `prowlarr/api-key` und
     `sabnzbd/api-key` ausdrücklich den Shelfmark-Variablen zu. Die bestehenden
     Secrets mit doppelten Unterstrichen werden nicht direkt übernommen.

## Einmaliges Setup in Shelfmark nach einem späteren Flux-Deployment

1. `https://shelfmark.internal.denniseffing.de` öffnen. Die einzige Route erbt
   den bestehenden Envoy-/Pocket-ID-Schutz; es gibt keine externe Route und keine
   SecurityPolicy-Ausnahme. Im Shelfmark-Setup einen lokalen Admin anlegen.
   Gateway-Login und Shelfmark-Login sind zunächst getrennt.
2. Prowlarr-, SABnzbd- und Audiobookshelf-Verbindungen testen. Die konfigurierte
   Library-ID mit der aktuellen Audiobookshelf-Bibliothek abgleichen.
3. **Settings → Advanced → Remote Path Mappings** hinzufügen:

   | Client | Remote Path | Local Path |
   | --- | --- | --- |
   | `sabnzbd` | `/media-2/downloads/usenet/complete/shelfmark-audiobooks` | `/downloads` |

   `PROWLARR_REMOTE_PATH_MAPPINGS` ist in Version `1.7.0` ausdrücklich UI-only
   (`env_supported=False`), daher kein wirkungsloser Env-Eintrag im HelmRelease.
   Die Zuordnung bleibt unter `/config/plugins/advanced.json` persistent.
4. Default ist Hörbuch, Sprache `de`, Open Library als Metadatenquelle,
   Prowlarr als einzige konfigurierte Release-Quelle, SABnzbd im **Copy-Modus**.
   Open Library wird ausdrücklich aktiviert. Falls dort Metadaten fehlen, direkt
   in Prowlarr suchen. Sprache eines Releases immer separat prüfen.
5. Nach einem erfolgreichen Import in den Container-Logs auf
   `[shelfmark-scan] INFO: Audiobookshelf accepted the library scan.` achten.
   Audiobookshelf bestätigt in `2.38.0` den Scan-Auftrag sofort; HTTP-Erfolg ist
   noch kein Nachweis, dass der anschließende Scan abgeschlossen ist.

In Version `1.7.0` haben gesetzte Env-Werte Vorrang vor gespeicherten Einstellungen
und sind in der UI gesperrt. Änderungen an diesen Werten erfolgen im HelmRelease.
UI-only Einstellungen und nutzerspezifische Overrides liegen auf dem Config-PVC.
Es gibt keine automatische Download-Bereinigung; der Client-Job und seine Dateien
bleiben im Copy-Modus erhalten. Nicht auf Move oder Hardlinks umstellen, solange
die Abnahmetests nicht abgeschlossen sind.

## Scan-Hook und Betrieb

`app/configmap.yaml` enthält nicht geheime Helm-Werte mit dem Python-Hook.
Helm erzeugt daraus `ConfigMap/shelfmark-scripts`, mountet ihn ausführbar nach
`/scripts` und nimmt den Inhalt in `checksum/configMaps` des Pod-Templates auf.
Das Watch-Label an `shelfmark-values` löst bei Änderungen eine Helm-Reconciliation
aus; die neue Checksum sorgt für einen Pod-Rollout. Kein Reloader oder Sidecar nötig.

Der Hook akzeptiert ausschließlich Payload-Version `1`, `phase=post_transfer`,
Folder-Output und absolute Ziel-/Dateipfade innerhalb von `/audiobooks`.
Symlinks und `..` werden vor der Pfadprüfung aufgelöst. Dateinamen werden nie als
Befehle ausgeführt. Der Token wird nicht an Redirect-Ziele weitergereicht.
Maximal drei HTTP-Versuche à 60 Sekunden, Pausen von 5/10 Sekunden und ein globales
240-Sekunden-Zeitlimit bleiben unter Shelfmarks 300 Sekunden. Kein `force=1`.

Bei Fehlern bleibt der Hook erfolgreich (Exit-Code `0`) und behält die importierten
Dateien. Warnungen enthalten keine Payloads, URLs oder Token. Weil Shelfmark
`1.7.0` stderr erfolgreicher Hooks verwirft, schreibt der Hook die gleichen
Meldungen im Container zusätzlich auf stdout des App-Elternprozesses; das muss
bei der Laufzeitabnahme ebenfalls geprüft werden. Notfallweg ist ein manueller
Audiobookshelf-Bibliotheksscan, nicht erneutes Herunterladen oder Verschieben.

Der Container läuft als `1000:1000` mit schreibgeschütztem Root-Dateisystem.
Separat beschreibbar sind `/config`, `/audiobooks`, disk-basiertes `/tmp` (20Gi)
und `/home/shelfmark` (256Mi). Das zusätzliche Home-Mount ist nötig, weil der
non-root Entrypoint den Home-Pfad aus `/etc/passwd` bestimmt. Es ist flüchtig;
SQLite und sämtliche persistenten Einstellungen bleiben auf `/config`.
CPU-/RAM-/Ephemeral-Storage-Werte sind Startbudgets, keine gemessenen Anforderungen.
Freien Node-Speicher und größere Archiv-Importe vor der Abnahme prüfen.

## Lokale Validierung (ohne Deployment)

Der Hook-Test liest exakt den eingebetteten Skriptinhalt; er benötigt Python 3.10+
und PyYAML, keine Shelfmark-Pakete. Alle API-Aufrufe werden gemockt.

```bash
python3 -B -m unittest discover -s kubernetes/apps/default/shelfmark/tests -v
kustomize build kubernetes/apps/default/shelfmark/app
kustomize build kubernetes/apps/default
flux-local test --enable-helm --all-namespaces --path kubernetes/cluster \
  --sources flux-system --label-selector 'denniseffing.de/source=public' -v
```

Die bestehende `.github/workflows/flux-local.yaml` führt auch die Hook-Tests aus.

## Noch offene Laufzeitabnahme

- Config-PVC gebunden, ExternalSecret/HelmRelease/Pod gesund; lokale Authentifizierung
  und interne HTTPS-Route geschützt, auch kein ungeschützter Einstellungs-/API-Zugriff.
- Rootless/read-only Betrieb, Schreibrechte, tatsächliche NFS-Mounts und das
  Remote Path Mapping funktionieren nach einem Pod-Neustart.
- Rechtmäßig verfügbarer Test mit einzelnem M4B, mehrteiligen MP3-Dateien und Archiv:
  nur die neue SABnzbd-Kategorie wird benutzt, ein Ordner pro Buch, eindeutige Namen,
  korrekte Reihenfolge, automatische Sichtbarkeit und Wiedergabe in Audiobookshelf.
- Vorhandene Bücher/Doppelanfragen erkennen; keine stillen Überschreibungen.
- Ausfall von SABnzbd, NFS oder Audiobookshelf verändert keine anderen Medien/Jobs.
  Scan-Ausfall muss eine sichtbare Warnung erzeugen und den Import erhalten.
- Config/SQLite-Backup und Restore prüfen. Wöchentliche Longhorn-Backups sind
  gelabelt; Hörbuchdateien auf NFS werden vom Config-Backup nicht gesichert.

Zur Rücknahme zunächst `controllers.shelfmark.replicas: 0` setzen. Das Entfernen
der App darf den Config-PVC nicht prunen; `prune: disabled` schützt ihn. Bei einer
späteren vollständigen Rücknahme nur Shelfmark und seine dedizierte Kategorie
entfernen. PVC und bereits importierte Hörbücher ohne ausdrückliche Freigabe behalten.

## Referenzen

- [Shelfmark Release 1.7.0](https://github.com/calibrain/shelfmark/releases/tag/v1.7.0)
- [Variablen für 1.7.0](https://github.com/calibrain/shelfmark/blob/v1.7.0/docs/environment-variables.md)
- [Entrypoint für 1.7.0](https://github.com/calibrain/shelfmark/blob/v1.7.0/entrypoint.sh)
- [Remote Path Mappings](https://github.com/calibrain/shelfmark/blob/v1.7.0/shelfmark/config/settings.py)
- [Hook-Ausführung](https://github.com/calibrain/shelfmark/blob/v1.7.0/shelfmark/download/postprocess/custom_script.py)
- [Usenet-Dateiverarbeitung](https://github.com/calibrain/shelfmark/blob/v1.7.0/shelfmark/download/outputs/folder.py)
- [Audiobookshelf-Scan-Endpunkt 2.38.0](https://github.com/advplyr/audiobookshelf/blob/v2.38.0/server/controllers/LibraryController.js)
