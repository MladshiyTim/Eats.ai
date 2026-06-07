from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from .models import UserProfile, DietPlan, DailyLog, FoodLog, DeviceToken


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email']


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True, validators=[validate_password])
    password2 = serializers.CharField(write_only=True, required=True, label='Confirm Password')

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'password2']

    def validate(self, attrs):
        if attrs['password'] != attrs['password2']:
            raise serializers.ValidationError({'password': "Passwords do not match."})
        return attrs

    def create(self, validated_data):
        validated_data.pop('password2')
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            password=validated_data['password'],
        )
        # Create empty profile
        UserProfile.objects.create(user=user)
        return user


class UserProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = UserProfile
        fields = [
            'id', 'user', 'full_name', 'age', 'gender', 'height_cm', 'weight_kg',
            'target_weight_kg', 'activity_level', 'goal', 'work_type',
            'work_hours_per_day', 'sleep_hours_per_day', 'water_liters_per_day',
            'does_sport', 'sport_type', 'medical_conditions', 'food_allergies',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'user', 'created_at', 'updated_at']


class ProfileQuestionnaireSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = [
            'full_name', 'age', 'gender', 'height_cm', 'weight_kg',
            'target_weight_kg', 'activity_level', 'goal', 'work_type',
            'work_hours_per_day', 'sleep_hours_per_day', 'water_liters_per_day',
            'does_sport', 'sport_type', 'medical_conditions', 'food_allergies',
        ]


class DietPlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = DietPlan
        fields = [
            'id', 'user', 'duration_days', 'start_date', 'end_date',
            'daily_calories', 'daily_protein_g', 'daily_carbs_g', 'daily_fat_g',
            'daily_water_liters', 'meal_plan', 'sport_recommendation',
            'general_advice', 'is_active', 'created_at',
        ]
        read_only_fields = [
            'id', 'user', 'start_date', 'end_date', 'daily_calories',
            'daily_protein_g', 'daily_carbs_g', 'daily_fat_g', 'daily_water_liters',
            'meal_plan', 'sport_recommendation', 'general_advice', 'created_at',
        ]


class DailyLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = DailyLog
        fields = [
            'id', 'user', 'date', 'weight_kg', 'water_liters', 'calories_consumed',
            'meals_followed', 'workout_done', 'water_target_met', 'sleep_hours',
            'notes', 'mood',
        ]
        read_only_fields = ['id', 'user']


class FoodLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodLog
        fields = [
            'id', 'user', 'date', 'meal_type', 'name', 'calories',
            'protein_g', 'carbs_g', 'fat_g', 'portion_note', 'recognized',
            'confidence', 'created_at',
        ]
        read_only_fields = ['id', 'user', 'recognized', 'confidence', 'created_at']


class DeviceTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceToken
        fields = ['id', 'token', 'platform', 'is_active', 'updated_at']
        read_only_fields = ['id', 'is_active', 'updated_at']
