#!/bin/bash

# Configuration
TEST_DIR="$HOME/Desktop/BackupVideo_Tests"
SOURCE_DIR="$TEST_DIR/Source"
DEST_RENDUS="$TEST_DIR/Destination_Rendus"
DEST_ARCHIVES="$TEST_DIR/Destination_Archives"
DEST_RUSHS="$TEST_DIR/Destination_Rushs"

# Clean previous tests
rm -rf "$TEST_DIR"
mkdir -p "$SOURCE_DIR" "$DEST_RENDUS" "$DEST_ARCHIVES" "$DEST_RUSHS"

# Create fake projects
PROJECTS=(
    "ClientA_Projet1"
    "ClientB_Projet2"
    "ClientC_Projet3_Special"
)

for PROJ in "${PROJECTS[@]}"; do
    PROJ_DIR="$SOURCE_DIR/$PROJ"
    mkdir -p "$PROJ_DIR"
    
    # Create Rushs
    mkdir -p "$PROJ_DIR/Rushs"
    for i in {1..5}; do
        # 1MB fake file
        dd if=/dev/urandom of="$PROJ_DIR/Rushs/cam1_clip$i.mp4" bs=1024 count=1024 2>/dev/null
    done
    
    # Create Rendus
    mkdir -p "$PROJ_DIR/Rendus"
    for i in {1..2}; do
        # 2MB fake file
        dd if=/dev/urandom of="$PROJ_DIR/Rendus/export_v$i.mp4" bs=1024 count=2048 2>/dev/null
    done
    
    # Create project file
    echo "Fichier de projet FCPX / Premiere" > "$PROJ_DIR/montage.prproj"
    
    # Create other folders
    mkdir -p "$PROJ_DIR/Audio"
    mkdir -p "$PROJ_DIR/Assets"
    echo "Musique" > "$PROJ_DIR/Audio/music.wav"
done

echo "✅ Environnement de test généré sur le bureau : $TEST_DIR"
echo "👉 Dossier source : $SOURCE_DIR"
echo "👉 Dossiers de destination : $DEST_RENDUS, $DEST_ARCHIVES, $DEST_RUSHS"
