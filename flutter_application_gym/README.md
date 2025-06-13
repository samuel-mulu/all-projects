# 🏋️‍♂️ Gym Flutter App

> A powerful Flutter app for managing gym memberships and operations locally, featuring live counters, detailed reports, and real-time updates.  
> Built with Firebase Authentication and Firestore database for seamless backend support.

---

## ✨ Features

- 🔐 **Firebase Email/Password Authentication** with role-based access (Admin & Cashier)  
- ⏳ **Live 30-day counter** tracking new memberships and activities  
- 📊 **Monthly and yearly reports** with detailed analytics and profit calculations  
- 👥 **Active and inactive member tracking** with real-time status updates  
- ⚡ **Real-time data syncing** with Firestore for instant UI updates  
- 🎨 **User-friendly and modern UI** optimized for smooth user experience  
- 🛠️ **Admin panel** to manage members, subscriptions, and reports  
- 💳 **Cashier panel** for processing membership sales and renewals  

---

## 🛠️ Technologies Used

- 🐦 Flutter (Dart) for mobile app development  
- 🔥 Firebase Authentication for secure login  
- ☁️ Cloud Firestore for real-time database  
- ⚙️ Provider / Bloc / GetX (choose your state management)  
- 🧩 Custom widgets for clean and responsive UI  

---

## 🗂️ Screens and Modules

- 🔑 **Authentication Screens:** Login, Registration, and Role Selection  
- 📈 **Admin Dashboard:**  
  - 🕒 View live counters (new members, active members, inactive members)  
  - 📅 Generate and export monthly/yearly profit and activity reports  
  - 🗃️ Manage memberships and subscriptions  
- 💼 **Cashier Dashboard:**  
  - 💸 Process membership sales and renewals  
  - 🧾 View daily transactions and receipts  

---

## 🚀 Setup & Installation

```bash
# Clone the repository
git clone 
cd gym_flutter_app

# Install dependencies
flutter pub get

# Run the app
flutter run
