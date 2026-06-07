# HealthAI Backend — Django REST Framework

AI parhez va fitnes kouch mobil ilovasi uchun backend.

---

## Talablar

- Python 3.11+
- pip

---

## O'rnatish

### 1. Virtual muhit yaratish

```bash
cd /path/to/healthai/backend
python3 -m venv venv
source venv/bin/activate        # Linux/macOS
# yoki
venv\Scripts\activate           # Windows
```

### 2. Kutubxonalarni o'rnatish

```bash
pip install -r requirements.txt
```

### 3. `.env` faylini sozlash

```bash
cp .env.example .env
```

`.env` faylini oching va quyidagilarni to'ldiring:

```env
GEMINI_API_KEY=AIza-xxxxxxxxxxxxxxxxxxxxxxxx
GEMINI_BASE_URL=https://generativelanguage.googleapis.com/v1beta
GEMINI_MODEL=gemini-3.5-flash
DJANGO_SECRET_KEY=sizning-maxfiy-kalitingiz
```

> **Eslatma:** `GEMINI_API_KEY` bo'sh qoldirilsa, ilova avtomatik hisoblangan fallback rejadan foydalanadi.

### 4. Ma'lumotlar bazasini yaratish (migratsiyalar)

```bash
python manage.py makemigrations
python manage.py migrate
```

### 5. Superuser yaratish (admin panel uchun)

```bash
python manage.py createsuperuser
```

### 6. Serverni ishga tushirish

```bash
python manage.py runserver
```

Brauzerda: http://127.0.0.1:8000/admin/

---

## API Endpoints — curl misollari

### Ro'yxatdan o'tish

```bash
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{
    "username": "ali",
    "email": "ali@example.com",
    "password": "Parol1234!",
    "password2": "Parol1234!"
  }'
```

**Javob:**
```json
{
  "user": {"id": 1, "username": "ali", "email": "ali@example.com"},
  "access": "eyJ...",
  "refresh": "eyJ..."
}
```

---

### Tizimga kirish

```bash
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username": "ali", "password": "Parol1234!"}'
```

---

### Token yangilash

```bash
curl -X POST http://localhost:8000/api/auth/refresh/ \
  -H "Content-Type: application/json" \
  -d '{"refresh": "REFRESH_TOKEN_BU_YERGA"}'
```

---

### Joriy foydalanuvchi ma'lumoti

```bash
curl -X GET http://localhost:8000/api/auth/me/ \
  -H "Authorization: Bearer ACCESS_TOKEN_BU_YERGA"
```

---

### Profilni ko'rish

```bash
curl -X GET http://localhost:8000/api/profile/ \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

---

### Profilni to'ldirish/yangilash

```bash
curl -X PUT http://localhost:8000/api/profile/ \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "full_name": "Ali Valiyev",
    "age": 28,
    "gender": "M",
    "height_cm": 178,
    "weight_kg": 85,
    "target_weight_kg": 75,
    "activity_level": "light",
    "goal": "lose_weight",
    "work_type": "sedentary",
    "work_hours_per_day": 8,
    "sleep_hours_per_day": 7,
    "water_liters_per_day": 2,
    "does_sport": false,
    "sport_type": "",
    "medical_conditions": "",
    "food_allergies": ""
  }'
```

---

### Parhez rejasini yaratish (AI bilan)

```bash
curl -X POST http://localhost:8000/api/diet-plan/generate/ \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"duration_days": 14}'
```

---

### Faol parhez rejasini ko'rish

```bash
curl -X GET http://localhost:8000/api/diet-plan/active/ \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

---

### Parhez rejalari tarixi

```bash
curl -X GET http://localhost:8000/api/diet-plan/history/ \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

---

### Kunlik log yaratish/yangilash

```bash
curl -X POST http://localhost:8000/api/daily-log/ \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2024-12-01",
    "weight_kg": 84.5,
    "water_liters": 2.5,
    "meals_followed": true,
    "workout_done": false,
    "sleep_hours": 7.5,
    "mood": "good",
    "notes": "Yaxshi kun o'\''tdi"
  }'
```

---

### Bugungi log

```bash
curl -X GET http://localhost:8000/api/daily-log/today/ \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

---

### Loglar ro'yxati (filtrlash bilan)

```bash
# Barcha loglar
curl -X GET "http://localhost:8000/api/daily-log/" \
  -H "Authorization: Bearer ACCESS_TOKEN"

# Muayyan sana
curl -X GET "http://localhost:8000/api/daily-log/?date=2024-12-01" \
  -H "Authorization: Bearer ACCESS_TOKEN"

# Sana oralig'i
curl -X GET "http://localhost:8000/api/daily-log/?from=2024-11-01&to=2024-12-01" \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

---

### Statistika

```bash
curl -X GET http://localhost:8000/api/stats/ \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

---

## Flutter ilovasini ulash

### Android emulyator (standart)

Flutter ilovasida base URL sifatida quyidagini ishlating:

```dart
const String baseUrl = 'http://10.0.2.2:8000/api';
```

`10.0.2.2` — Android emulyatorida kompyuteringizning localhost manzili.

---

### Haqiqiy telefon (real device)

Haqiqiy telefon bilan ulanish uchun kompyuteringizning lokal IP manzilini toping:

**macOS:**
```bash
ipconfig getifaddr en0
```

**Linux:**
```bash
ip addr show | grep "inet " | grep -v "127.0.0.1"
# yoki
hostname -I
```

**Windows:**
```bash
ipconfig
# IPv4 Address qatorini toping
```

Masalan, IP `192.168.1.5` bo'lsa, Flutter ilovasida:

```dart
const String baseUrl = 'http://192.168.1.5:8000/api';
```

> **Muhim:** Server `0.0.0.0` da ishga tushirilishi kerak:
> ```bash
> python manage.py runserver 0.0.0.0:8000
> ```
> Telefon va kompyuter bir xil Wi-Fi tarmog'ida bo'lishi kerak.

---

## Admin panel

http://localhost:8000/admin/

Superuser bilan kiring va barcha ma'lumotlarni boshqaring.

---

## Railway deploy

Loyiha Railway uchun tayyorlangan:

- repo rootdan deploy qilsangiz: `railway.json` va `nixpacks.toml` backendni avtomatik ishga tushiradi
- faqat `backend/` papkasini root directory qilsangiz: `backend/railway.json` va `backend/Procfile` ishlaydi

Railway variables:

```env
DJANGO_SECRET_KEY=uzun-va-tasodifiy-secret-key
DEBUG=False
GEMINI_API_KEY=AIza-...
GEMINI_BASE_URL=https://generativelanguage.googleapis.com/v1beta
GEMINI_MODEL=gemini-3.5-flash
```

PostgreSQL ishlatish uchun Railway’da Postgres service qo‘shing. Railway `DATABASE_URL`ni avtomatik beradi va backend shu URLdan foydalanadi.
`DATABASE_SSL_REQUIRE=True` faqat ulanishda SSL majburiy bo‘lgan Postgres host uchun kerak.

Custom domain yoki web frontend bo‘lsa:

```env
ALLOWED_HOSTS=your-domain.com
CSRF_TRUSTED_ORIGINS=https://your-domain.com
CORS_ALLOWED_ORIGINS=https://your-frontend-domain.com
CORS_ALLOW_ALL_ORIGINS=False
```

HTTPS/HSTSni yoqish uchun:

```env
SECURE_SSL_REDIRECT=True
SECURE_HSTS_SECONDS=31536000
```

Start command:

```bash
gunicorn healthai.wsgi:application --bind 0.0.0.0:$PORT
```

Release command:

```bash
python manage.py migrate
```

---

## Loyiha tuzilmasi

```
backend/
├── manage.py
├── requirements.txt
├── .env.example
├── .gitignore
├── README.md
├── healthai/
│   ├── __init__.py
│   ├── settings.py
│   ├── urls.py
│   ├── wsgi.py
│   └── asgi.py
└── core/
    ├── __init__.py
    ├── apps.py
    ├── models.py          # UserProfile, DietPlan, DailyLog
    ├── serializers.py
    ├── views.py
    ├── urls.py
    ├── admin.py
    ├── ai_service.py      # Gemini integratsiyasi + fallback
    └── migrations/
```

---

## Xavfsizlik eslatmalari (production)

- `DEBUG=False` qiling
- `ALLOWED_HOSTS` ni konkret domenlar bilan to'ldiring
- `CORS_ALLOW_ALL_ORIGINS=False` qilib, faqat Flutter ilova domenini ruxsat bering
- `DJANGO_SECRET_KEY` ni kuchli kalit bilan almashtiring
- PostgreSQL yoki boshqa kuchli MBga o'ting
