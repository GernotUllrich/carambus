#!/usr/bin/env python3
"""
Image Cleaner
Bereinigt gescannte Bilder: macht Hintergrund weiß und Linien schwarz
"""

import argparse
from pathlib import Path
from PIL import Image, ImageEnhance, ImageOps
import numpy as np


def clean_image(input_file, output_dir, threshold=200, contrast=1.5, brightness=1.2):
    """
    Bereinigt ein Bild: weißer Hintergrund, schwarze Linien.
    
    Args:
        input_file: Pfad zum Input-Bild
        output_dir: Pfad zum Ausgabeverzeichnis
        threshold: Schwellwert für Hintergrund-Aufhellung (0-255)
        contrast: Kontrast-Verstärkung (>1 = mehr Kontrast)
        brightness: Helligkeit (>1 = heller)
    """
    input_path = Path(input_file)
    
    with Image.open(input_path) as img:
        # In Graustufen konvertieren falls Farbbild
        if img.mode != 'L':
            img = img.convert('L')
        
        # Schritt 1: Kontrast erhöhen
        enhancer = ImageEnhance.Contrast(img)
        img = enhancer.enhance(contrast)
        
        # Schritt 2: Helligkeit erhöhen
        enhancer = ImageEnhance.Brightness(img)
        img = enhancer.enhance(brightness)
        
        # Schritt 3: Schwellwert-basierte Bereinigung
        # Alle Pixel über dem Schwellwert werden weiß, darunter schwarz
        img_array = np.array(img)
        
        # Hintergrund (helle Pixel) -> weiß
        # Linien (dunkle Pixel) -> schwarz
        cleaned = np.where(img_array > threshold, 255, 0).astype(np.uint8)
        
        # Zurück zu PIL Image
        cleaned_img = Image.fromarray(cleaned, mode='L')
        
        # Optional: Schärfe erhöhen für sauberere Linien
        enhancer = ImageEnhance.Sharpness(cleaned_img)
        cleaned_img = enhancer.enhance(1.5)
        
        # Speichern
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        output_file = output_path / input_path.name
        
        cleaned_img.save(output_file, 'PNG', optimize=True)
        
        return output_file


def clean_advanced(input_file, output_dir, mode='auto'):
    """
    Erweiterte Bereinigung mit verschiedenen Modi.
    
    Args:
        mode: 'auto', 'aggressive', 'gentle'
    """
    input_path = Path(input_file)
    
    with Image.open(input_path) as img:
        # DPI-Informationen aus Original-Bild auslesen
        original_dpi = img.info.get('dpi', None)
        
        # In Graustufen
        if img.mode != 'L':
            img = img.convert('L')
        
        img_array = np.array(img)
        
        if mode == 'auto':
            # Automatischer Schwellwert basierend auf Histogramm
            # Finde den häufigsten Grauton (= Hintergrund)
            hist, bins = np.histogram(img_array.flatten(), bins=256, range=(0, 255))
            
            # Ignoriere sehr dunkle und sehr helle Werte
            hist[0:20] = 0  # Ignoriere fast-schwarz
            hist[240:256] = 0  # Ignoriere fast-weiß
            
            # Finde Peak (Hintergrundfarbe)
            background_gray = np.argmax(hist)
            
            # Schwellwert etwas unter dem Hintergrund
            threshold = background_gray - 30
            
            print(f"  Auto-Schwellwert: {threshold} (Hintergrund bei ~{background_gray})")
            
            # Kontrast und Helligkeit anpassen
            enhancer = ImageEnhance.Contrast(img)
            img = enhancer.enhance(1.8)
            
            enhancer = ImageEnhance.Brightness(img)
            img = enhancer.enhance(1.1)
            
            img_array = np.array(img)
            cleaned = np.where(img_array > threshold, 255, 0).astype(np.uint8)
            
        elif mode == 'aggressive':
            # Starke Bereinigung - sehr sauberes Ergebnis, könnte Details verlieren
            enhancer = ImageEnhance.Contrast(img)
            img = enhancer.enhance(2.0)
            
            enhancer = ImageEnhance.Brightness(img)
            img = enhancer.enhance(1.3)
            
            img_array = np.array(img)
            cleaned = np.where(img_array > 180, 255, 0).astype(np.uint8)
            
        else:  # gentle
            # Sanfte Bereinigung - behält mehr Details
            enhancer = ImageEnhance.Contrast(img)
            img = enhancer.enhance(1.3)
            
            enhancer = ImageEnhance.Brightness(img)
            img = enhancer.enhance(1.15)
            
            img_array = np.array(img)
            cleaned = np.where(img_array > 210, 255, 0).astype(np.uint8)
        
        # Zu PIL Image
        cleaned_img = Image.fromarray(cleaned, mode='L')
        
        # Schärfe
        enhancer = ImageEnhance.Sharpness(cleaned_img)
        cleaned_img = enhancer.enhance(1.5)
        
        # Speichern
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        output_file = output_path / input_path.name
        
        # DPI-Informationen beibehalten beim Speichern
        if original_dpi:
            cleaned_img.save(output_file, 'PNG', dpi=original_dpi, optimize=True)
            print(f"  DPI beibehalten: {original_dpi}")
        else:
            cleaned_img.save(output_file, 'PNG', optimize=True)
        
        return output_file


def main():
    parser = argparse.ArgumentParser(
        description='Bereinigt gescannte Bilder: weißer Hintergrund, schwarze Linien',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Modi:
  auto       - Automatische Erkennung (empfohlen)
  aggressive - Starke Bereinigung, sehr sauber
  gentle     - Sanfte Bereinigung, mehr Details

Beispiele:
  # Automatische Bereinigung (empfohlen)
  %(prog)s -i "Stoot 66.png" -o cleaned
  
  # Alle Bilder in einem Ordner
  %(prog)s -i tmp/input/*.png -o tmp/output -m auto
  
  # Starke Bereinigung
  %(prog)s -i *.png -o cleaned -m aggressive
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
        '-m', '--mode',
        choices=['auto', 'aggressive', 'gentle'],
        default='auto',
        help='Bereinigungsmodus (Standard: auto)'
    )
    
    args = parser.parse_args()
    
    valid_files = [f for f in args.input if Path(f).exists() and Path(f).is_file()]
    
    if not valid_files:
        parser.error('Keine gültigen Input-Dateien gefunden')
    
    print(f"Bereinige {len(valid_files)} Bild(er)")
    print(f"Modus: {args.mode}")
    print(f"Ausgabe: {args.output}\n")
    
    processed = 0
    errors = 0
    
    for input_file in valid_files:
        try:
            print(f"✓ {Path(input_file).name}")
            clean_advanced(input_file, args.output, args.mode)
            processed += 1
        except Exception as e:
            print(f"✗ Fehler bei {input_file}: {e}")
            errors += 1
    
    print(f"\nFertig: {processed} Bilder verarbeitet, {errors} Fehler")


if __name__ == '__main__':
    main()
