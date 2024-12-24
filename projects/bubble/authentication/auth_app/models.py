# auth_app/models.py

from django.db import models
from django.contrib.auth import get_user_model
from django.utils.translation import gettext_lazy as _

User = get_user_model()

class UserAuthProvider(models.Model):
    PROVIDER_CHOICES = [
        ('supabase', 'Supabase'),
        ('google', 'Google'),
        ('facebook', 'Facebook'),
        ('twitter', 'Twitter'),
        ('github', 'GitHub'),
        ('printful', 'Printful'),
        ('shopify', 'Shopify'),
        # Add more providers as needed
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='auth_providers')
    provider = models.CharField(_('Provider'), max_length=50, choices=PROVIDER_CHOICES)
    provider_id = models.CharField(_('Provider ID'), max_length=255)
    access_token = models.TextField(_('Access Token'))
    refresh_token = models.TextField(_('Refresh Token'), null=True, blank=True)
    expires_at = models.DateTimeField(_('Expires At'), null=True, blank=True)
    scope = models.TextField(_('Scope'), null=True, blank=True)
    created_at = models.DateTimeField(_('Created At'), auto_now_add=True)
    updated_at = models.DateTimeField(_('Updated At'), auto_now=True)

    class Meta:
        verbose_name = _('User Auth Provider')
        verbose_name_plural = _('User Auth Providers')
        unique_together = ('user', 'provider')
        indexes = [
            models.Index(fields=['user', 'provider']),
            models.Index(fields=['provider', 'provider_id']),
        ]

    def __str__(self):
        return f"{self.user.username} - {self.get_provider_display()}"

    @property
    def is_expired(self):
        from django.utils import timezone
        return self.expires_at is not None and self.expires_at <= timezone.now()


class Subscription(models.Model):
    PLAN_CHOICES = [
        ('free', 'Free'),
        ('premium', 'Premium'),
        ('pro', 'Pro'),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='subscription')
    plan = models.CharField(max_length=50, choices=PLAN_CHOICES, default='free')
    active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.plan}"
