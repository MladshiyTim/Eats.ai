from django.db import models
from django.contrib.auth.models import User


class UserProfile(models.Model):
    GENDER_CHOICES = [
        ('M', 'Male'),
        ('F', 'Female'),
    ]
    ACTIVITY_CHOICES = [
        ('sedentary', 'Sedentary'),
        ('light', 'Light'),
        ('moderate', 'Moderate'),
        ('active', 'Active'),
        ('very_active', 'Very Active'),
    ]
    GOAL_CHOICES = [
        ('lose_weight', 'Lose Weight'),
        ('maintain', 'Maintain'),
        ('gain_weight', 'Gain Weight'),
        ('build_muscle', 'Build Muscle'),
    ]
    WORK_TYPE_CHOICES = [
        ('sedentary', 'Sedentary'),
        ('standing', 'Standing'),
        ('physical', 'Physical'),
        ('mixed', 'Mixed'),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    full_name = models.CharField(max_length=255, blank=True, default='')
    age = models.IntegerField(null=True, blank=True)
    gender = models.CharField(max_length=1, choices=GENDER_CHOICES, blank=True, default='')
    height_cm = models.FloatField(null=True, blank=True)
    weight_kg = models.FloatField(null=True, blank=True)
    target_weight_kg = models.FloatField(null=True, blank=True)
    activity_level = models.CharField(
        max_length=20, choices=ACTIVITY_CHOICES, blank=True, default=''
    )
    goal = models.CharField(max_length=20, choices=GOAL_CHOICES, blank=True, default='')
    work_type = models.CharField(
        max_length=20, choices=WORK_TYPE_CHOICES, blank=True, default=''
    )
    work_hours_per_day = models.FloatField(null=True, blank=True)
    sleep_hours_per_day = models.FloatField(null=True, blank=True)
    water_liters_per_day = models.FloatField(null=True, blank=True)
    does_sport = models.BooleanField(default=False)
    sport_type = models.CharField(max_length=255, blank=True, null=True)
    medical_conditions = models.TextField(blank=True, null=True)
    food_allergies = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user.username} - Profile"

    class Meta:
        verbose_name = 'User Profile'
        verbose_name_plural = 'User Profiles'


class DietPlan(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='diet_plans')
    duration_days = models.IntegerField(default=14)
    start_date = models.DateField()
    end_date = models.DateField()
    daily_calories = models.IntegerField()
    daily_protein_g = models.IntegerField()
    daily_carbs_g = models.IntegerField()
    daily_fat_g = models.IntegerField()
    daily_water_liters = models.FloatField()
    meal_plan = models.JSONField(default=list)
    sport_recommendation = models.TextField(blank=True, default='')
    general_advice = models.TextField(blank=True, default='')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - Diet Plan ({self.start_date})"

    class Meta:
        verbose_name = 'Diet Plan'
        verbose_name_plural = 'Diet Plans'
        ordering = ['-created_at']


class DailyLog(models.Model):
    MOOD_CHOICES = [
        ('good', 'Good'),
        ('normal', 'Normal'),
        ('bad', 'Bad'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='daily_logs')
    date = models.DateField()
    weight_kg = models.FloatField(null=True, blank=True)
    water_liters = models.FloatField(default=0.0)
    calories_consumed = models.IntegerField(null=True, blank=True)
    meals_followed = models.BooleanField(default=False)
    workout_done = models.BooleanField(default=False)
    water_target_met = models.BooleanField(default=False)
    sleep_hours = models.FloatField(null=True, blank=True)
    notes = models.TextField(blank=True, null=True)
    mood = models.CharField(max_length=10, choices=MOOD_CHOICES, blank=True, null=True)

    class Meta:
        verbose_name = 'Daily Log'
        verbose_name_plural = 'Daily Logs'
        unique_together = ('user', 'date')
        ordering = ['-date']

    def __str__(self):
        return f"{self.user.username} - Log ({self.date})"
