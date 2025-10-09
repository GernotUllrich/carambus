#!/bin/bash
# Quick JavaScript rebuild script
echo "🧹 Clearing Rails cache..."
rm -rf tmp/cache/*

echo "🔨 Building JavaScript..."
yarn build

echo "✅ Done! Refresh your browser."
