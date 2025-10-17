#!/bin/bash
# Check if title is provided
if [ -z "$1" ]; then
  echo "Usage: $0 \"TITLE\""
  exit 1
fi

TITLE="$1"
DATE=$(date +"%Y-%m-%d %H:%M:%S %z")
FILENAME="_posts/$(date +%Y-%m-%d)-${TITLE// /-}.md"

cat > "$FILENAME" <<EOF
---
title: $TITLE
date: $DATE
categories: [TOP_CATEGORY, SUB_CATEGORY]
tags: [tag]     # TAG names should always be lowercase
---
EOF

echo "File created: $FILENAME"