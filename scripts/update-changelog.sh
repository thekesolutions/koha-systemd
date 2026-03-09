#!/bin/bash
set -e

# npm version lifecycle:
# 1. preversion runs (package.json still has OLD version)
# 2. npm bumps version in package.json
# 3. npm commits
# 4. postversion runs
# So we need to calculate the new version ourselves

CURRENT_VERSION=$(node -p "require('./package.json').version")

# Bump patch version
IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
NEW_VERSION="$major.$minor.$((patch + 1))"

# Update debian/changelog
TIMESTAMP=$(date -R)
cat > debian/changelog.new << EOF
koha-systemd ($NEW_VERSION) unstable; urgency=medium

  * Release $NEW_VERSION

 -- Tomas Cohen Arazi <tomascohen@theke.io>  $TIMESTAMP

EOF
cat debian/changelog >> debian/changelog.new
mv debian/changelog.new debian/changelog

# Update README
sed -i.bak "s/koha-systemd_[0-9.]*_all.deb/koha-systemd_${NEW_VERSION}_all.deb/g" README.md
rm -f README.md.bak

# Stage changes
git add debian/changelog README.md
