#!/usr/bin/env python3
"""
Image Resizer with DPI adjustment
Verkleinert PNG-Bilder durch Erhöhung der Pixeldichte (DPI) oder durch Pixel-Reduktion
"""

import argparse
import os
from pathlib import Path
from PIL import Image


def resize_with_dpi(input_files, output_dir, scale_factor, mode='dpi'):
    """
    Verkleinert Bilder durch DPI-Anpassung oder Pixel-Reduktion.
    
    Args:
        input_files: Liste von Pfaden zu den Input-Bildern
        output_dir: Pfad zum Ausgabeverzeichnis
        scale_factor: Faktor um den die Bilder verkleinert werden
        mode: 'dpi' = nur DPI erhöhen, 'pixel' = Pixel reduzieren + DPI erhöhen
    """
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    processed = 0
    errors = 0
    
    for input_file in input_files:
        try:
            input_path = Path(input_file)
            
            with Image.open(input_path) as img:
                # Aktuelle DPI auslesen (default: 72 DPI wenn nicht gesetzt)
                current_dpi = img.info.get('dpi', (72, 72))
                if isinstance(current_dpi, (int, float)):
                    current_dpi = (current_dpi, current_dpi)
                
                if mode == 'dpi':
                    # Modus 1: Nur DPI erhöhen, Pixel-Dimensionen bleiben gleich
                    # Physikalische Größe wird kleiner, aber Qualität bleibt gleich
                    new_dpi = (
                        int(current_dpi[0] / scale_factor),
                        int(current_dpi[1] / scale_factor)
                    )
                    
                    # Physikalische Größe berechnen
                    old_size_inch = (img.width / current_dpi[0], img.height / current_dpi[1])
                    new_size_inch = (img.width / new_dpi[0], img.height / new_dpi[1])
                    
                    # Bild mit neuer DPI speichern
                    output_file = output_path / input_path.name
                    img.save(output_file, 'PNG', dpi=new_dpi, optimize=True)
                    
                    print(f"✓ {input_path.name}:")
                    print(f"  Pixel: {img.width}x{img.height} (unverändert)")
                    print(f"  DPI: {current_dpi[0]} → {new_dpi[0]}")
                    print(f"  Physikalisch: {old_size_inch[0]:.2f}\"x{old_size_inch[1]:.2f}\" → {new_size_inch[0]:.2f}\"x{new_size_inch[1]:.2f}\"")
                    
                elif mode == 'pixel':
                    # Modus 2: Pixel reduzieren UND DPI erhöhen
                    # Doppelte Verkleinerung: weniger Pixel, höhere Dichte
                    new_width = int(img.width * scale_factor)
                    new_height = int(img.height * scale_factor)
                    new_dpi = (
                        int(current_dpi[0] / scale_factor),
                        int(current_dpi[1] / scale_factor)
                    )
                    
                    # Bild verkleinern
                    resized_img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
                    
                    # Mit neuer DPI speichern
                    output_file = output_path / input_path.name
                    resized_img.save(output_file, 'PNG', dpi=new_dpi, optimize=True)
                    
                    old_size_inch = (img.width / current_dpi[0], img.height / current_dpi[1])
                    new_size_inch = (new_width / new_dpi[0], new_height / new_dpi[1])
                    
                    print(f"✓ {input_path.name}:")
                    print(f"  Pixel: {img.width}x{img.height} → {new_width}x{new_height}")
                    print(f"  DPI: {current_dpi[0]} → {new_dpi[0]}")
                    print(f"  Physikalisch: {old_size_inch[0]:.2f}\"x{old_size_inch[1]:.2f}\" → {new_size_inch[0]:.2f}\"x{new_size_inch[1]:.2f}\"")
                
                processed += 1
                
        except Exception as e:
            print(f"✗ Fehler bei {input_file}: {e}")
            errors += 1
    
    print(f"\nFertig: {processed} Bilder verarbeitet, {errors} Fehler")


def main():
    parser = argparse.ArgumentParser(
        description='Verkleinert PNG-Bilder durch DPI-Anpassung',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Modi:
  dpi    - Nur DPI erhöhen, Pixel bleiben gleich (Standard)
           → Datei bleibt gleich groß, physikalische Größe wird kleiner
           → Keine Qualitätsverluste
  
  pixel  - Pixel reduzieren UND DPI erhöhen
           → Kleinere Datei, kleinere physikalische Größe
           → Proportionale Qualität

Beispiele:
  # Nur DPI erhöhen (verlustfrei)
  %(prog)s -i *.png -o output -f 0.5 -m dpi
  
  # Pixel + DPI anpassen
  %(prog)s -i diagrams/*.png -o small -f 0.5 -m pixel
        """
    )
    
    parser.add_argument(
        '-i', '--input',
        nargs='+',
        required=True,
        help='Liste der Input-Bilder'
    )
    
    parser.add_argument(
        '-o', '--output',
        required=True,
        help='Ausgabeverzeichnis'
    )
    
    parser.add_argument(
        '-f', '--factor',
        type=float,
        required=True,
        help='Verkleinerungsfaktor (z.B. 0.5 für halbe Größe)'
    )
    
    parser.add_argument(
        '-m', '--mode',
        choices=['dpi', 'pixel'],
        default='dpi',
        help='Modus: "dpi" nur DPI erhöhen (Standard), "pixel" Pixel+DPI'
    )
    
    args = parser.parse_args()
    
    if args.factor <= 0 or args.factor > 1:
        parser.error('Der Faktor muss zwischen 0 und 1 liegen')
    
    valid_files = [f for f in args.input if Path(f).exists() and Path(f).is_file()]
    
    if not valid_files:
        parser.error('Keine gültigen Input-Dateien gefunden')
    
    mode_desc = "DPI-Erhöhung (verlustfrei)" if args.mode == 'dpi' else "Pixel-Reduktion + DPI-Erhöhung"
    print(f"Verkleinere {len(valid_files)} Bild(er) um Faktor {args.factor}")
    print(f"Modus: {mode_desc}")
    print(f"Ausgabe: {args.output}\n")
    
    resize_with_dpi(valid_files, args.output, args.factor, args.mode)


if __name__ == '__main__':
    main()
