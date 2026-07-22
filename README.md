# OrbPals
A desktop pet, inspired by oddballz.

## How to Run from Source

1. Download and install [Godot Engine](https://godotengine.org/download) (This project was built with Godot 4).
2. Open Godot Engine and click **Import**.
3. Navigate to the directory containing this project's `project.godot` file and select it.
4. Once the project is open, press `F5` (or click the **Play** icon in the top right corner) to run the application.

## How to Build / Export a Release

To create a standalone executable for others to play without needing the Godot Engine:

1. Open the project in the Godot Editor.
2. Go to the top menu and select **Project > Export...**
3. Click **Add...** at the top of the Export menu and select your target platform (e.g., Windows Desktop, Linux/X11, macOS).
4. *(Note: If you haven't downloaded Export Templates yet, Godot will prompt you to download them. Click **Manage Export Templates** at the bottom of the dialog and install them).*
5. After adding a platform, click the **Export Project** button at the bottom.
6. Choose a destination folder and filename, then click **Save**.

This will generate the executable files that you can zip up and share with others!
