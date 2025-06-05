#!/usr/bin/env bash

# Function to check if running on Windows
is_windows() {
    [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == CYGWIN* ]]
}

# Function to convert Windows path to Unix path
win_to_unix_path() {
    if is_windows; then
        echo "/$1" | sed 's/\\/\//g' | sed 's/://'
    else
        echo "$1"
    fi
}

set -e

# Check if a file argument is provided
if [ $# -eq 0 ]; then
    echo "Error: No file specified. Usage: $0 <filename.asm>"
    exit 1
fi

FILE_TO_RUN="$1"
FILE_NAME=$(basename "$FILE_TO_RUN" .asm)

if [[ "$FILE_TO_RUN" != *.asm ]]; then
    echo "Error: File must have .asm extension"
    exit 1
fi

if [ ! -f "$FILE_TO_RUN" ]; then
    echo "Error: File '$FILE_TO_RUN' not found."
    exit 1
fi

# Check if the asm-compiler image exists
if ! docker image inspect asm-compiler:latest >/dev/null 2>&1; then
    echo "Building asm-compiler image..."
    docker build -t asm-compiler:latest .
else
    echo "asm-compiler image already exists. Skipping build."
fi

# Convert current directory path for Docker volume mounting
CURRENT_DIR=$(win_to_unix_path "$(pwd)")

# Compile the assembly code using ld (no gcc)
docker run --rm -v "${CURRENT_DIR}:/usr/src/app" asm-compiler:latest bash -c "
    set -e
    nasm -f elf32 $FILE_TO_RUN -o ${FILE_NAME}.o
    ld -m elf_i386 -nostdlib -e _start -o $FILE_NAME ${FILE_NAME}.o
"

echo "Compilation completed. Executable '$FILE_NAME' created."

# Execute the compiled program
echo "Running the program:"
docker run --rm -it -v "${CURRENT_DIR}:/usr/src/app" asm-compiler:latest ./$FILE_NAME
