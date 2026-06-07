from django.contrib import admin
from .models import UserProfile, DietPlan, DailyLog, FoodLog, DeviceToken, ReminderLog


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


@admin.register(FoodLog)
class FoodLogAdmin(admin.ModelAdmin):
    list_display = ['user', 'date', 'meal_type', 'name', 'calories', 'recognized', 'confidence', 'created_at']
    list_filter = ['meal_type', 'recognized']
    search_fields = ['user__username', 'name']
    date_hierarchy = 'date'


@admin.register(DeviceToken)
class DeviceTokenAdmin(admin.ModelAdmin):
    list_display = ['user', 'platform', 'is_active', 'updated_at']
    list_filter = ['platform', 'is_active']
    search_fields = ['user__username', 'token']


@admin.register(ReminderLog)
class ReminderLogAdmin(admin.ModelAdmin):
    list_display = ['user', 'date', 'slot', 'sent_at']
    list_filter = ['slot']
    search_fields = ['user__username']
    date_hierarchy = 'date'
