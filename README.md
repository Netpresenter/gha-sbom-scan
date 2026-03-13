# gha-sbom-scan

Centralized GitHub Action for SBOM generation and vulnerability scanning. Generates CycloneDX SBOMs and scans them with Grype.

## Scan Types

| `scan-type` | Tool | What it scans | Runner requirement |
|---|---|---|---|
| `source` | Syft | Directory (npm, pip, etc. via lockfiles) | Any |
| `image` | Syft | Container registry image | Any |
| `gradle` | cdxgen | Gradle project (resolved deps) | Java + Gradle set up |
| `cocoapods` | cyclonedx-cocoapods | Podfile.lock | Ruby (pre-installed on macOS runners) |

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `scan-type` | yes | - | `source`, `image`, `gradle`, `cocoapods` |
| `scan-target` | yes | - | Dir path, registry ref, gradle project dir, or Podfile path |
| `sbom-filename` | yes | - | Output SBOM filename (e.g. `sbom-source.cdx.json`) |
| `artifact-name` | yes | - | GitHub artifact name |
| `summary-title` | yes | - | Step summary heading |
| `grype-fail-on` | no | `""` | Fail on severity: `critical`, `high`, `medium`, `low`, or empty |
| `retention-days` | no | `90` | Artifact retention days |

## Outputs

| Output | Description |
|---|---|
| `sbom-path` | Path to the generated SBOM file |
| `vuln-count` | Total vulnerability count |
| `critical-count` | Critical vulnerability count |

## Usage

### Source scan (npm, pip, etc.)

```yaml
- uses: Netpresenter/gha-sbom-scan@v1
  with:
    scan-type: source
    scan-target: .
    sbom-filename: sbom-source.cdx.json
    artifact-name: sbom-source-${{ github.ref_name }}
    summary-title: "Source SBOM"
```

### Container image scan

```yaml
- uses: Netpresenter/gha-sbom-scan@v1
  with:
    scan-type: image
    scan-target: ghcr.io/myorg/myapp:latest
    sbom-filename: sbom-image.cdx.json
    artifact-name: sbom-image-${{ github.ref_name }}
    summary-title: "Image SBOM"
```

### Android native (Gradle)

Run after `ionic capacitor build android` (which generates the Gradle project) and before `./gradlew bundleRelease`:

```yaml
- name: Build Android
  run: ionic capacitor build android --release --prod --no-open

- name: SBOM scan Android native deps
  uses: Netpresenter/gha-sbom-scan@v1
  with:
    scan-type: gradle
    scan-target: ./android
    sbom-filename: sbom-android-native.cdx.json
    artifact-name: sbom-android-native-${{ github.ref_name }}
    summary-title: "Android Native SBOM"

- name: Build App Release Bundle
  working-directory: ./android/
  run: ./gradlew bundleRelease
```

### iOS native (CocoaPods)

Run after `npx cap sync --deployment ios` (which generates `Podfile.lock`) and before the build step:

```yaml
- name: Sync iOS
  run: npx cap sync --deployment ios

- name: SBOM scan iOS native deps
  uses: Netpresenter/gha-sbom-scan@v1
  with:
    scan-type: cocoapods
    scan-target: ios/App/Podfile
    sbom-filename: sbom-ios-native.cdx.json
    artifact-name: sbom-ios-native-${{ github.ref_name }}
    summary-title: "iOS Native SBOM"

- name: Build Signed IPA
  uses: yukiarrr/ios-build-action@v1.12.0
```

### Using the fail gate

Fail the workflow if vulnerabilities at or above a severity threshold are found:

```yaml
- uses: Netpresenter/gha-sbom-scan@v1
  with:
    scan-type: source
    scan-target: .
    sbom-filename: sbom-source.cdx.json
    artifact-name: sbom-source-${{ github.ref_name }}
    summary-title: "Source SBOM"
    grype-fail-on: critical
```

### Using outputs in downstream steps

```yaml
- name: SBOM scan
  id: sbom
  uses: Netpresenter/gha-sbom-scan@v1
  with:
    scan-type: source
    scan-target: .
    sbom-filename: sbom-source.cdx.json
    artifact-name: sbom-source
    summary-title: "Source SBOM"

- name: Check results
  run: |
    echo "Vulnerabilities: ${{ steps.sbom.outputs.vuln-count }}"
    echo "Critical: ${{ steps.sbom.outputs.critical-count }}"
```

## Migration from local composite action

If you currently have a local `.github/actions/sbom-scan/action.yml`, replace:

```yaml
# Before
- uses: ./.github/actions/sbom-scan
  with:
    scan-type: source
    scan-target: .
    sbom-filename: sbom-source.cdx.json
    artifact-name: sbom-source
    summary-title: "Source SBOM"

# After
- uses: Netpresenter/gha-sbom-scan@v1
  with:
    scan-type: source
    scan-target: .
    sbom-filename: sbom-source.cdx.json
    artifact-name: sbom-source
    summary-title: "Source SBOM"
```

The new action is fully backwards-compatible with existing `source` and `image` scan types, and adds `gradle` and `cocoapods` support plus the `grype-fail-on` and `retention-days` inputs.

## Versioning

- Pin to `@v1` for automatic minor/patch updates
- Pin to exact tags like `@v1.0.0` for full reproducibility
