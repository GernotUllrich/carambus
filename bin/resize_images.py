#!/usr/bin/env python3
"""
Image Resizer Script
Verkleinert PNG-Bilder um einen bestimmten Faktor und speichert sie in einem Ausgabeverzeichnis.
"""

import argparse
import os
from pathlib import Path
from PIL import Image


def resize_images(input_files, output_dir, scale_factor):
    """
    Verkleinert Bilder um den angegebenen Faktor.
    
    Args:
        input_files: Liste von Pfaden zu den Input-Bildern
        output_dir: Pfad zum Ausgabeverzeichnis
        scale_factor: Faktor um den die Bilder verkleinert werden (z.B. 0.5 für halbe Größe)
    """
    # Ausgabeverzeichnis erstellen, falls es nicht existiert
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    processed = 0
    errors = 0
    
    for input_file in input_files:
        try:
            input_path = Path(input_file)
            
            # Bild öffnen
            with Image.open(input_path) as img:
                # Neue Dimensionen berechnen
                new_width = int(img.width * scale_factor)
                new_height = int(img.height * scale_factor)
                
                # Bild verkleinern (LANCZOS für beste Qualität)
                resized_img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
                
                # Ausgabepfad erstellen
                output_file = output_path / input_path.name
                
                # Bild speichern
                resized_img.save(output_file, 'PNG', optimize=True)
                
                print(f"✓ {input_path.name}: {img.width}x{img.height} → {new_width}x{new_height}")
                processed += 1
                
        except Exception as e:
            print(f"✗ Fehler bei {input_file}: {e}")
            errors += 1
    
    print(f"\nFertig: {processed} Bilder verarbeitet, {errors} Fehler")


def main():
    parser = argparse.ArgumentParser(
        description='Verkleinert PNG-Bilder um einen bestimmten Faktor',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Beispiele:
  %(prog)s --input *.png --output resized --factor 0.5
  %(prog)s -i image1.png image2.png -o output_folder -f 0.25
  %(prog)s --input diagrams/*.png --output small_diagrams --factor 0.3
        """
    )
    
    parser.add_argument(
        '-i', '--input',
        nargs='+',
        required=True,
        help='Liste der Input-Bilder (z.B. *.png oder einzelne Dateien)'
    )
    
    parser.add_argument(
        '-o', '--output',
        required=True,
        help='Ausgabeverzeichnis für die verkleinerten Bilder'
    )
    
    parser.add_argument(
        '-f', '--factor',
        type=float,
        required=True,
        help='Verkleinerungsfaktor (z.B. 0.5 für halbe Größe, 0.25 für Viertel)'
    )
    
    args = parser.parse_args()
    
    # Validierung
    if args.factor <= 0 or args.factor > 1:
        parser.error('Der Faktor muss zwischen 0 und 1 liegen (z.B. 0.5 für halbe Größe)')
    
    # Prüfe ob Input-Dateien existieren
    valid_files = []
    for file_pattern in args.input:
        file_path = Path(file_pattern)
        if file_path.exists() and file_path.is_file():
            valid_files.append(file_pattern)
        else:
            print(f"Warnung: {file_pattern} nicht gefunden oder keine Datei")
    
    if not valid_files:
        parser.error('Keine gültigen Input-Dateien gefunden')
    
    print(f"Verkleinere {len(valid_files)} Bild(er) um Faktor {args.factor}")
    print(f"Ausgabe: {args.output}\n")
    
    resize_images(valid_files, args.output, args.factor)


if __name__ == '__main__':
    main()
