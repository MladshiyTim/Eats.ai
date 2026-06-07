from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from .views import (
    RegisterView,
    LoginView,
    MeView,
    ProfileView,
    GenerateDietPlanView,
    ActiveDietPlanView,
    DietPlanHistoryView,
    ConfirmDietPlanView,
    DailyLogListView,
    TodayLogView,
    DailyLogDetailView,
    StatsView,
    FoodPhotoAnalyzeView,
    FoodLogListView,
    FoodLogDetailView,
    DeviceRegisterView,
    DailyStatusView,
)

urlpatterns = [
    # Auth
    path('auth/register/', RegisterView.as_view(), name='auth-register'),
    path('auth/login/', LoginView.as_view(), name='auth-login'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='auth-refresh'),
    path('auth/me/', MeView.as_view(), name='auth-me'),

    # Profile
    path('profile/', ProfileView.as_view(), name='profile'),

    # Diet Plan
    path('diet-plan/generate/', GenerateDietPlanView.as_view(), name='diet-plan-generate'),
    path('diet-plan/active/', ActiveDietPlanView.as_view(), name='diet-plan-active'),
    path('diet-plan/history/', DietPlanHistoryView.as_view(), name='diet-plan-history'),
    path('diet-plan/confirm/', ConfirmDietPlanView.as_view(), name='diet-plan-confirm'),

    # Daily Log
    path('daily-log/', DailyLogListView.as_view(), name='daily-log-list'),
    path('daily-log/today/', TodayLogView.as_view(), name='daily-log-today'),
    path('daily-log/<str:key>/', DailyLogDetailView.as_view(), name='daily-log-detail'),

    # Food logging (photo → calories)
    path('food-log/analyze/', FoodPhotoAnalyzeView.as_view(), name='food-log-analyze'),
    path('food-log/', FoodLogListView.as_view(), name='food-log-list'),
    path('food-log/<int:pk>/', FoodLogDetailView.as_view(), name='food-log-detail'),

    # Devices (FCM push)
    path('devices/register/', DeviceRegisterView.as_view(), name='device-register'),

    # Daily enforcement status
    path('daily-status/', DailyStatusView.as_view(), name='daily-status'),

    # Stats
    path('stats/', StatsView.as_view(), name='stats'),
]
