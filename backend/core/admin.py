from django.contrib import admin
from .models import UserProfile, DietPlan, DailyLog


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ['user', 'full_name', 'age', 'gender', 'weight_kg', 'goal', 'activity_level', 'created_at']
    list_filter = ['gender', 'goal', 'activity_level', 'work_type']
    search_fields = ['user__username', 'user__email', 'full_name']
    readonly_fields = ['created_at', 'updated_at']


@admin.register(DietPlan)
class DietPlanAdmin(admin.ModelAdmin):
    list_display = ['user', 'duration_days', 'start_date', 'end_date', 'daily_calories', 'is_active', 'created_at']
    list_filter = ['is_active', 'duration_days']
    search_fields = ['user__username']
    readonly_fields = ['created_at']


@admin.register(DailyLog)
class DailyLogAdmin(admin.ModelAdmin):
    list_display = ['user', 'date', 'weight_kg', 'water_liters', 'calories_consumed', 'meals_followed', 'workout_done', 'water_target_met', 'mood']
    list_filter = ['meals_followed', 'workout_done', 'water_target_met', 'mood']
    search_fields = ['user__username']
    date_hierarchy = 'date'
