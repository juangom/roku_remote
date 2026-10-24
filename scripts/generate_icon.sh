#!/usr/bin/env bash
#
# Generate the RokuMote launcher artwork with ImageMagick.
# Outputs to assets/icon/:
#   icon.png             1024x1024 legacy icon (rounded purple tile + remote)
#   icon_foreground.png  1024x1024 adaptive-icon foreground (safe zone)
#   icon_background.png  1024x1024 adaptive-icon background (solid purple)
#   icon_playstore.png   512x512 icon for the Play Console listing
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p assets/icon

PURPLE='#662D91'
OUT=assets/icon

# --- Legacy icon: purple rounded tile + white remote -------------------------
convert -size 1024x1024 xc:none \
  -fill "$PURPLE" -draw 'roundrectangle 0,0 1023,1023 180,180' \
  -fill white     -draw 'roundrectangle 322,152 702,872 130,130' \
  -fill "$PURPLE" -draw 'circle 512,232 512,258' \
  -fill "$PURPLE" -draw 'circle 512,430 512,550' \
  -fill white     -draw 'circle 512,430 512,516' \
  -fill "$PURPLE" -draw 'circle 512,430 512,462' \
  -draw 'circle 442,650 442,676' \
  -draw 'circle 582,650 582,676' \
  "$OUT/icon.png"

# --- Adaptive foreground: remote only ---------------------------------------
# flutter_launcher_icons insets the foreground by 16%, so the remote is drawn
# larger here; after the inset it occupies ~53% of the masked icon.
convert -size 1024x1024 xc:none \
  -fill white     -draw 'roundrectangle 307,112 717,912 140,140' \
  -fill "$PURPLE" -draw 'circle 512,210 512,240' \
  -fill "$PURPLE" -draw 'circle 512,440 512,580' \
  -fill white     -draw 'circle 512,440 512,540' \
  -fill "$PURPLE" -draw 'circle 512,440 512,476' \
  -draw 'circle 432,690 432,720' \
  -draw 'circle 592,690 592,720' \
  "$OUT/icon_foreground.png"

# --- Adaptive background: solid purple ---------------------------------------
convert -size 1024x1024 "xc:$PURPLE" "$OUT/icon_background.png"

# --- Play Store listing icon -------------------------------------------------
convert "$OUT/icon.png" -resize 512x512 "$OUT/icon_playstore.png"

echo "Generated:"
identify "$OUT"/icon.png "$OUT"/icon_foreground.png "$OUT"/icon_background.png "$OUT"/icon_playstore.png
