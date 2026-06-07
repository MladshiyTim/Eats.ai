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
    # User must explicitly confirm (accept) the plan before strict daily
    # enforcement kicks in.
    confirmed = models.BooleanField(default=False)
    confirmed_at = models.DateTimeField(null=True, blank=True)
    # Daily window (local hours) used to distribute water/meal reminders.
    wake_hour = models.IntegerField(default=7)
    sleep_hour = models.IntegerField(default=23)
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


class FoodLog(models.Model):
    """A single food item the user ate, recognized from a photo via AI
    (or entered manually). Counts toward the day's consumed calories."""

    MEAL_CHOICES = [
        ('breakfast', 'Breakfast'),
        ('lunch', 'Lunch'),
        ('dinner', 'Dinner'),
        ('snack', 'Snack'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='food_logs')
    date = models.DateField()
    meal_type = models.CharField(max_length=10, choices=MEAL_CHOICES, default='snack')
    name = models.CharField(max_length=255, default='')
    calories = models.IntegerField(default=0)
    protein_g = models.FloatField(default=0)
    carbs_g = models.FloatField(default=0)
    fat_g = models.FloatField(default=0)
    portion_note = models.CharField(max_length=255, blank=True, default='')
    # True if calories were estimated by the AI vision model from a photo.
    recognized = models.BooleanField(default=True)
    confidence = models.FloatField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Food Log'
        verbose_name_plural = 'Food Logs'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} - {self.name} ({self.calories} kcal)"


class DeviceToken(models.Model):
    """An FCM device registration token used to deliver push notifications."""

    PLATFORM_CHOICES = [
        ('android', 'Android'),
        ('ios', 'iOS'),
        ('web', 'Web'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='devices')
    token = models.CharField(max_length=512, unique=True)
    platform = models.CharField(max_length=10, choices=PLATFORM_CHOICES, default='android')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Device Token'
        verbose_name_plural = 'Device Tokens'
        ordering = ['-updated_at']

    def __str__(self):
        return f"{self.user.username} - {self.platform} device"


class ReminderLog(models.Model):
    """Records each reminder push sent so the scheduler never double-sends
    the same slot to the same user on the same day."""

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reminder_logs')
    date = models.DateField()
    # Slot key, e.g. 'water_3' or 'meal_lunch'.
    slot = models.CharField(max_length=40)
    sent_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Reminder Log'
        verbose_name_plural = 'Reminder Logs'
        unique_together = ('user', 'date', 'slot')
        ordering = ['-sent_at']

    def __str__(self):
        return f"{self.user.username} - {self.slot} ({self.date})"
