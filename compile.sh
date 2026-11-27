#!/usr/bin/env bash
# Build the capstone report PDF.
#
# Usage:
#   ./compile.sh          # build template.pdf
#   ./compile.sh clean    # remove build artefacts (and the PDF)

set -euo pipefail

MAIN="template"
BUILD_DIR="build"

cd "$(dirname "$0")"

if [[ "${1:-}" == "clean" ]]; then
  rm -rf "$BUILD_DIR" "$MAIN.pdf"
  echo "Cleaned."
  exit 0
fi

if command -v latexmk >/dev/null 2>&1; then
  latexmk -pdf -interaction=nonstopmode -halt-on-error \
          -outdir="$BUILD_DIR" "$MAIN.tex"
elif command -v pdflatex >/dev/null 2>&1; then
  mkdir -p "$BUILD_DIR"
  # Three passes: content, then table of contents / list of figures / tables,
  # then final cross-reference and page-number resolution.
  for pass in 1 2 3; do
    echo "== pdflatex pass $pass/3 =="
    pdflatex -interaction=nonstopmode -halt-on-error \
             -file-line-error -output-directory="$BUILD_DIR" "$MAIN.tex" \
      > "$BUILD_DIR/pass$pass.log" || {
        echo "pdflatex failed on pass $pass. Errors:" >&2
        grep -E "^.*:[0-9]+:|^! " "$BUILD_DIR/pass$pass.log" | head -30 >&2
        echo "Full log: $BUILD_DIR/$MAIN.log" >&2
        exit 1
      }
  done
else
  echo "Error: neither latexmk nor pdflatex found. Install TeX Live:" >&2
  echo "  sudo apt install texlive-latex-recommended texlive-latex-extra" >&2
  exit 1
fi

cp "$BUILD_DIR/$MAIN.pdf" "./$MAIN.pdf"

# Surface warnings worth a look without drowning in log noise.
if grep -q "LaTeX Warning: Reference\|LaTeX Warning: Citation" "$BUILD_DIR/$MAIN.log"; then
  echo
  echo "Warnings:"
  grep "LaTeX Warning: \(Reference\|Citation\)" "$BUILD_DIR/$MAIN.log" | sort -u
fi

echo
echo "Built: $MAIN.pdf ($(du -h "$MAIN.pdf" | cut -f1), $(pdfinfo "$MAIN.pdf" 2>/dev/null | awk '/^Pages/{print $2" pages"}'))"
