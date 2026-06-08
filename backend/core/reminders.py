"""
Reminder dispatch logic, shared by the `send_reminders` management command
and the HTTP trigger endpoint (so an external cron can fire it via a URL).
"""

from django.utils import timezone

from .models import DietPlan, DailyLog, ReminderLog
from . import fcm_service


# Tolerance window (minutes): a due slot is only sent if the scheduler fires
# within this many minutes of its scheduled time, so a missed run doesn't dump
# the whole day's backlog at once.
GRACE_MINUTES = 90


def water_slots(plan):
    """Return [(slot_key, minute_of_day, index, count)] for water reminders."""
    target = plan.daily_water_liters or 0
    if target <= 0:
        return []
    count = max(4, min(10, round(target / 0.3)))
    start = max(0, plan.wake_hour) * 60
    end = min(23, plan.sleep_hour - 1) * 60
    if end <= start:
        end = start + 60
    step = (end - start) / max(1, count - 1)
    slots = []
    for i in range(count):
        minute = int(round(start + i * step))
        slots.append((f'water_{i + 1}', minute, i + 1, count))
    return slots


def meal_slots(plan):
    """Return [(slot_key, minute_of_day, label)] for meal reminders."""
    wake = max(0, plan.wake_hour)
    return [
        ('meal_breakfast', (wake + 1) * 60, 'Nonushta'),
        ('meal_lunch', 13 * 60, 'Tushlik'),
        ('meal_dinner', 19 * 60, 'Kechki ovqat'),
    ]


def dispatch_due_reminders():
    """Send any reminder slots that have just become due. Returns the number
    of users a push was delivered to. No-op (returns 0) if FCM isn't set up."""
    if not fcm_service.is_configured():
        return 0

    now = timezone.localtime()
    today = now.date()
    now_minute = now.hour * 60 + now.minute

    sent = 0
    plans = DietPlan.objects.filter(is_active=True, confirmed=True).select_related('user')
    for plan in plans:
        user = plan.user
        log = DailyLog.objects.filter(user=user, date=today).first()
        water_liters = (log.water_liters if log else 0) or 0
        meals_followed = bool(log.meals_followed) if log else False
        target_water = plan.daily_water_liters or 0

        due = []

        if water_liters < target_water:
            remaining = round(max(0, target_water - water_liters), 1)
            for slot, minute, idx, count in water_slots(plan):
                if minute <= now_minute <= minute + GRACE_MINUTES:
                    due.append((
                        slot,
                        '💧 Suv ichish vaqti!',
                        f'Bugungi rejada yana {remaining} L suv qoldi '
                        f'({idx}/{count}). Hoziroq bir stakan ich’ing.',
                        {'type': 'water'},
                    ))

        if not meals_followed:
            for slot, minute, label in meal_slots(plan):
                if minute <= now_minute <= minute + GRACE_MINUTES:
                    due.append((
                        slot,
                        f'🍽 {label} vaqti!',
                        'Rejangizdagi taomni iste’mol qiling va rasmga olib '
                        'kaloriyasini belgilang.',
                        {'type': 'meal'},
                    ))

        for slot, title, body, data in due:
            _, created = ReminderLog.objects.get_or_create(
                user=user, date=today, slot=slot
            )
            if not created:
                continue
            delivered = fcm_service.send_to_user(user, title, body, data)
            if delivered:
                sent += 1
            else:
                ReminderLog.objects.filter(user=user, date=today, slot=slot).delete()

    return sent
