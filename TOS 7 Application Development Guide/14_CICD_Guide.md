# 14. CI/CD Guide

### 14.1 GitHub Actions Templates

**Required Repository Secrets:**
Configure in GitHub repository Settings → Secrets and Variables → Actions:

| Secret Name | Description | Required |
|---|---|---|
| `DOCKERHUB_USERNAME` | Docker Hub username (for pushing images) | Required for Docker apps |
| `DOCKERHUB_TOKEN` | Docker Hub access token (not password) | Required for Docker apps |
| `GPG_PRIVATE_KEY` | GPG private key for package signing (future) | Optional |
| `GPG_PASSPHRASE` | GPG key passphrase | Optional |

> Never hardcode credentials in workflow files. Always use GitHub Secrets.

**Deb Applications** use the following GitHub Actions workflow. Replace `<appid>` with your actual application ID and `./app-root` with your Deb package root directory path. `./app-root` must contain `DEBIAN/` and the payload under `usr/local/<appid>/` — `config.ini`, `<appid>.lang`, and the icon must be at `usr/local/<appid>/` inside the payload, never at the deb root (see Section 8.2).

```yaml
# .github/workflows/build-deb.yml
name: Build Deb Package

on:
  push:
    tags:
      - 'v*'
  pull_request:
    branches: [main]

jobs:
  build:
    strategy:
      matrix:
        arch: [amd64, arm64]
        include:
          - arch: amd64
            runner: ubuntu-latest
          - arch: arm64
            runner: ubuntu-latest

    runs-on: ${{ matrix.runner }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up QEMU (arm64)
        if: matrix.arch == 'arm64'
        uses: docker/setup-qemu-action@v3

      - name: Install build dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y dpkg-dev debhelper lintian

      - name: Build deb package
        run: |
          dpkg-deb --build ./app-root ./<appid>_${{ github.event.release.tag_name }}_${{ matrix.arch }}.deb

      - name: Validate package
        run: |
          dpkg-deb -c ./*.deb
          dpkg-deb -I ./*.deb
          lintian ./*.deb || true

      - name: Generate checksums
        run: |
          sha256sum ./*.deb > ./*.deb.sha256

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: deb-${{ matrix.arch }}
          path: |
            *.deb
            *.sha256

  release:
    needs: build
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/')

    steps:
      - name: Download artifacts
        uses: actions/download-artifact@v4

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            deb-amd64/*.deb
            deb-amd64/*.sha256
            deb-arm64/*.deb
            deb-arm64/*.sha256
```

### 14.2 Multi-Architecture Build

**Docker Applications:**

```yaml
# .github/workflows/build-docker.yml
name: Build and Push Docker Image

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: |
            ${{ secrets.DOCKERHUB_USERNAME }}/<appid>:latest
            ${{ secrets.DOCKERHUB_USERNAME }}/<appid>:${{ github.ref_name }}

      - name: Security scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: '${{ secrets.DOCKERHUB_USERNAME }}/<appid>:${{ github.ref_name }}'
          format: 'table'
          exit-code: '1'
          severity: 'CRITICAL,HIGH'
```

### 14.3 Automated Validation

Add a validation workflow to check configuration files on every push. The validation script should also check whether `type` and `open_path` exist simultaneously; if so, report an error.

```yaml
# .github/workflows/validate.yml
name: Validate Configuration

on:
  push:
  pull_request:

jobs:
  validate:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Validate config.ini (JSON format)
        run: |
          python3 -c "import json; json.load(open('config.ini'))"
          echo "config.ini JSON format is valid"

      - name: Validate required fields
        run: |
          python3 -c "
          import json
          config = json.load(open('config.ini'))
          required = ['id', 'icon', 'publisher', 'exec', 'version', 'low_version',
                      'category', 'depend', 'platform', 'application_type', 'user',
                      'all_user_display', 'allow_open_in_mobile']
          for field in required:
              assert field in config, f'Missing required field: {field}'
          
          # Validate Deb-specific fields
          if config['application_type'] == 'deb':
              assert config.get('system_id'), 'Deb application must have system_id'
              assert config.get('package'), 'Deb application must have package'
          
          # Validate category count
          assert len(config['category']) <= 3, 'Maximum 3 categories'
          
          # Validate type and open_path cannot coexist
          if 'type' in config and 'open_path' in config:
              raise AssertionError('type and open_path cannot both exist; choose only one')
          
          print('All validations passed!')
          "

      - name: Validate app.lang (14 languages)
        run: |
          python3 -c "
          required_langs = ['zh-cn', 'zh-hk', 'en-us', 'fr-fr', 'de-de', 
                           'it-it', 'es-es', 'hu-hu', 'ja-jp', 'ko-kr',
                           'pl-pl', 'ru-ru', 'tr-tr', 'pt-pt']
          with open('app.lang', 'r') as f:
              content = f.read()
          for lang in required_langs:
              assert f'[{lang}]' in content, f'Missing language: {lang}'
          print('All 14 languages present!')
          "

      - name: Validate icon (SVG format)
        run: |
          python3 -c "
          import json, os
          config = json.load(open('config.ini'))
          icon_path = config['icon']
          icon_file = icon_path.lstrip('/')
          assert os.path.exists(icon_file), f'Icon not found: {icon_file}'
          with open(icon_file, 'r') as f:
              content = f.read()
          assert '<svg' in content and '</svg>' in content, 'Not a valid SVG file'
          assert 'viewBox' in content, 'SVG missing viewBox attribute'
          print(f'Icon validation passed: {icon_file}')
          "

```

> **Gitee Actions (China-based Developers):** For developers hosting on Gitee, adapt the GitHub Actions workflows to the Gitee CI/CD format. Complete Gitee CI/CD templates are available on the TNAS Developer Platform. Gitee uses the `gitee-ci.yml` configuration format. Please refer to the Gitee documentation for environment setup.

### 14.4 Release & Upload

After a successful build:

1. Create a GitHub Release with the deb package and checksums
2. Update the repository's config.ini and app.lang if needed
3. Submit the new version through the TNAS Developer Platform
4. When submitting the version on the Developer Platform, select the Release (tag) and the package you just uploaded

---

← [Previous: Local Testing & Debugging](13_Local_Testing.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next: Publishing Process](15_Publishing_Process.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to TOC](../README.md)
