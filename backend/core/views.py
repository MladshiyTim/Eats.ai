import os
from datetime import date, timedelta

from django.contrib.auth.models import User
from django.db.models import Avg
from django.utils import timezone
from rest_framework import status
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from .ai_service import generate_diet_plan, analyze_food_image
from .models import DietPlan, DailyLog, UserProfile, FoodLog, DeviceToken
from .serializers import (
    DailyLogSerializer,
    DietPlanSerializer,
    DeviceTokenSerializer,
    FoodLogSerializer,
    ProfileQuestionnaireSerializer,
    RegisterSerializer,
    UserProfileSerializer,
    UserSerializer,
)


# ─── Auth ────────────────────────────────────────────────────────────────────


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            from rest_framework_simplejwt.tokens import RefreshToken
            refresh = RefreshToken.for_user(user)
            return Response(
                {
                    'user': UserSerializer(user).data,
                    'access': str(refresh.access_token),
                    'refresh': str(refresh),
                },
                status=status.HTTP_201_CREATED,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = TokenObtainPairSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.user
            UserProfile.objects.get_or_create(user=user)
            return Response(
                {
                    'user': UserSerializer(user).data,
                    'access': serializer.validated_data['access'],
                    'refresh': serializer.validated_data['refresh'],
                }
            )
        return Response(serializer.errors, status=status.HTTP_401_UNAUTHORIZED)


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Ensure profile exists for the user
        UserProfile.objects.get_or_create(user=request.user)
        # Flutter expects a flat User object here
        serializer = UserSerializer(request.user)
        return Response(serializer.data)


# ─── Profile ─────────────────────────────────────────────────────────────────


class ProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        serializer = UserProfileSerializer(profile)
        return Response(serializer.data)

    def put(self, request):
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        serializer = ProfileQuestionnaireSerializer(profile, data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(UserProfileSerializer(profile).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def patch(self, request):
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        serializer = ProfileQuestionnaireSerializer(profile, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(UserProfileSerializer(profile).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def post(self, request):
        return self.patch(request)


# ─── Diet Plan ────────────────────────────────────────────────────────────────


class GenerateDietPlanView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        profile, _ = UserProfile.objects.get_or_create(user=request.user)

        # Validate profile completeness
        required_fields = ['height_cm', 'weight_kg', 'age', 'goal', 'activity_level']
        missing = [f for f in required_fields if not getattr(profile, f)]
        if missing:
            return Response(
                {
                    'error': 'Profil to\'liq emas.',
                    'missing_fields': missing,
                    'message': f"Iltimos, quyidagi maydonlarni to'ldiring: {', '.join(missing)}",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        duration_days = request.data.get('duration_days', 14)
        try:
            duration_days = int(duration_days)
            if duration_days < 1:
                raise ValueError
        except (ValueError, TypeError):
            return Response(
                {'error': 'duration_days musbat butun son bo\'lishi kerak.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Generate plan via AI (or fallback)
        plan_data = generate_diet_plan(profile, duration_days)

        # Deactivate previous plans
        DietPlan.objects.filter(user=request.user, is_active=True).update(is_active=False)

        today = date.today()
        diet_plan = DietPlan.objects.create(
            user=request.user,
            duration_days=duration_days,
            start_date=today,
            end_date=today + timedelta(days=duration_days - 1),
            daily_calories=plan_data['daily_calories'],
            daily_protein_g=plan_data['daily_protein_g'],
            daily_carbs_g=plan_data['daily_carbs_g'],
            daily_fat_g=plan_data['daily_fat_g'],
            daily_water_liters=plan_data['daily_water_liters'],
            meal_plan=plan_data['meal_plan'],
            sport_recommendation=plan_data['sport_recommendation'],
            general_advice=plan_data['general_advice'],
            is_active=True,
        )

        serializer = DietPlanSerializer(diet_plan)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class ActiveDietPlanView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            plan = DietPlan.objects.get(user=request.user, is_active=True)
            return Response(DietPlanSerializer(plan).data)
        except DietPlan.DoesNotExist:
            return Response(
                {'detail': 'Faol parhez rejasi topilmadi.'},
                status=status.HTTP_404_NOT_FOUND,
            )


class DietPlanHistoryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        plans = DietPlan.objects.filter(user=request.user)
        serializer = DietPlanSerializer(plans, many=True)
        return Response(serializer.data)


# ─── Daily Log ────────────────────────────────────────────────────────────────


class DailyLogListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        logs = DailyLog.objects.filter(user=request.user)

        # Filter by specific date
        date_param = request.query_params.get('date')
        if date_param:
            logs = logs.filter(date=date_param)

        # Filter by date range
        from_param = request.query_params.get('from')
        to_param = request.query_params.get('to')
        if from_param:
            logs = logs.filter(date__gte=from_param)
        if to_param:
            logs = logs.filter(date__lte=to_param)

        serializer = DailyLogSerializer(logs, many=True)
        return Response(serializer.data)

    def post(self, request):
        """Create or update (upsert) a daily log for a given date."""
        log_date = request.data.get('date', str(date.today()))

        try:
            log = DailyLog.objects.get(user=request.user, date=log_date)
            serializer = DailyLogSerializer(log, data=request.data, partial=True)
        except DailyLog.DoesNotExist:
            serializer = DailyLogSerializer(data=request.data)

        if serializer.is_valid():
            serializer.save(user=request.user)
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class TodayLogView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        today = date.today()
        log, created = DailyLog.objects.get_or_create(
            user=request.user,
            date=today,
            defaults={'water_liters': 0.0, 'meals_followed': False, 'workout_done': False},
        )
        serializer = DailyLogSerializer(log)
        return Response(serializer.data)


class DailyLogDetailView(APIView):
    """Detail endpoint that supports both numeric id and ISO date in the URL."""
    permission_classes = [IsAuthenticated]

    def _get_log(self, request, key):
        # Try interpreting key as numeric id first
        if key.isdigit():
            try:
                return DailyLog.objects.get(user=request.user, id=int(key))
            except DailyLog.DoesNotExist:
                return None
        # Otherwise treat as YYYY-MM-DD date string
        try:
            return DailyLog.objects.get(user=request.user, date=key)
        except DailyLog.DoesNotExist:
            return None

    def get(self, request, key):
        log = self._get_log(request, key)
        if log is None:
            return Response({'detail': 'Topilmadi'}, status=status.HTTP_404_NOT_FOUND)
        return Response(DailyLogSerializer(log).data)

    def patch(self, request, key):
        log = self._get_log(request, key)
        if log is None:
            return Response({'detail': 'Topilmadi'}, status=status.HTTP_404_NOT_FOUND)
        serializer = DailyLogSerializer(log, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save(user=request.user)
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def put(self, request, key):
        return self.patch(request, key)

    def delete(self, request, key):
        log = self._get_log(request, key)
        if log is None:
            return Response({'detail': 'Topilmadi'}, status=status.HTTP_404_NOT_FOUND)
        log.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


# ─── Stats ────────────────────────────────────────────────────────────────────


class StatsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        today = date.today()
        thirty_days_ago = today - timedelta(days=30)
        seven_days_ago = today - timedelta(days=7)

        # Current weight: most recent log with weight
        recent_weight_log = (
            DailyLog.objects.filter(user=request.user, weight_kg__isnull=False)
            .order_by('-date')
            .first()
        )
        current_weight = recent_weight_log.weight_kg if recent_weight_log else None

        # Also fall back to profile weight
        if current_weight is None:
            try:
                current_weight = request.user.profile.weight_kg
            except UserProfile.DoesNotExist:
                current_weight = None

        # Weight change last 30 days
        weight_30_days_ago_log = (
            DailyLog.objects.filter(
                user=request.user,
                weight_kg__isnull=False,
                date__gte=thirty_days_ago,
            )
            .order_by('date')
            .first()
        )
        weight_change_30d = None
        if current_weight is not None and weight_30_days_ago_log is not None:
            weight_change_30d = round(current_weight - weight_30_days_ago_log.weight_kg, 2)

        # Last 7 days averages
        last_7_logs = DailyLog.objects.filter(
            user=request.user,
            date__gte=seven_days_ago,
        )
        total_7 = last_7_logs.count()

        avg_water = None
        avg_sleep = None
        avg_calories = None
        workout_adherence = None
        meal_adherence = None

        if total_7 > 0:
            agg = last_7_logs.aggregate(
                avg_water=Avg('water_liters'),
                avg_sleep=Avg('sleep_hours'),
                avg_calories=Avg('calories_consumed'),
            )
            avg_water = round(agg['avg_water'], 2) if agg['avg_water'] else 0
            avg_sleep = round(agg['avg_sleep'], 2) if agg['avg_sleep'] else None
            avg_calories = round(agg['avg_calories']) if agg['avg_calories'] else None

            workout_count = last_7_logs.filter(workout_done=True).count()
            meals_count = last_7_logs.filter(meals_followed=True).count()
            workout_adherence = round((workout_count / total_7) * 100, 1)
            meal_adherence = round((meals_count / total_7) * 100, 1)

        # Flat shape consumed by the Flutter client
        workout_count_7d = last_7_logs.filter(workout_done=True).count() if total_7 > 0 else 0
        meals_count_7d = last_7_logs.filter(meals_followed=True).count() if total_7 > 0 else 0

        return Response(
            {
                'current_weight_kg': current_weight,
                'avg_weight': current_weight,
                'weight_change_last_30_days_kg': weight_change_30d,
                'avg_water_liters': avg_water,
                'avg_sleep_hours': avg_sleep,
                'avg_calories': avg_calories,
                'workout_adherence_pct': workout_adherence,
                'meal_adherence_pct': meal_adherence,
                'workouts_done': workout_count_7d,
                'meals_followed_days': meals_count_7d,
                'logs_count_7d': total_7,
                'last_7_days': {
                    'logs_count': total_7,
                    'average_water_liters': avg_water,
                    'average_sleep_hours': avg_sleep,
                    'workout_adherence_pct': workout_adherence,
                    'meal_adherence_pct': meal_adherence,
                },
            }
        )


# ─── Plan confirmation ──────────────────────────────────────────────────────────


class ConfirmDietPlanView(APIView):
    """User accepts the active plan; strict daily enforcement begins."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            plan = DietPlan.objects.get(user=request.user, is_active=True)
        except DietPlan.DoesNotExist:
            return Response(
                {'detail': 'Faol parhez rejasi topilmadi. Avval reja yarating.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        plan.confirmed = True
        plan.confirmed_at = timezone.now()

        # Optional daily window for reminder distribution.
        try:
            wake = int(request.data.get('wake_hour', plan.wake_hour))
            sleep = int(request.data.get('sleep_hour', plan.sleep_hour))
            if 0 <= wake <= 23:
                plan.wake_hour = wake
            if 0 <= sleep <= 23:
                plan.sleep_hour = sleep
        except (ValueError, TypeError):
            pass

        plan.save(update_fields=['confirmed', 'confirmed_at', 'wake_hour', 'sleep_hour'])
        return Response(DietPlanSerializer(plan).data)


# ─── Food photo → calories ──────────────────────────────────────────────────────


def _resize_image(raw: bytes) -> tuple:
    """Downscale large photos to keep AI requests fast/cheap.
    Returns (bytes, mime_type). Falls back to the original on any error."""
    try:
        import io
        from PIL import Image

        img = Image.open(io.BytesIO(raw))
        img = img.convert('RGB')
        img.thumbnail((1024, 1024))
        out = io.BytesIO()
        img.save(out, format='JPEG', quality=85)
        return out.getvalue(), 'image/jpeg'
    except Exception:
        return raw, 'image/jpeg'


class FoodPhotoAnalyzeView(APIView):
    """Accept a food photo, estimate its calories via Gemini Vision, and log it."""
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        image = request.FILES.get('image')
        if image is None:
            return Response(
                {'error': 'Rasm yuborilmadi (image maydoni kerak).'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        raw = image.read()
        if not raw:
            return Response(
                {'error': 'Bo\'sh rasm fayli.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        data, mime = _resize_image(raw)
        result = analyze_food_image(data, mime)

        if not result.get('is_food'):
            return Response(
                {'is_food': False, 'error': result.get('error', 'Taom aniqlanmadi.')},
                status=status.HTTP_422_UNPROCESSABLE_ENTITY,
            )

        meal_type = request.data.get('meal_type', 'snack')
        if meal_type not in dict(FoodLog.MEAL_CHOICES):
            meal_type = 'snack'

        today = date.today()
        food = FoodLog.objects.create(
            user=request.user,
            date=today,
            meal_type=meal_type,
            name=result['name'],
            calories=result['calories'],
            protein_g=result['protein_g'],
            carbs_g=result['carbs_g'],
            fat_g=result['fat_g'],
            portion_note=result.get('portion_note', ''),
            recognized=True,
            confidence=result.get('confidence'),
        )

        # Roll the calories into today's DailyLog.
        log, _ = DailyLog.objects.get_or_create(user=request.user, date=today)
        log.calories_consumed = (log.calories_consumed or 0) + result['calories']
        log.save(update_fields=['calories_consumed'])

        return Response(
            {
                'food_log': FoodLogSerializer(food).data,
                'calories_consumed_today': log.calories_consumed,
            },
            status=status.HTTP_201_CREATED,
        )


class FoodLogListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        logs = FoodLog.objects.filter(user=request.user)
        date_param = request.query_params.get('date')
        if date_param:
            logs = logs.filter(date=date_param)
        return Response(FoodLogSerializer(logs, many=True).data)

    def post(self, request):
        """Manual food entry (no photo)."""
        serializer = FoodLogSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        food = serializer.save(user=request.user, recognized=False)

        log, _ = DailyLog.objects.get_or_create(user=request.user, date=food.date)
        log.calories_consumed = (log.calories_consumed or 0) + (food.calories or 0)
        log.save(update_fields=['calories_consumed'])
        return Response(FoodLogSerializer(food).data, status=status.HTTP_201_CREATED)


class FoodLogDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, pk):
        try:
            food = FoodLog.objects.get(user=request.user, id=pk)
        except FoodLog.DoesNotExist:
            return Response({'detail': 'Topilmadi'}, status=status.HTTP_404_NOT_FOUND)

        # Subtract its calories back from the day's total.
        try:
            log = DailyLog.objects.get(user=request.user, date=food.date)
            log.calories_consumed = max(0, (log.calories_consumed or 0) - (food.calories or 0))
            log.save(update_fields=['calories_consumed'])
        except DailyLog.DoesNotExist:
            pass

        food.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


# ─── Device registration (FCM) ──────────────────────────────────────────────────


class DeviceRegisterView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [JSONParser]

    def post(self, request):
        token = (request.data.get('token') or '').strip()
        if not token:
            return Response(
                {'error': 'token majburiy.'}, status=status.HTTP_400_BAD_REQUEST
            )
        platform = request.data.get('platform', 'android')

        device, _ = DeviceToken.objects.update_or_create(
            token=token,
            defaults={'user': request.user, 'platform': platform, 'is_active': True},
        )
        return Response(DeviceTokenSerializer(device).data, status=status.HTTP_200_OK)

    def delete(self, request):
        token = (request.data.get('token') or '').strip()
        if token:
            DeviceToken.objects.filter(user=request.user, token=token).update(is_active=False)
        return Response(status=status.HTTP_204_NO_CONTENT)


# ─── Daily enforcement status ───────────────────────────────────────────────────


def _compute_streak(user, today):
    """Consecutive days (ending today or yesterday) the user logged adherence."""
    logs = {
        log.date: log
        for log in DailyLog.objects.filter(user=user, date__lte=today)
    }
    streak = 0
    cursor = today
    # Allow today to be still-in-progress: start counting from yesterday if
    # today has no log yet.
    if today not in logs or not _day_is_adherent(logs.get(today)):
        cursor = today - timedelta(days=1)
    while cursor in logs and _day_is_adherent(logs[cursor]):
        streak += 1
        cursor -= timedelta(days=1)
    return streak


def _day_is_adherent(log):
    if log is None:
        return False
    return bool(log.meals_followed) or (log.calories_consumed or 0) > 0


class DailyStatusView(APIView):
    """Drives the mobile 'hard-forcing' gate: tells the app whether the user
    still owes actions today and should be blocked until they complete them."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        today = date.today()

        try:
            plan = DietPlan.objects.get(user=request.user, is_active=True)
        except DietPlan.DoesNotExist:
            return Response({
                'has_plan': False,
                'plan_confirmed': False,
                'locked': False,
                'actions_required': ['create_plan'],
                'message': 'Hali parhez rejasi yo\'q.',
            })

        if not plan.confirmed:
            return Response({
                'has_plan': True,
                'plan_confirmed': False,
                'locked': True,
                'actions_required': ['confirm_plan'],
                'message': 'Rejani tasdiqlang va boshlang.',
            })

        log = DailyLog.objects.filter(user=request.user, date=today).first()
        calories_consumed = (log.calories_consumed if log else 0) or 0
        water_liters = (log.water_liters if log else 0) or 0
        meals_followed = bool(log.meals_followed) if log else False
        workout_done = bool(log.workout_done) if log else False

        target_cal = plan.daily_calories or 0
        target_water = plan.daily_water_liters or 0

        actions = []
        if not meals_followed and calories_consumed == 0:
            actions.append('log_food')
        if target_water and water_liters < target_water:
            actions.append('drink_water')
        if not workout_done:
            actions.append('workout')

        return Response({
            'has_plan': True,
            'plan_confirmed': True,
            'locked': len(actions) > 0,
            'actions_required': actions,
            'streak': _compute_streak(request.user, today),
            'targets': {
                'calories': target_cal,
                'water_liters': target_water,
            },
            'today': {
                'calories_consumed': calories_consumed,
                'calories_remaining': max(0, target_cal - calories_consumed),
                'water_liters': water_liters,
                'water_remaining_liters': round(max(0, target_water - water_liters), 2),
                'meals_followed': meals_followed,
                'workout_done': workout_done,
            },
            'message': (
                'Bugun barcha vazifalar bajarildi! 💪'
                if not actions
                else 'Bugungi vazifalaringizni yakunlang.'
            ),
        })


# ─── Cron trigger (external scheduler) ──────────────────────────────────────────


class TriggerRemindersView(APIView):
    """HTTP endpoint an external cron service can hit to dispatch due
    reminders. Protected by a shared secret (CRON_SECRET env), passed either
    as ?key=... or the X-Cron-Key header."""
    permission_classes = [AllowAny]

    def _authorized(self, request):
        secret = os.environ.get('CRON_SECRET', '').strip()
        if not secret:
            return False
        provided = request.query_params.get('key') or request.headers.get('X-Cron-Key', '')
        return provided == secret

    def post(self, request):
        if not self._authorized(request):
            return Response({'detail': 'Forbidden'}, status=status.HTTP_403_FORBIDDEN)
        from .reminders import dispatch_due_reminders
        from . import fcm_service
        try:
            count = dispatch_due_reminders()
        except Exception as exc:  # noqa: BLE001 — surface config errors to the caller
            return Response(
                {'dispatched': 0, 'error': f'{type(exc).__name__}: {exc}'},
                status=status.HTTP_200_OK,
            )
        return Response({
            'dispatched': count,
            'fcm_configured': fcm_service.is_configured(),
        })

    def get(self, request):
        # Allow GET so simple cron services / uptime pingers can trigger it.
        return self.post(request)
