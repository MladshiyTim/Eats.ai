"""
Send distributed water + meal reminders via FCM.

Run periodically (e.g. every 30 minutes), either from a Railway Cron job:
    python manage.py send_reminders
or via the HTTP trigger endpoint /api/cron/send-reminders/ hit by an external
cron service.
"""

from django.core.management.base import BaseCommand

from core.reminders import dispatch_due_reminders
from core import fcm_service


class Command(BaseCommand):
    help = 'Send due water/meal reminders to users via FCM.'

    def handle(self, *args, **options):
        if not fcm_service.is_configured():
            self.stdout.write(self.style.WARNING(
                'FCM not configured (set FIREBASE_CREDENTIALS_JSON). Skipping.'
            ))
            return
        sent = dispatch_due_reminders()
        self.stdout.write(self.style.SUCCESS(f'Reminders dispatched: {sent}'))
