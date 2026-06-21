name: Centralized Org APT Auto-Scanner & Publisher

on:
  workflow_dispatch: # Single-click manual button with no inputs
  schedule:
    - cron: '0 */6 * * *' # Automated check every 6 hours

permissions:
  contents: write
  pages: write
  id-token: write

jobs:
  scan-and-build:
    runs-on: ubuntu-24.04-arm

    steps:
      - name: Checkout Existing APT Pages Pool & State
        uses: actions/checkout@v4
        with:
          ref: gh-pages
          path: public
        continue-on-error: true # Safely ignores failures on the very first run

      - name: Install Build & Parsing Tools
        run: |
          sudo apt-get update
          sudo apt-get install -y devscripts equivs build-essential dpkg-dev apt-utils apt jq
          mkdir -p new-output

      - name: Scan Account Repositories
        env:
          # The auto-generated secrets.GITHUB_TOKEN is an installation token scoped
          # ONLY to this repo - it cannot list or read sibling repos in the org, even
          # public ones. Use a PAT instead (classic PAT with `repo` + `read:org` scopes,
          # or a fine-grained PAT scoped to the org with Contents:Read + Metadata:Read
          # on all repos), stored as the ORG_SCAN_TOKEN secret.
          GH_TOKEN: ${{ secrets.ORG_SCAN_TOKEN }}
        run: |
          OWNER="${{ github.repository_owner }}"
          # github.event.repository.name depends on the event payload and isn't always
          # populated (e.g. some schedule contexts). GITHUB_REPOSITORY (owner/repo) is
          # always set by the runner, so derive the name from that instead.
          CURRENT_REPO="${GITHUB_REPOSITORY#*/}"
          
          # Initialize metadata tracking state file if missing
          mkdir -p public
          if [ ! -f public/state.json ]; then
            echo "{}" > public/state.json
          fi

          # Determine if OWNER is an Organization or a Personal User Account dynamically
          ACCOUNT_TYPE=$(gh api users/$OWNER --jq '.type')
          echo "Account Type Detected: $ACCOUNT_TYPE for owner $OWNER"

          if [ "$ACCOUNT_TYPE" = "Organization" ]; then
            REPOS=$(gh api orgs/$OWNER/repos --paginate --jq '.[] | .name')
          else
            # If it's a regular user account, fetch all public repositories owned by this user
            REPOS=$(gh api users/$OWNER/repos --paginate --jq '.[] | select(.private == false) | .name')
          fi

          echo "Found repositories to check: $(echo $REPOS | tr '\n' ' ')"
          echo "Total repositories to scan: $(echo "$REPOS" | grep -c . || echo 0)"

          for REPO in $REPOS; do
            if [ "$REPO" = "$CURRENT_REPO" ]; then
              continue
            fi

            echo "--------------------------------------------------"
            echo "Processing Repository: $REPO"
            
            # Try getting HEAD commit SHA. If it fails, look up the explicit default branch
            LATEST_SHA=$(gh api repos/$OWNER/$REPO/commits/HEAD --jq '.sha' 2>/dev/null || echo "")
            if [ -z "$LATEST_SHA" ]; then
              DEFAULT_BRANCH=$(gh api repos/$OWNER/$REPO --jq '.default_branch' 2>/dev/null || echo "main")
              LATEST_SHA=$(gh api repos/$OWNER/$REPO/commits/$DEFAULT_BRANCH --jq '.sha' 2>/dev/null || echo "")
            fi

            if [ -z "$LATEST_SHA" ]; then
              echo " -> [SKIP] Could not resolve any commit SHA for $REPO. Is the repository completely empty?"
              continue
            fi

            # Read the last successfully built SHA from the upgraded nested object state
            LAST_SHA=$(jq -r --arg repo "$REPO" '.[$repo].sha // ""' public/state.json)

            if [ "$LATEST_SHA" = "$LAST_SHA" ]; then
              echo " -> [OK] No new commits detected ($LATEST_SHA). Already up to date."
              continue
            fi

            # Dynamic structural detection: check for debian/control at root level or one sub-level deep
            HAS_DEBIAN=$(gh api repos/$OWNER/$REPO/contents/debian/control --jq '.name' 2>/dev/null || echo "")
            DEBIAN_PATH="debian/control"
            
            if [ -z "$HAS_DEBIAN" ]; then
              # Look for it inside a nested subdirectory if root is empty
              NESTED_CHECK=$(gh api -X GET search/code -f q="filename:control path:debian repo:$OWNER/$REPO" --jq '.items[0].path' 2>/dev/null || echo "")
              if [ -n "$NESTED_CHECK" ]; then
                HAS_DEBIAN="control"
                DEBIAN_PATH="$NESTED_CHECK"
                echo " -> Found debian configuration nested at: $DEBIAN_PATH"
              fi
            fi

            if [ -z "$HAS_DEBIAN" ]; then
              echo " -> [SKIP] No 'debian/control' file found anywhere in $REPO. Skipping compilation."
              # Store state so we don't spam the API on unchanged repos
              jq --arg repo "$REPO" --arg sha "$LATEST_SHA" '.[$repo] = {sha: $sha, date: "N/A", packages: "No debian/control"}' public/state.json > tmp.json && mv tmp.json public/state.json
              continue
            fi

            echo " -> [BUILDING] New changes found! Proceeding to clone and compile..."
            
            rm -rf source-code
            git clone --depth 1 https://x-access-token:${GH_TOKEN}@github.com/$OWNER/$REPO.git source-code
            
            cd source-code
            # Navigate to where debian/control actually lives if it's nested
            DEBIAN_DIR=$(dirname "$DEBIAN_PATH")
            if [ "$DEBIAN_DIR" != "debian" ] && [ "$DEBIAN_DIR" != "." ]; then
              cd $(dirname "$DEBIAN_DIR")
            fi

            # dpkg-buildpackage requires debian/changelog to exist - generate one
            # on the fly (date-based version) if the repo doesn't ship it. This is
            # build-local only and never committed back to the source repo.
            if [ ! -f debian/changelog ]; then
              echo " -> No debian/changelog found, generating one for this build..."
              PKG_NAME=$(grep -m1 '^Source:' debian/control | sed 's/Source:[[:space:]]*//')
              BUILD_VERSION="1.0.0~git$(date +'%Y%m%d')-1"
              printf '%s (%s) stable; urgency=medium\n\n  * Auto-generated changelog for CI build (no debian/changelog in source repo).\n\n -- Cutie Org APT Scanner <actions@github.com>  %s\n' "$PKG_NAME" "$BUILD_VERSION" "$(date -R)" > debian/changelog
            fi

            sudo mk-build-deps --install \
              --tool='apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends --yes' \
              debian/control || echo "Dependency warnings encountered."

            dpkg-buildpackage -us -uc -b || echo "Compilation failed for $REPO."
            
            # Return to the central workspace root
            cd "${{ github.workspace }}"
            
            # Parse produced debian package names out before clean up strings
            BUILT_PACKAGES=$(find . -maxdepth 1 -name "*.deb" -exec basename {} \; | sed 's/_.*//' | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
            
            if [ -z "$BUILT_PACKAGES" ]; then
              echo " -> [ERROR] Compilation finished but no .deb binary packages were captured."
            else
              echo " -> [SUCCESS] Packages produced: $BUILT_PACKAGES"
              mv *.deb new-output/ 2>/dev/null || true
              mv *.changes new-output/ 2>/dev/null || true
              
              # Record timestamps along with output binaries mapping
              CURRENT_DATE=$(date +'%Y-%m-%d %H:%M:%S UTC')
              jq --arg repo "$REPO" --arg sha "$LATEST_SHA" --arg date "$CURRENT_DATE" --arg pkgs "$BUILT_PACKAGES" \
                '.[$repo] = {sha: $sha, date: $date, packages: $pkgs}' public/state.json > tmp.json && mv tmp.json public/state.json
            fi
            rm -rf source-code
          done

      - name: Import GPG key
        env:
          GPG_PRIVATE_KEY: ${{ secrets.GPG_PRIVATE_KEY }}
        run: |
          if [ -n "$GPG_PRIVATE_KEY" ]; then
            echo "$GPG_PRIVATE_KEY" | gpg --import --batch
            echo "allow-preset-passphrase" > ~/.gnupg/gpg-agent.conf
            echo "pinentry-mode loopback" >> ~/.gnupg/gpg.conf
            echo "no-tty" >> ~/.gnupg/gpg.conf
            gpg-connect-agent reloadagent /bye
          fi

      - name: Regenerate APT Repository Structure
        env:
          GNUPGHOME: /home/runner/.gnupg
          GPG_KEY_ID: ${{ secrets.GPG_KEY_ID }}
          GPG_PASSPHRASE: ${{ secrets.GPG_PASSPHRASE }}
          USER: ${{ github.repository_owner }}
          REPO: ${{ github.event.repository.name }}
        run: |
          mkdir -p public/pool/main
          mkdir -p public/dists/stable/main/binary-arm64

          # Integrate any freshly generated packages into our primary pool
          if [ "$(ls -A new-output/*.deb 2>/dev/null)" ]; then
            cp new-output/*.deb public/pool/main/
          fi

          # Export public GPG verification key
          gpg --armor --export $GPG_KEY_ID > public/repo.gpg

          cd public
          
          # Rebuild entire package registry index
          dpkg-scanpackages --arch arm64 pool/main /dev/null > dists/stable/main/binary-arm64/Packages
          gzip -k -f dists/stable/main/binary-arm64/Packages

          cd dists/stable
          cat << EOF > Release
          Origin: https://$USER.github.io/$REPO
          Label: Organization APT Repository
          Suite: stable
          Codename: stable
          Version: 1.0
          Architectures: arm64
          Components: main
          Description: Centralized Debian packages for the organization
          EOF

          apt-ftparchive release . >> Release

          # Re-sign repository definitions
          echo "$GPG_PASSPHRASE" | gpg --batch --yes --pinentry-mode loopback --passphrase-fd 0 --default-key $GPG_KEY_ID --clearsign -o InRelease Release
          echo "$GPG_PASSPHRASE" | gpg --batch --yes --pinentry-mode loopback --passphrase-fd 0 --default-key $GPG_KEY_ID -abs -o Release.gpg Release

      - name: Generate Index Interface Page
        env:
          USER: ${{ github.repository_owner }}
          REPO: ${{ github.event.repository.name }}
        run: |
          REPO_URL="https://$USER.github.io/$REPO"
          
          # Use jq to convert the tracking state directly into dynamic HTML table rows
          TABLE_ROWS=$(jq -r '
            to_entries[] | 
            select(.value.packages != "No debian/control") | 
            "<tr><td><strong>\(.key)</strong></td><td>\(.value.packages)</td><td>\(.value.date)</td><td><code>\(.value.sha | .[0:7])</code></td></tr>"
          ' public/state.json || echo "")

          cat << EOF > public/index.html
          <!DOCTYPE html>
          <html>
          <head>
            <title>Organization APT Repository</title>
            <style>
              body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; max-width: 950px; margin: 40px auto; padding: 0 20px; color: #333; line-height: 1.5; }
              pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; font-family: monospace; border: 1px solid #e0e0e0; }
              h1, h2 { color: #111; border-bottom: 1px solid #eee; padding-bottom: 10px; margin-top: 30px; }
              table { width: 100%; border-collapse: collapse; margin-top: 20px; margin-bottom: 30px; }
              th, td { text-align: left; padding: 12px; border-bottom: 1px solid #ddd; }
              th { background-color: #f8f9fa; font-weight: bold; color: #555; }
              tr:hover { background-color: #fafafa; }
              code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; font-family: monospace; font-size: 0.9em; border: 1px solid #e0e0e0; }
              .status-table { border: 1px solid #e0e0e0; border-radius: 6px; }
            </style>
          </head>
          <body>
            <h1>Organization APT Repository</h1>
            
            <h2>Available Packages & Build Status</h2>
            <table class="status-table">
              <thead>
                <tr>
                  <th>Source Repository</th>
                  <th>Packages Built</th>
                  <th>Last Build Date</th>
                  <th>Commit SHA</th>
                </tr>
              </thead>
              <tbody>
                ${TABLE_ROWS:-<tr><td colspan="4" style="text-align:center; color:#888;">No active package records tracked yet. Run scanner to populate.</td></tr>}
              </tbody>
            </table>

            <h2>1. Add GPG key</h2>
            <pre>curl ${REPO_URL}/repo.gpg | sudo tee /etc/apt/trusted.gpg.d/org-repo.gpg</pre>
            
            <h2>2. Add repository</h2>
            <pre>echo "deb ${REPO_URL} stable main" | sudo tee /etc/apt/sources.list.d/org-repo.list
          sudo apt-get update</pre>
          </body>
          </html>
          EOF

      - name: Commit Package Pool & Scanner State
        uses: peaceiris/actions-gh-pages@v4
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./public
          force_orphan: true
