# RingGlow

A macOS menu bar utility that displays a glowing ring indicator for Claude Code agent states.

## Features

- **Real-time State Monitoring**: Displays Claude Code agent states (idle, thinking, working, attention, error, sleeping, notification)
- **Visual Feedback**: Animated ring with glow effects, color changes, and rotation animations
- **Permission Alerts**: Shows allow/deny buttons when Claude Code requests tool permissions
- **Memory Monitor**: Displays current memory usage percentage in the ring center
- **Gravity Physics**: Ring follows physics when dragged and released
- **Particle Sphere Mode**: Alternative appearance with 3000 animated particles
- **Customizable**: Adjustable ring size, glow intensity, and appearance modes
- **Fullscreen Aware**: Automatically hides when fullscreen applications are active

## Installation

1. Download the latest release from [GitHub Releases](https://github.com/lavien520/ring-1.4/releases)
2. Move `RingGlow.app` to your Applications folder
3. Launch the app - it will appear as a glowing ring on your desktop

## Usage

- **Left-click and drag** to move the ring
- **Right-click** to access the context menu with options:
  - Settings
  - Rotate / Spin animations
  - Glow intensity adjustment
  - Memory usage display
  - Particle pulse effect
  - Appearance mode switching (Ring / Particle Sphere)
  - Quit

## Configuration

The ring automatically connects to Claude Code's hook system on port 23334. Configure Claude Code to send state updates to this port.

## Requirements

- macOS 13.0 or later
- Claude Code CLI installed

## License

MIT License

## Recommended For

- **Claude Code Users**: Get visual feedback on agent states without checking the terminal
- **Developers**: Monitor Claude Code's thinking/working states in real-time
- **Power Users**: Customize the ring appearance and behavior to match your workflow

## Why RingGlow?

- **Non-intrusive**: Sits on your desktop without blocking your work
- **Beautiful**: Smooth animations and glow effects
- **Informative**: Instantly see what Claude Code is doing
- **Customizable**: Adjust to your preferences
- **Fullscreen Friendly**: Automatically hides when you need full screen space
