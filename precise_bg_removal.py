#!/usr/bin/env python3
"""
Precise background removal for trading hub animation frames.
Preserves white text only in "TRADING" and "OPEN" sign areas.
Uses pure PIL without numpy dependencies.
"""

import os
import sys
from PIL import Image, ImageDraw

def create_text_mask(image_size, text_regions):
    """Create a mask for text regions where white should be preserved."""
    mask = Image.new('L', image_size, 0)  # Black mask (0 = don't preserve)
    draw = ImageDraw.Draw(mask)

    # Draw white rectangles where text should be preserved
    for region in text_regions:
        draw.rectangle(region, fill=255)  # White = preserve white pixels

    return mask

def remove_background_preserve_text(image_path, text_regions, output_path):
    """Remove white background but preserve white in specified text regions."""

    # Load the image
    img = Image.open(image_path).convert('RGBA')
    width, height = img.size

    # Create text preservation mask
    text_mask = create_text_mask((width, height), text_regions)

    # Process pixel by pixel
    pixels = img.load()
    mask_pixels = text_mask.load()

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]

            # Check if pixel is white-ish (within tolerance)
            is_white = (r > 240 and g > 240 and b > 240)

            # Check if pixel is in text region
            in_text_region = mask_pixels[x, y] > 0

            # If white and NOT in text region, make transparent
            if is_white and not in_text_region:
                pixels[x, y] = (r, g, b, 0)  # Make transparent

    # Save the result
    img.save(output_path, 'PNG')

    return img

def process_all_frames(input_dir, output_dir, text_regions):
    """Process all PNG files in the input directory."""

    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)

    # Get all PNG files
    png_files = [f for f in os.listdir(input_dir) if f.lower().endswith('.png')]
    png_files.sort()

    print(f"Processing {len(png_files)} frames...")

    for i, filename in enumerate(png_files):
        input_path = os.path.join(input_dir, filename)
        output_path = os.path.join(output_dir, filename)

        print(f"Processing {filename} ({i+1}/{len(png_files)})...")

        try:
            remove_background_preserve_text(input_path, text_regions, output_path)
        except Exception as e:
            print(f"Error processing {filename}: {e}")

    print("Processing complete!")

def test_single_frame(input_dir, text_regions):
    """Test on a single frame first to check coordinates."""
    png_files = [f for f in os.listdir(input_dir) if f.lower().endswith('.png')]
    if not png_files:
        print("No PNG files found!")
        return

    test_file = png_files[0]
    input_path = os.path.join(input_dir, test_file)
    output_path = f"test_result_{test_file}"

    print(f"Testing with {test_file}...")

    # Load image to check dimensions
    img = Image.open(input_path)
    print(f"Image dimensions: {img.size}")

    remove_background_preserve_text(input_path, text_regions, output_path)
    print(f"Test result saved as: {output_path}")

def main():
    # Define text regions (left, top, right, bottom) where white should be preserved
    # These coordinates may need adjustment based on actual frame content
    text_regions = [
        # "TRADING" text area (approximate coordinates - may need adjustment)
        (680, 145, 930, 195),

        # "OPEN" text area (approximate coordinates - may need adjustment)
        (1070, 230, 1170, 260),
    ]

    # Directories
    input_dir = "frames_orig"
    output_dir = "frames_final"

    # Check if input directory exists
    if not os.path.exists(input_dir):
        print(f"Error: Input directory '{input_dir}' not found!")
        print("Available directories:")
        for item in os.listdir('.'):
            if os.path.isdir(item):
                print(f"  - {item}")
        return 1

    # First test on a single frame
    print("=== Testing on single frame ===")
    test_single_frame(input_dir, text_regions)

    # Ask user if they want to proceed
    response = input("\nDo you want to process all frames? (y/n): ")
    if response.lower() == 'y':
        print("\n=== Processing all frames ===")
        process_all_frames(input_dir, output_dir, text_regions)
    else:
        print("Processing cancelled. Adjust coordinates in the script if needed.")

    return 0

if __name__ == "__main__":
    sys.exit(main())
