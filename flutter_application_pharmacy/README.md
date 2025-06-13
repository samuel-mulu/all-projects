# 💊 Pharmacy Flutter App

> A comprehensive Flutter app for managing pharmacy inventory and sales locally, featuring live updates, detailed reports, and smooth user experience.  
> Powered by Firebase Authentication and Firestore database.

---

## ✨ Features

- 🔐 **Firebase Email/Password Authentication** with role-based access (Admin & Cashier)  
- 🏷️ **Pharmacy product inventory management** (add, update, delete products)  
- 💸 **Sales processing** with real-time updates and receipt generation  
- 📊 **Monthly and yearly sales reports** including profit calculations  
- 📦 **Stock level tracking** with alerts for low inventory  
- ⚡ **Real-time data syncing** with Firestore for instant UI updates  
- 🎨 **Clean and intuitive UI** optimized for quick workflow  
- 🛠️ **Admin panel** for inventory and user management  
- 💼 **Cashier panel** for fast and accurate sales transactions  

---

## 🛠️ Technologies Used

- 🐦 Flutter (Dart) for cross-platform mobile app development  
- 🔥 Firebase Authentication for secure user login  
- ☁️ Cloud Firestore for real-time NoSQL database  
- ⚙️ Provider / Bloc / GetX (choose your state management)  
- 🧩 Custom widgets for responsive and reusable UI components  

---

## 🗂️ Screens and Modules

- 🔑 **Authentication Screens:** User login and role-based access  
- 🏢 **Admin Dashboard:**  
  - 📋 Manage pharmacy products and inventory  
  - 📦 Monitor stock levels and set alerts  
  - 📅 Generate and review monthly/yearly sales and profit reports  
  - 👥 Manage cashier accounts  
- 💼 **Cashier Dashboard:**  
  - 💳 Process product sales and generate receipts  
  - 📊 View daily sales summary  

---

## 🚀 Setup & Installation

```bash
# Clone the repository
git clone <your-repo-url>
cd pharmacy_flutter_app

# Install dependencies
flutter pub get

# Run the app
flutter run
