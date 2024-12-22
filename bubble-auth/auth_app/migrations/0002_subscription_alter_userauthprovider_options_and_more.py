# Generated by Django 5.1.2 on 2024-11-08 12:12

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('auth_app', '0001_initial'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='Subscription',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('plan', models.CharField(choices=[('free', 'Free'), ('premium', 'Premium'), ('pro', 'Pro')], default='free', max_length=50)),
                ('active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
            ],
        ),
        migrations.AlterModelOptions(
            name='userauthprovider',
            options={'verbose_name': 'User Auth Provider', 'verbose_name_plural': 'User Auth Providers'},
        ),
        migrations.RemoveField(
            model_name='userauthprovider',
            name='expires_in',
        ),
        migrations.AddField(
            model_name='userauthprovider',
            name='expires_at',
            field=models.DateTimeField(blank=True, null=True, verbose_name='Expires At'),
        ),
        migrations.AddField(
            model_name='userauthprovider',
            name='updated_at',
            field=models.DateTimeField(auto_now=True, verbose_name='Updated At'),
        ),
        migrations.AlterField(
            model_name='userauthprovider',
            name='access_token',
            field=models.TextField(verbose_name='Access Token'),
        ),
        migrations.AlterField(
            model_name='userauthprovider',
            name='created_at',
            field=models.DateTimeField(auto_now_add=True, verbose_name='Created At'),
        ),
        migrations.AlterField(
            model_name='userauthprovider',
            name='provider',
            field=models.CharField(choices=[('supabase', 'Supabase'), ('google', 'Google'), ('facebook', 'Facebook'), ('twitter', 'Twitter'), ('github', 'GitHub'), ('printful', 'Printful'), ('shopify', 'Shopify')], max_length=50, verbose_name='Provider'),
        ),
        migrations.AlterField(
            model_name='userauthprovider',
            name='provider_id',
            field=models.CharField(max_length=255, verbose_name='Provider ID'),
        ),
        migrations.AlterField(
            model_name='userauthprovider',
            name='refresh_token',
            field=models.TextField(blank=True, null=True, verbose_name='Refresh Token'),
        ),
        migrations.AlterField(
            model_name='userauthprovider',
            name='scope',
            field=models.TextField(blank=True, null=True, verbose_name='Scope'),
        ),
        migrations.AlterField(
            model_name='userauthprovider',
            name='user',
            field=models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='auth_providers', to=settings.AUTH_USER_MODEL),
        ),
        migrations.AddIndex(
            model_name='userauthprovider',
            index=models.Index(fields=['user', 'provider'], name='auth_app_us_user_id_718afb_idx'),
        ),
        migrations.AddIndex(
            model_name='userauthprovider',
            index=models.Index(fields=['provider', 'provider_id'], name='auth_app_us_provide_d19861_idx'),
        ),
        migrations.AddField(
            model_name='subscription',
            name='user',
            field=models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='subscription', to=settings.AUTH_USER_MODEL),
        ),
    ]
