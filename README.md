# OrbPals 🐾

OrbPals is a physics-driven, interactive desktop pet application inspired by classic desktop pets like *Oddballz*. Your OrbPals bounce, squish, wander around your desktop windows, eat snacks, play with toys, dig up rare materials, and react dynamically to your interactions!

---

## 🚀 How to Run

### Option 1: Download Release Binaries (Recommended)
Download pre-built standalone executables directly from the official releases page:
👉 **[OrbPals Releases](https://github.com/austeregrim/OrbPals/releases/tag/Release)**

Simply extract the downloaded file and run the `OrbPals` executable!

### Option 2: Run / Build from Source
1. Download and install [Godot Engine 4](https://godotengine.org/download).
2. Clone or download this repository.
3. Open Godot, click **Import**, and select the `project.godot` file in the project folder.
4. Press `F5` (or click **Play**) to run the project immediately.
5. To export a standalone binary: go to **Project > Export...**, select your OS platform, and click **Export Project**.

---

## 🕹️ How to Play & Interact

### 🚰 Dispenser Drawer & Pets
* **Bringing out an OrbPal**: Open the **Dispenser Drawer** (`🚰` tab on the right side of your screen), choose a pet from the dropdown roster (e.g. *Grubby*, *Slinky*, *Glub*, *Gonzo*), and click **Summon**.
* **Recalling & Managing**: Use **Recall** to return the selected pet back into the dispenser, or **Recall All** to retrieve every active pet.
* **Cleaning Up**: Click **Mop** to clean up any messes or accidents left on screen.

### 🍎 Feeding & ⚽ Playing
* **Feeding**: Click **Food** or **Cookie** in the Dispenser Drawer to drop tasty snacks onto your desktop. Nearby OrbPals will spot the treat, hop over, and eat it when hungry.
* **Playing with the Ball**: Click **Ball** in the Dispenser Drawer to spawn a bouncy toy ball!
  * OrbPals will chase, nudge, and bounce the ball around.
  * You can click and drag the ball to throw it for your OrbPal to fetch.
  * *Tip*: Don't hit your OrbPal too hard repeatedly with the ball—they might get annoyed!

### 🖐️ Direct Pet Interactions
* **Petting & Poke**: Click on an OrbPal to pet or squish them.
* **Pick Up & Toss**: Left-click and hold on an OrbPal to drag them across your desktop. Release while moving to toss them in the air!
* **Walk Command**: Click and hold on an open desktop area for a short moment (around 0.35s) to signal your OrbPals to walk towards that location.
* **Digging**: OrbPals naturally like to dig holes on your screen. When they finish digging, they unearth raw materials and gene fragments!

---

## 🧬 Materials & Genetic Builder

### 📦 Inventory & Material Deconstruction
When your OrbPal digs up items (like *Ancient Fossils*, *Starlight Crystals*, *Bio Slime*, or *Glowing Amber*), they are stored in your **Inventory** (`📦` tab).
* Open the **Inventory** panel to inspect your collected raw materials and current DNA fragment reserves.
* Select a raw material and click **Deconstruct** to break it down into genetic building blocks (Adenine, Thymine, Cytosine, Guanine, Sugar, Phosphate, Methyl, and Nucleotide Polymers).

### 🥚 Genetic Builder (Custom Pets)
Unleash your inner scientist in the **Genetic Builder** (`🥚` tab)!
1. Combine your harvested DNA fragments to build a unique genetic strand.
2. Enter a custom name for your new species.
3. Click **Hatch Pet** to create a custom OrbPal!
4. Your custom creature will hatch, emerge from the dispenser, and automatically be saved into your permanent pet roster.

---

## ⚙️ Settings Panel Options

Open the **Settings Panel** (`⚙️` tab) to customize your desktop experience:

* **Play Pen Mode**: Toggles a safe, contained window bounds for your OrbPals instead of full desktop passthrough mode.
* **Screen Selector**: Choose which monitor your OrbPals live on when using multi-monitor setups (or select *All Screens*).
* **Target FPS**: Adjust application frame rate limits (30 FPS, 60 FPS, 90 FPS, 120 FPS, or Unlimited) to optimize performance and battery life.
* **Window Obstacles**: Enables active window boundary detection, allowing OrbPals to walk on top of open application windows and window frames on your desktop.
* **Old Age / Pet Mortality**: Toggle whether pets experience natural aging over time.
* **Theme Color**: Customize the UI panel theme accent colors to match your style.

