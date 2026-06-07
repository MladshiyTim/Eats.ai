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
    DailyLogListView,
    TodayLogView,
    DailyLogDetailView,
    StatsView,
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

    # Daily Log
    path('daily-log/', DailyLogListView.as_view(), name='daily-log-list'),
    path('daily-log/today/', TodayLogView.as_view(), name='daily-log-today'),
    path('daily-log/<str:key>/', DailyLogDetailView.as_view(), name='daily-log-detail'),

    # Stats
    path('stats/', StatsView.as_view(), name='stats'),
]
