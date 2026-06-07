from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='dailylog',
            name='calories_consumed',
            field=models.IntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='dailylog',
            name='water_target_met',
            field=models.BooleanField(default=False),
        ),
    ]
