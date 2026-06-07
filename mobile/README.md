# AI Salomatlik — Flutter mobil ilovasi

Sun'iy intellekt asosidagi parhez va fitness kouching ilovasi. Django REST backend bilan ishlaydi.

---

## Talablar

| Talab | Versiya |
|-------|---------|
| Flutter SDK | 3.x (≥ 3.3.0) |
| Dart | ≥ 3.3.0 |
| Android Studio yoki VS Code | Oxirgi versiya |
| Android emulyator yoki real qurilma | — |

### Flutter SDK o'rnatish

Flutter SDK ni rasmiy saytdan yuklab oling:  
👉 [https://docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install)

O'rnatgandan so'ng PATH ni sozlang va quyidagi buyruq bilan tekshiring:
```bash
flutter doctor
```
Barcha talab qilingan komponentlar yashil ko'rinishi kerak.

---

## Loyihani sozlash

### 1. Paketlarni o'rnatish

```bash
cd healthai/mobile
flutter pub get
```

### 2. Backend URL ni sozlash

`lib/config.dart` faylini oching va `apiBaseUrl` konstantasini o'zgartiring:

```dart
// Android emulyator uchun (standart):
const String apiBaseUrl = 'http://10.0.2.2:8000/api';

// iOS simulyator uchun:
const String apiBaseUrl = 'http://localhost:8000/api';

// Real qurilma uchun — kompyuteringizning lokal IP manzilini kiriting:
// Windows: ipconfig | grep "IPv4"
// Mac/Linux: ifconfig | grep "inet "
const String apiBaseUrl = 'http://192.168.1.42:8000/api';
```

> **Muhim:** Real qurilmada test qilganda, telefon va kompyuter **bir xil Wi-Fi tarmog'ida** bo'lishi kerak!

---

## Backendni ishga tushirish

Backend Django serverni ishga tushirish (barcha interfeyslarda):

```bash
cd ../backend
python manage.py runserver 0.0.0.0:8000
```

Emulyatorda `10.0.2.2:8000` manzili orqali, real qurilmada esa kompyuteringizning LAN IP manzili orqali ulaniladi.

---

## Ilovani ishga tushirish

### Debug rejimda

```bash
flutter run
```

Bir nechta qurilma ulangan bo'lsa:
```bash
flutter devices          # Mavjud qurilmalar ro'yxati
flutter run -d emulator-5554   # Muayyan qurilmada
```

### Release (APK) ni qurish

```bash
flutter build apk --release
```

APK fayl quyidagi joyda yaratiladi:
```
build/app/outputs/flutter-apk/app-release.apk
```

### Debug APK qurish

```bash
flutter build apk --debug
```

---

## APK ni telefonga o'rnatish

### Usul 1: USB orqali

```bash
# USB debugging yoqilgan bo'lsin (Settings → Developer options → USB debugging)
flutter install
# yoki
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Usul 2: Telegram orqali

1. `app-release.apk` faylini Telegram orqali o'zingizga yuboring
2. Telefoningizda faylni yuklab oling
3. Fayl menejeri orqali APK ni toping va bosing
4. Agar so'ralsa: **Sozlamalar → Noma'lum manbalardan o'rnatishga ruxsat** ni yoqing
5. O'rnatishni tasdiqlang

> **Eslatma:** Android 8+ da "Noma'lum manbalar" sozlamasi ilova bo'yicha alohida: Sozlamalar → Maxsus ruxsatlar → Noma'lum ilovalar o'rnatish.

---

## iOS uchun qurish

iOS uchun **Mac kompyuter** talab qilinadi:

```bash
# iOS simulyatorda
flutter run

# Release build
flutter build ios --release
```

TestFlight yoki to'g'ridan-to'g'ri o'rnatish uchun Xcode kerak bo'ladi.

---

## Backend bilan bog'lanish muammolari

| Muammo | Yechim |
|--------|--------|
| `Connection refused` | Backend ishga tushganini tekshiring: `python manage.py runserver 0.0.0.0:8000` |
| Emulyatorda ulanmayapti | `10.0.2.2` manzilini ishlating (localhost emas!) |
| Real qurilmada ulanmayapti | Bir xil Wi-Fi tarmog'idaligingizni tekshiring; `lib/config.dart` da LAN IP ni to'g'ri kiriting |
| Port bloklangan | Xavfsizlik devori (firewall) sozlamalarini tekshiring; port 8000 ochiq bo'lishi kerak |
| HTTPS xatosi | Hozircha HTTP ishlatilmoqda; `AndroidManifest.xml` da `usesCleartextTraffic="true"` mavjud |

### IP manzilni topish

**Windows:**
```cmd
ipconfig
```
"IPv4 Address" qatoridagi manzilni oling, masalan: `192.168.1.42`

**Mac / Linux:**
```bash
ifconfig | grep "inet "
# yoki
ip addr show
```

---

## Loyiha strukturasi

```
lib/
├── main.dart              — Ilovaning kirish nuqtasi, Provider sozlamasi
├── config.dart            — API URL va konstantalar
├── theme.dart             — Material 3 dizayn tizimi (yashil rang)
├── models/
│   ├── user.dart          — Foydalanuvchi modeli
│   ├── profile.dart       — Sog'liq profili modeli
│   ├── diet_plan.dart     — Parhez rejasi modeli (DietPlan, DayPlan, Meal)
│   └── daily_log.dart     — Kunlik qayd modeli
├── services/
│   ├── api_client.dart    — HTTP client, JWT inject, token refresh
│   ├── auth_service.dart  — Login, register, logout
│   ├── profile_service.dart — Profil CRUD
│   ├── diet_service.dart  — Reja olish va yaratish
│   └── log_service.dart   — Kunlik qaydlar
├── providers/
│   ├── auth_provider.dart    — Autentifikatsiya holati
│   └── profile_provider.dart — Profil holati
├── screens/
│   ├── splash_screen.dart    — Token tekshiruvi
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── questionnaire_screen.dart — 5 bosqichli shakl
│   ├── home_screen.dart      — Bottom navigation
│   ├── dashboard_tab.dart    — Bosh sahifa
│   ├── plan_tab.dart         — Parhez rejasi
│   ├── log_tab.dart          — Kunlik qaydlar
│   ├── profile_tab.dart      — Profil
│   └── generate_plan_screen.dart — AI reja yaratish
└── widgets/
    ├── primary_button.dart   — Tugma komponent
    ├── labeled_field.dart    — Matn kiritish maydoni
    ├── section_card.dart     — Karta komponent
    └── stat_chip.dart        — Statistika chip
```

---

## Litsenziya

Ushbu loyiha shaxsiy foydalanish va o'qitish maqsadida yaratilgan.
