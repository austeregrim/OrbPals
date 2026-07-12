# **Project Blueprint: Modern Desktop Pet (*Oddballz* Spiritual Successor)**

## **1\. Core Technical Requirements**

To make this game function seamlessly across modern operating systems inside the Godot Engine, the architecture must support three core system-level operations:

* **Per-Pixel Window Transparency:** The Godot project must be configured as a borderless, always-on-top window where the background color is entirely transparent, leaving only the pet visible.  
* **Dynamic Mouse Click-Through Masking:** A low-level C\# or extension layer must actively toggle the window's mouse interaction flag. When the mouse is over empty space, clicks must pass through to background apps. When hovering directly over the pet's collision shape, clicks must register within Godot.  
* **OS Display Interrogation:** The application must query Godot's DisplayServer API to fetch real-time monitor resolutions and window placement data, establishing hard bounding boxes for the pet's pathfinding and movement scripts.

## **2\. Character Needs & States Matrix**

The pet's AI utilizes a Finite State Machine (FSM) governed by 7 internal drives that constantly decay over time.

| Need/Drive | Trigger Threshold | Vector Body Deformation | Recovery Mechanism |
| :---- | :---- | :---- | :---- |
| **Hunger** | Drops below 30% | Shapes lose elasticity, deflate, and droop downward. | Spawn food item via hotkey; pet pathfinds and consumes it. |
| **Boredom** | Drops below 40% | Erratic stretching, vibrating, rapid border bouncing. | Spawn a interactive toy or allow pet to chase the mouse cursor. |
| **Energy** | Drops below 15% | Collapses into a static, uniform ball with particle effects. | Must remain undisturbed in sleep state until drive hits 100%. |
| **Affection** | Drops below 50% | Elongates upward, actively tracking and seeking the cursor. | Hover mouse over body (petting) or trigger click-and-drag. |
| **Curiosity** | Drops below 30% | Narrows into a vertical periscope shape; targets window edges. | Reach a window/cursor boundary and dwell for 3 seconds. |
| **Agitation** | Rapid clicks/shake | Smooth vector lines warp into jagged, sharp edge shapes. | Cease all interaction entirely for 10–15 seconds to cool down. |
| **Wellness** | Drops below 40% | Spring physics dampen; body sags unevenly to one side. | Use the specialized "Cure" tool directly on the pet's layer. |

## **3\. Sequential Development Plan**

Development is broken into 5 sequential, isolated testing stages to ensure stability before layering complex mechanics.

Stage 1 (Environment) ──\> Stage 2 (Vector Body) ──\> Stage 3 (Locomotion) ──\> Stage 4 (FSM Testing) ──\> Stage 5 (Interaction)

### **Stage 1: Window & Environment Baseline**

* **Objective:** Establish a completely invisible, non-intrusive workspace environment.  
* **Execution:** Configure Godot project properties for borderless transparent display. Implement the C\# click-through toggle logic loop.  
* **Success Metric:** You can click through the running transparent Godot app to select folders on your actual OS desktop without closing the window.

### **Stage 2: The Vector Body Prototype**

* **Objective:** Build the character using procedural rendering instead of traditional art assets.  
* **Execution:** Script a central node using custom \_draw() loops to render interconnected circles. Apply spring physics calculations to handle squish, stretch, and deceleration forces.  
* **Success Metric:** Clicking and throwing the pet causes the body shapes to realistically deform on impact and snap back into a sphere when resting.

### **Stage 3: Locomotion & Screen Boundaries**

* **Objective:** Confine autonomous pet movement to the physical monitor dimensions.  
* **Execution:** Program a basic "Random Walk" routine. Integrate DisplayServer coordinates to create invisible boundary walls.  
* **Success Metric:** The pet wanders across the desktop indefinitely, turning or bouncing cleanly off the edges of your physical monitors.

### **Stage 4: Debug Sandbox & State Logic**

* **Objective:** Validate all behavioral AI states under controlled conditions.  
* **Execution:** Code the 7-state FSM framework. Build a temporary, secondary UI panel with manual sliders tied directly to each internal drive.  
* **Success Metric:** Adjusting a slider manually instantly triggers the corresponding vector deformation and movement behavior without relying on automated decay timers.

### **Stage 5: Interactivity & Spawning Systems**

* **Objective:** Close the game loop by allowing player actions to satisfy pet needs.  
* **Execution:** Build item instantiation systems to drop food or toys at cursor coordinates. Hook the pet's pathfinding directly to these item coordinates upon creation.  
* **Success Metric:** Dropping food near a starving pet overrides its random wander, pulls it toward the item, triggers the eating sequence, and automatically resets the hunger drive.

## **4\. Operational Expectations**

* **Performance Footprint:** Because this application runs constantly alongside other software, the execution loop must remain incredibly lightweight. Procedural vector drawing (\_draw) uses significantly less memory than scaling large 3D models or uncompressed sprite sheets.  
* **Scalability:** By keeping the behavioral drives isolated as custom Resource files (.tres), you can generate entirely new pet personalities later just by tweaking numeric values, without rewriting the core AI state scripts.