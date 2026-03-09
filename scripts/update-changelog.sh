#!/bin/bash
set -e

# Get new version from package.json (npm version updates it before preversion runs)
NEW_VERSION=$(node -p "require('./package.json').version")

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
sed -i "s/koha-systemd_[0-9.]*_all.deb/koha-systemd_${NEW_VERSION}_all.deb/g" README.md

# Stage changes
git add debian/changelog README.md
