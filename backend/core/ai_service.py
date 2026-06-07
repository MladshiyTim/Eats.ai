"""
AI service for generating diet plans using Google Gemini API.
Falls back to computed plan if API is unavailable or key is missing.
"""

import os
import json
import base64
import requests
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .models import UserProfile


# Activity level multipliers for TDEE (Mifflin-St Jeor)
ACTIVITY_MULTIPLIERS = {
    'sedentary': 1.2,
    'light': 1.375,
    'moderate': 1.55,
    'active': 1.725,
    'very_active': 1.9,
}


def _calculate_bmr(profile) -> float:
    """Calculate Basal Metabolic Rate using Mifflin-St Jeor formula."""
    weight = profile.weight_kg or 70.0
    height = profile.height_cm or 170.0
    age = profile.age or 25

    if profile.gender == 'M':
        bmr = 10 * weight + 6.25 * height - 5 * age + 5
    else:
        bmr = 10 * weight + 6.25 * height - 5 * age - 161
    return bmr


def _calculate_tdee(profile) -> float:
    """Calculate Total Daily Energy Expenditure."""
    bmr = _calculate_bmr(profile)
    multiplier = ACTIVITY_MULTIPLIERS.get(profile.activity_level or 'sedentary', 1.2)
    return bmr * multiplier


def _adjust_calories_for_goal(tdee: float, goal: str) -> int:
    """Adjust calories based on goal."""
    if goal == 'lose_weight':
        return int(tdee - 500)
    elif goal == 'gain_weight':
        return int(tdee + 300)
    elif goal == 'build_muscle':
        return int(tdee + 200)
    else:  # maintain
        return int(tdee)


def _calculate_macros(calories: int, goal: str) -> dict:
    """Calculate protein, carbs, and fat in grams."""
    # Protein: 25-30% for muscle, 30% for lose, 20% for maintain/gain
    if goal in ('build_muscle',):
        protein_pct, fat_pct = 0.30, 0.25
    elif goal == 'lose_weight':
        protein_pct, fat_pct = 0.30, 0.30
    else:
        protein_pct, fat_pct = 0.20, 0.30

    carbs_pct = 1.0 - protein_pct - fat_pct

    protein_g = int((calories * protein_pct) / 4)
    fat_g = int((calories * fat_pct) / 9)
    carbs_g = int((calories * carbs_pct) / 4)

    return {'protein_g': protein_g, 'carbs_g': carbs_g, 'fat_g': fat_g}


def _make_simple_meal_template(calories: int, day: int) -> dict:
    """Generate a simple meal template for fallback plan."""
    breakfast_cal = int(calories * 0.25)
    lunch_cal = int(calories * 0.35)
    dinner_cal = int(calories * 0.30)
    snack_cal = calories - breakfast_cal - lunch_cal - dinner_cal

    return {
        'day': day,
        'breakfast': {
            'name': 'Tuxum va non',
            'calories': breakfast_cal,
            'ingredients': ['2 ta tuxum', '2 bo\'lak non', '1 stakan sut yoki choy'],
        },
        'lunch': {
            'name': 'Guruch va tovuq',
            'calories': lunch_cal,
            'ingredients': ['150g tovuq go\'shti', '100g guruch', 'sabzavotlar salati'],
        },
        'dinner': {
            'name': 'Baliq va sabzavot',
            'calories': dinner_cal,
            'ingredients': ['150g baliq', 'bug\'langan sabzavotlar', '100g kartoshka'],
        },
        'snacks': [
            {
                'name': 'Meva va yong\'oq',
                'calories': snack_cal,
                'ingredients': ['1 ta olma', '30g yong\'oq yoki bodom'],
            }
        ],
    }


def _get_sport_advice_fallback(work_type: str, goal: str) -> str:
    """Generate sport advice based on work type and goal."""
    base = {
        'sedentary': "Siz kun davomida ko'p o'tirasiz, shuning uchun har kuni kamida 30 daqiqa yurish yoki engil mashqlar qilish zarur.",
        'standing': "Siz kun davomida ko'p turasiz. Oyoq va dum g'a mashqlariga e'tibor bering.",
        'physical': "Siz jismoniy ish qilasiz. Mashqlar kuchini tiklash va cho'zilishga qaratilsin.",
        'mixed': "Aralash faoliyat uchun muvozanatli mashq dasturi tavsiya etiladi.",
    }.get(work_type or 'sedentary', "Muntazam jismoniy faoliyat sog'liq uchun muhim.")

    goal_suffix = {
        'lose_weight': " Yog' yoqish uchun kardio mashqlari (yugurish, velosiped, suzish) haftada 4-5 marta 45 daqiqa davom ettirilsin.",
        'gain_weight': " Vazn oshirish uchun og'irlik ko'tarish mashqlari haftada 3-4 marta tavsiya etiladi.",
        'build_muscle': " Mushak qurish uchun og'irlik mashqlari haftada 4-5 marta, har gruppa uchun 3-4 set.",
        'maintain': " Sog'liqni saqlash uchun haftada 3-4 marta aralash (kardio + kuch) mashqlar qiling.",
    }.get(goal or 'maintain', '')

    return base + goal_suffix


def _build_fallback_plan(profile, duration_days: int) -> dict:
    """Build a complete fallback plan using calculated values."""
    tdee = _calculate_tdee(profile)
    calories = _adjust_calories_for_goal(tdee, profile.goal or 'maintain')
    # Ensure minimum calories
    calories = max(calories, 1200 if (profile.gender == 'F') else 1500)

    macros = _calculate_macros(calories, profile.goal or 'maintain')

    water = profile.water_liters_per_day or max(2.0, round((profile.weight_kg or 70) * 0.033, 1))

    meal_plan = [_make_simple_meal_template(calories, day + 1) for day in range(duration_days)]

    sport_rec = _get_sport_advice_fallback(profile.work_type, profile.goal)

    advice = (
        f"Kunlik kaloriya: {calories} kkal. "
        f"Oqsil: {macros['protein_g']}g, Uglevodlar: {macros['carbs_g']}g, Yog': {macros['fat_g']}g. "
        f"Kunlik suv: {water} litr. "
        "Ushbu reja sizning profilingiz asosida hisoblangan. "
        "Yaxshi natijalar uchun rejaga qat'iy amal qiling va haftalik vazningizni kuzating."
    )

    return {
        'daily_calories': calories,
        'daily_protein_g': macros['protein_g'],
        'daily_carbs_g': macros['carbs_g'],
        'daily_fat_g': macros['fat_g'],
        'daily_water_liters': water,
        'meal_plan': meal_plan,
        'sport_recommendation': sport_rec,
        'general_advice': advice,
    }


def _build_prompt(profile, duration_days: int, bmr: float, tdee: float) -> str:
    """Build the AI prompt in Uzbek."""
    target_weight_str = f"{profile.target_weight_kg} kg" if profile.target_weight_kg else "Ko'rsatilmagan"
    sport_str = f"Ha, {profile.sport_type}" if profile.does_sport and profile.sport_type else ("Ha" if profile.does_sport else "Yo'q")
    medical_str = profile.medical_conditions or "Yo'q"
    allergies_str = profile.food_allergies or "Yo'q"

    goal_map = {
        'lose_weight': 'Vazn yo\'qotish',
        'gain_weight': 'Vazn oshirish',
        'maintain': 'Vaznni saqlash',
        'build_muscle': 'Mushak qurish',
    }
    activity_map = {
        'sedentary': 'Harakatsiz (kun bo\'yi o\'tirish)',
        'light': 'Engil (haftada 1-3 marta yurish)',
        'moderate': 'O\'rtacha (haftada 3-5 marta mashq)',
        'active': 'Faol (haftada 6-7 marta mashq)',
        'very_active': 'Juda faol (jismoniy ish yoki intensiv sport)',
    }
    work_map = {
        'sedentary': 'O\'troq (ofis, kompyuter)',
        'standing': 'Tik turib ishlash',
        'physical': 'Jismoniy mehnat',
        'mixed': 'Aralash',
    }

    return f"""Siz professional dietolog va fitnes mutaxassisisiz. Quyidagi foydalanuvchi ma'lumotlari asosida {duration_days} kunlik to'liq parhez va sport rejasini tuzing.

## Foydalanuvchi ma'lumotlari:
- Yosh: {profile.age} yosh
- Jins: {"Erkak" if profile.gender == "M" else "Ayol"}
- Bo'y: {profile.height_cm} sm
- Hozirgi vazn: {profile.weight_kg} kg
- Maqsad vazn: {target_weight_str}
- Faollik darajasi: {activity_map.get(profile.activity_level or 'sedentary', profile.activity_level)}
- Maqsad: {goal_map.get(profile.goal or 'maintain', profile.goal)}
- Ish turi: {work_map.get(profile.work_type or 'sedentary', profile.work_type)}
- Kunlik ish soatlari: {profile.work_hours_per_day or 8} soat
- Uyqu: {profile.sleep_hours_per_day or 7} soat/kun
- Suv iste'moli: {profile.water_liters_per_day or 2} litr/kun
- Sport qilish: {sport_str}
- Tibbiy holatlar: {medical_str}
- Oziq-ovqat allergiyalari: {allergies_str}

## Hisoblangan qiymatlar (yo'riqnoma sifatida):
- BMR (Mifflin-St Jeor): {bmr:.0f} kkal/kun
- TDEE (jismoniy faollik bilan): {tdee:.0f} kkal/kun

## Talablar:
Faqat quyidagi JSON formatida javob bering (boshqa hech qanday matn yo'q):

{{
  "daily_calories": <int>,
  "daily_protein_g": <int>,
  "daily_carbs_g": <int>,
  "daily_fat_g": <int>,
  "daily_water_liters": <float>,
  "meal_plan": [
    {{
      "day": 1,
      "breakfast": {{"name": "<taom nomi>", "calories": <int>, "ingredients": ["<ingredient1>", ...]}},
      "lunch": {{"name": "<taom nomi>", "calories": <int>, "ingredients": ["<ingredient1>", ...]}},
      "dinner": {{"name": "<taom nomi>", "calories": <int>, "ingredients": ["<ingredient1>", ...]}},
      "snacks": [{{"name": "<taom nomi>", "calories": <int>, "ingredients": ["<ingredient1>", ...]}}]
    }},
    ... (jami {duration_days} kun)
  ],
  "sport_recommendation": "<Uzbek tilida batafsil sport tavsiyasi - foydalanuvchining ish turi va maqsadiga mos>",
  "general_advice": "<Uzbek tilida umumiy maslahatlar>"
}}

Muhim:
- Kaloriya miqdori TDEE va maqsadga mos bo'lsin (vazn yo'qotish uchun -400-600 kkal, oshirish uchun +200-400 kkal)
- Mahalliy o'zbek taomlarini ham kiriting
- Allergiyalarga e'tibor bering: {allergies_str}
- Tibbiy holatlarga mos keling: {medical_str}
- Har bir kun uchun turli-xil taomlar taklif eting
"""


def generate_diet_plan(profile, duration_days: int) -> dict:
    """
    Generate a diet plan using AI or fallback to computed plan.

    Args:
        profile: UserProfile instance
        duration_days: Number of days for the plan

    Returns:
        dict with keys: daily_calories, daily_protein_g, daily_carbs_g, daily_fat_g,
                        daily_water_liters, meal_plan, sport_recommendation, general_advice
    """
    api_key = os.environ.get('GEMINI_API_KEY', '').strip()
    base_url = os.environ.get(
        'GEMINI_BASE_URL',
        'https://generativelanguage.googleapis.com/v1beta',
    ).rstrip('/')
    model = os.environ.get('GEMINI_MODEL', 'gemini-2.0-flash')

    bmr = _calculate_bmr(profile)
    tdee = _calculate_tdee(profile)

    # Use fallback if no API key
    if not api_key:
        return _build_fallback_plan(profile, duration_days)

    try:
        prompt = _build_prompt(profile, duration_days, bmr, tdee)

        headers = {
            'x-goog-api-key': api_key,
            'Content-Type': 'application/json',
        }
        payload = {
            'contents': [
                {
                    'role': 'user',
                    'parts': [
                        {
                            'text': (
                                'Siz professional dietolog va fitnes mutaxassisisiz. '
                                'Faqat JSON formatida javob bering, boshqa hech qanday matn yozmang.\n\n'
                                f'{prompt}'
                            )
                        }
                    ],
                },
            ],
            'generationConfig': {
                'temperature': 0.7,
                'maxOutputTokens': 8000,
                'responseMimeType': 'application/json',
            },
        }

        # Keep this strictly below gunicorn's --timeout so a slow Gemini call
        # raises requests.Timeout (caught below → fallback plan) instead of
        # gunicorn SIGABRT-ing the worker, which would raise SystemExit and
        # bypass the fallback.
        response = requests.post(
            f'{base_url}/models/{model}:generateContent',
            headers=headers,
            json=payload,
            timeout=(10, 60),
        )
        response.raise_for_status()

        data = response.json()
        parts = data['candidates'][0]['content']['parts']
        content = ''.join(part.get('text', '') for part in parts).strip()

        # Strip markdown code blocks if present
        if content.startswith('```'):
            lines = content.split('\n')
            # Remove first line (```json or ```) and last line (```)
            lines = lines[1:-1] if lines[-1] == '```' else lines[1:]
            content = '\n'.join(lines)

        result = json.loads(content)

        # Validate required keys
        required_keys = [
            'daily_calories', 'daily_protein_g', 'daily_carbs_g',
            'daily_fat_g', 'daily_water_liters', 'meal_plan',
            'sport_recommendation', 'general_advice',
        ]
        for key in required_keys:
            if key not in result:
                raise ValueError(f"Missing key in AI response: {key}")

        # Ensure meal_plan has correct number of days
        if len(result.get('meal_plan', [])) < duration_days:
            # Pad with fallback days
            fallback = _build_fallback_plan(profile, duration_days)
            while len(result['meal_plan']) < duration_days:
                day_num = len(result['meal_plan']) + 1
                result['meal_plan'].append(_make_simple_meal_template(result['daily_calories'], day_num))

        return result

    except Exception:
        # Any failure → fallback
        return _build_fallback_plan(profile, duration_days)


# ─── Food photo → calories (Gemini Vision) ─────────────────────────────────────

_FOOD_VISION_PROMPT = (
    "Siz oziq-ovqat va kaloriya tahlili bo'yicha mutaxassissiz. "
    "Rasмdagi taomni aniqlang va taxminiy oziqaviy qiymatini hisoblang. "
    "Rasmda bir nechta taom bo'lsa, ularning umumiy yig'indisini bering. "
    "Porsiya hajmini ko'rinishidan taxmin qiling. "
    "Agar rasmda taom umuman bo'lmasa, is_food=false qiling.\n\n"
    "Faqat quyidagi JSON formatida javob bering (boshqa matn yo'q):\n"
    "{\n"
    '  "is_food": <true|false>,\n'
    '  "name": "<taom nomi, o\'zbek tilida>",\n'
    '  "calories": <int, jami kkal>,\n'
    '  "protein_g": <number>,\n'
    '  "carbs_g": <number>,\n'
    '  "fat_g": <number>,\n'
    '  "portion_note": "<porsiya tavsifi, masalan: 1 kosa, ~300g>",\n'
    '  "confidence": <0.0-1.0 oraligida ishonch darajasi>\n'
    "}"
)


def analyze_food_image(image_bytes: bytes, mime_type: str = 'image/jpeg') -> dict:
    """
    Analyze a food photo with Gemini Vision and estimate its nutrition.

    Returns a dict:
        {is_food, name, calories, protein_g, carbs_g, fat_g, portion_note,
         confidence, error?}

    On any failure returns {'is_food': False, 'error': <reason>} so the caller
    can surface a friendly message instead of crashing.
    """
    api_key = os.environ.get('GEMINI_API_KEY', '').strip()
    base_url = os.environ.get(
        'GEMINI_BASE_URL',
        'https://generativelanguage.googleapis.com/v1beta',
    ).rstrip('/')
    model = os.environ.get('GEMINI_VISION_MODEL', os.environ.get('GEMINI_MODEL', 'gemini-2.0-flash'))

    if not api_key:
        return {'is_food': False, 'error': 'AI xizmati sozlanmagan (API kalit yo\'q).'}

    try:
        encoded = base64.b64encode(image_bytes).decode('ascii')
        headers = {
            'x-goog-api-key': api_key,
            'Content-Type': 'application/json',
        }
        payload = {
            'contents': [
                {
                    'role': 'user',
                    'parts': [
                        {'text': _FOOD_VISION_PROMPT},
                        {'inline_data': {'mime_type': mime_type, 'data': encoded}},
                    ],
                },
            ],
            'generationConfig': {
                'temperature': 0.2,
                'maxOutputTokens': 1024,
                'responseMimeType': 'application/json',
            },
        }

        response = requests.post(
            f'{base_url}/models/{model}:generateContent',
            headers=headers,
            json=payload,
            timeout=(10, 60),
        )
        response.raise_for_status()

        data = response.json()
        parts = data['candidates'][0]['content']['parts']
        content = ''.join(part.get('text', '') for part in parts).strip()

        if content.startswith('```'):
            lines = content.split('\n')
            lines = lines[1:-1] if lines[-1] == '```' else lines[1:]
            content = '\n'.join(lines)

        result = json.loads(content)

        if not result.get('is_food', False):
            return {'is_food': False, 'error': 'Rasmda taom aniqlanmadi.'}

        return {
            'is_food': True,
            'name': str(result.get('name', 'Aniqlanmagan taom'))[:255],
            'calories': int(round(float(result.get('calories', 0) or 0))),
            'protein_g': float(result.get('protein_g', 0) or 0),
            'carbs_g': float(result.get('carbs_g', 0) or 0),
            'fat_g': float(result.get('fat_g', 0) or 0),
            'portion_note': str(result.get('portion_note', ''))[:255],
            'confidence': float(result.get('confidence', 0) or 0),
        }

    except Exception as exc:  # noqa: BLE001 — surface a friendly error
        return {'is_food': False, 'error': f'Rasmni tahlil qilib bo\'lmadi: {exc}'}
