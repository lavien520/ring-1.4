#!/usr/bin/env python3
"""Generate a DMG background image for RingGlow installer."""

import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Pillow not installed. Installing...")
    os.system(f"{sys.executable} -m pip install Pillow -q")
    from PIL import Image, ImageDraw, ImageFont

WIDTH, HEIGHT = 660, 400
BG_COLOR = (30, 30, 46)  # Dark background matching the ring aesthetic
ACCENT_COLOR = (100, 220, 255)  # Cyan glow

img = Image.new("RGB", (WIDTH, HEIGHT), BG_COLOR)
draw = ImageDraw.Draw(img)

# Draw a subtle gradient overlay
for y in range(HEIGHT):
    alpha = int(20 * (y / HEIGHT))
    draw.line([(0, y), (WIDTH, y)], fill=(BG_COLOR[0] + alpha, BG_COLOR[1] + alpha, BG_COLOR[2] + alpha))

# Draw decorative ring arcs
import math
cx, cy = WIDTH // 2, HEIGHT // 2 - 20
radius = 80
for angle in range(0, 360, 3):
    rad = math.radians(angle)
    x1 = cx + int((radius + 5) * math.cos(rad))
    y1 = cy + int((radius + 5) * math.sin(rad))
    x2 = cx + int((radius - 5) * math.cos(rad))
    y2 = cy + int((radius - 5) * math.sin(rad))
    brightness = int(100 + 100 * math.sin(math.radians(angle * 3)))
    draw.line([(x1, y1), (x2, y2)], fill=(brightness, 220, 255), width=2)

# Draw arrow from app to Applications
arrow_y = HEIGHT // 2 + 30
arrow_start = WIDTH // 2 + 100
arrow_end = WIDTH // 2 + 200
draw.line([(arrow_start, arrow_y), (arrow_end, arrow_y)], fill=(180, 180, 180), width=3)
# Arrowhead
draw.polygon([
    (arrow_end, arrow_y),
    (arrow_end - 12, arrow_y - 8),
    (arrow_end - 12, arrow_y + 8),
], fill=(180, 180, 180))

# Add text
try:
    font_large = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 24)
    font_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 14)
except:
    font_large = ImageFont.load_default()
    font_small = ImageFont.load_default()

# Title
draw.text((WIDTH // 2, 30), "RingGlow", fill=ACCENT_COLOR, font=font_large, anchor="mt")
draw.text((WIDTH // 2, 60), "Claude Code Visual Indicator", fill=(160, 160, 170), font=font_small, anchor="mt")

# Labels
draw.text((WIDTH // 2 - 130, HEIGHT - 60), "RingGlow.app", fill=(200, 200, 210), font=font_small, anchor="mt")
draw.text((WIDTH // 2 + 150, HEIGHT - 60), "Applications", fill=(200, 200, 210), font=font_small, anchor="mt")

# Version
draw.text((WIDTH // 2, HEIGHT - 20), "v1.0  •  macOS 13.0+", fill=(100, 100, 110), font=font_small, anchor="mb")

output_dir = sys.argv[1] if len(sys.argv) > 1 else "build"
os.makedirs(output_dir, exist_ok=True)
output_path = os.path.join(output_dir, "dmg-background.png")
img.save(output_path, "PNG")
print(f"Background image saved: {output_path}")
