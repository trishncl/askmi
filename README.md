<div align="center">

<img src="./askmi.gif" alt="AskMi Logo" width="220"/>

# AskMi

**An AI-Assisted Decision Support for AA’s Lomi**

</div>

---

## 📌 Project Overview

AskMi is a mobile application developed for AA’s Lomi. It provides role-based access for the owner, managers, and cashiers to manage sales, inventory, products, reports, and user management.

## How to Open the Project

1. Download and extract the project folder.
2. Open **Visual Studio Code**.
3. Select **File > Open Folder**.
4. Open the `askmi_app` folder containing the `pubspec.yaml` file.
5. Open the terminal in Visual Studio Code.
6. Install the required packages:

```bash
flutter pub get
```

7. Run the application:

```bash
flutter run
```

To run the application in Google Chrome:

```bash
flutter run -d chrome
```

## Firebase Configuration

The application uses Firebase Authentication and Cloud Firestore.

Run the following commands to connect the project to Firebase:

```bash
firebase login
flutterfire configure
```

Select the official AskMi Firebase project and the required platforms. After configuration, run:

```bash
flutter clean
flutter pub get
flutter run
```

## 👥 User Roles and Features

### Owner

- Dashboard with filters for all four branches
- Sales monitoring
- Product and inventory management
- Viewing reports submitted by managers
- User account management
- Menu management
- Branch information and filtering
- Notifications
- Navigation drawer and bottom navigation bar

### Manager

- Dashboard for the assigned branch
- Sales monitoring
- Product and inventory management
- Report generation and submission to the owner
- Menu management
- Notifications
- Navigation drawer and bottom navigation bar

### Cashier

- Point of Sale
- Viewing available menu products
- Adding and updating cart items
- Processing Cash and GCash payments
- Completing checkout transactions
- Automatic stock deduction after checkout

## Technologies Used

- Flutter
- Dart
- Firebase Authentication
- Cloud Firestore
- Material Design 3
- Provider or Riverpod
- Google Fonts

## 📁 Required Project Folder

Open the folder containing the following files and directories:

```text
pubspec.yaml
lib/
assets/
android/
web/
```

Opening a folder without `pubspec.yaml` may cause Flutter to display:

```text
No pubspec.yaml file found
```
