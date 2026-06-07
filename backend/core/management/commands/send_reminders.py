"""
Send distributed water + meal reminders via FCM.

Run this periodically (e.g. every 30 minutes) from a Railway Cron job:
    python manage.py send_reminders

For each user with an active, confirmed plan it computes a set of reminder
slots spread across their waking hours, then pushes any slot that has just
become due and hasn't been sent yet today.
"""

from datetime import date

from django.core.management.base import BaseCommand
from django.utils import timezone

from core.models import DietPlan, DailyLog, ReminderLog
from core import fcm_service


# Tolerance window (minutes): a due slot is only sent if the scheduler fires
# within this many minutes of its scheduled time, so a missed cron run doesn't
# dump the whole day's backlog at once.
GRACE_MINUTES = 90


def _water_slots(plan):
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


def _meal_slots(plan):
    """Return [(slot_key, minute_of_day, label)] for meal reminders."""
    wake = max(0, plan.wake_hour)
    return [
        ('meal_breakfast', (wake + 1) * 60, 'Nonushta'),
        ('meal_lunch', 13 * 60, 'Tushlik'),
        ('meal_dinner', 19 * 60, 'Kechki ovqat'),
    ]


class Command(BaseCommand):
    help = 'Send due water/meal reminders to users via FCM.'

    def handle(self, *args, **options):
        if not fcm_service.is_configured():
            self.stdout.write(self.style.WARNING(
                'FCM not configured (set FIREBASE_CREDENTIALS_JSON). Skipping.'
            ))
            return

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

            # Water reminders — only while the target isn't met yet.
            if water_liters < target_water:
                remaining = round(max(0, target_water - water_liters), 1)
                for slot, minute, idx, count in _water_slots(plan):
                    if minute <= now_minute <= minute + GRACE_MINUTES:
                        due.append((
                            slot,
                            '💧 Suv ichish vaqti!',
                            f'Bugungi rejada yana {remaining} L suv qoldi '
                            f'({idx}/{count}). Hoziroq bir stakan ich’ing.',
                            {'type': 'water'},
                        ))

            # Meal reminders — only if meals not yet confirmed today.
            if not meals_followed:
                for slot, minute, label in _meal_slots(plan):
                    if minute <= now_minute <= minute + GRACE_MINUTES:
                        due.append((
                            slot,
                            f'🍽 {label} vaqti!',
                            'Rejangizdagi taomni iste’mol qiling va rasmga olib '
                            'kaloriyasini belgilang.',
                            {'type': 'meal'},
                        ))

            for slot, title, body, data in due:
                # Dedupe: skip if already sent this slot today.
                _, created = ReminderLog.objects.get_or_create(
                    user=user, date=today, slot=slot
                )
                if not created:
                    continue
                delivered = fcm_service.send_to_user(user, title, body, data)
                if delivered:
                    sent += 1
                else:
                    # No live device — drop the log so we retry once a device
                    # registers, rather than silently marking it sent forever.
                    ReminderLog.objects.filter(
                        user=user, date=today, slot=slot
                    ).delete()

        self.stdout.write(self.style.SUCCESS(f'Reminders dispatched: {sent}'))
