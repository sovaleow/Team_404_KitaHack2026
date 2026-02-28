# GrocerKu (KitaHack 2026)

GrocerKu is a smart inventory management application designed to reduce food waste by empowering users to track, manage, and discuss their groceries efficiently. Built for the KitaHack 2026 hackathon, it combines on-device machine learning with a community-driven approach to sustainability.

---

## 🛠 Technical Implementation Overview

### Core Framework
*   **Flutter & Dart**: Cross-platform development framework used to build a high-performance, responsive UI for Android.

### Google Tools & Firebase Integration
*   **Google ML Kit**: 
    *   **Text Recognition (OCR)**: Automatically detects expiry dates on food packaging during scanning.
    *   **Image Labeling**: Identifies food items and suggests categories (e.g., Vegetables, Fruits) using on-device vision models.
*   **Firebase Authentication**: Secure user login via Email/Password and **Google Sign-In**.
*   **Cloud Firestore**: Real-time NoSQL database used to sync user inventory, waste statistics, and community forum posts.

### Local Services & Analytics
*   **Flutter Local Notifications**: Scheduled alerts triggered locally to notify users of expiring items, even when offline.
*   **FL Chart**: Used to visualize "Overall Waste Rate," category-based waste distribution (Pie Chart), and "Weekly Waste Trends" (Bar Chart).
*   **Timezone (tz)**: Precise scheduling logic for notifications across different regions.

---

## 🚀 Implementation & Innovation

### Innovation: Smart Scanning Workflow
GrocerKu innovates the tedious process of manual data entry. By combining OCR and Image Labeling, users can simply point their camera at a grocery item. The app simultaneously attempts to identify the product name and its expiry date, prepopulating the entry form. This lowers the barrier to entry for food tracking.

### Implementation: Real-Time Impact Feedback
The "Impact Analysis" dashboard provides immediate psychological feedback. By calculating a "Waste Rate" based on total volume handled (Used vs. Wasted + Expired), users receive a clear score of their sustainability efforts. The integration between Firestore and FL Chart ensures these metrics update the moment an item is marked as used or passes its expiry date.

### Privacy-First Community
To encourage open discussion about food sustainability without compromising data, the community page uses a **Nickname-based system**. Users can set a custom alias, preventing the exposure of private email addresses while maintaining a persistent identity in discussions.

---

## ⚠️ Challenges Faced

### 1. The "Model Not Found" & API Versioning
During development, integrating the latest Gemini API models presented significant versioning challenges. Specifically, referencing experimental models like Gemini 2.0 through the Flutter SDK required exact `v1beta` configurations and Dart SDK upgrades. Due to regional availability and package constraints, we pivoted to optimizing local OCR and robust statistical tracking to ensure a stable user experience.

### 2. Accurate Waste Calculation logic
Initially, calculating an "Overall Waste Rate" resulted in values stuck at 100% because the logic only accounted for items currently in the fridge. We resolved this by implementing a "Total Managed Volume" algorithm, which tracks historical "Used" vs "Wasted" states alongside current inventory to provide a mathematically sound percentage.

### 3. Asynchronous Multi-Model Processing
Running both OCR and Image Labeling on a single camera snapshot required careful management of asynchronous futures. We optimized the workflow to ensure the UI remains responsive while two separate machine learning models process the same file in parallel.

---

## 🔮 Future Roadmap

*   **AI Culinary Assistant**: Re-integrating stable Gemini API models to provide personalized recipe suggestions based on "soon-to-expire" items in the user's inventory.
*   **Gamified Sustainability**: Introducing a reward system with badges and levels (e.g., "Zero-Waste Hero") to incentivize consistent food tracking and waste reduction.

---

## 📦 Getting Started

1.  **Clone the repo**: `git clone [repository-url]`
2.  **Install dependencies**: `flutter pub get`
3.  **Run the app**: `flutter run`

*Note: Firebase configuration files (`google-services.json`) are required for the authentication and database features to function.*
