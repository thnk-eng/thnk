import os
from django.shortcuts import render, redirect
from django.contrib.auth import login, logout, get_user_model, authenticate
from django.contrib import messages
from django.views import View
from django.contrib.auth.mixins import LoginRequiredMixin
from django.contrib.auth.views import (
    PasswordResetView as DjangoPasswordResetView,
    PasswordResetConfirmView as DjangoPasswordResetConfirmView,
    PasswordChangeView as DjangoPasswordChangeView,
)

from bubble_auth import settings
from .forms import RegistrationForm, ProfileEditForm

# Initialize Supabase client only if it's enabled
if settings.USE_SUPABASE:
    from supabase import create_client, Client

    SUPABASE_URL = os.getenv('SUPABASE_URL')
    SUPABASE_KEY = os.getenv('SUPABASE_KEY')

    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY) if SUPABASE_URL and SUPABASE_KEY else None

    if not supabase:
        raise EnvironmentError("Supabase URL or Key is missing in environment variables.")
else:
    supabase = None

User = get_user_model()

class LoginView(View):
    """
    Handles user login using Django's built-in authentication.
    """

    def get(self, request):
        return render(request, 'auth_app/login.html')

    def post(self, request):
        email = request.POST.get('email')
        password = request.POST.get('password')
        remember_me = request.POST.get('remember_me')

        user = authenticate(request, username=email, password=password)
        if user:
            login(request, user)

            # Session expiry settings
            if remember_me:
                request.session.set_expiry(1209600)  # 2 weeks
            else:
                request.session.set_expiry(0)  # Session expires on browser close

            return redirect('dashboard')
        else:
            messages.error(request, 'Invalid credentials')
            return redirect('login')



class LogoutView(View):
    """
    Handles user logout.
    """

    def get(self, request):
        try:
            logout(request)
            messages.success(request, 'You have been logged out.')
        except Exception as e:
            messages.error(request, f'Logout failed: {str(e)}')

        return redirect('login')



class RegisterView(View):
    """
    Handles user registration using Django's built-in authentication.
    """

    def get(self, request):
        form = RegistrationForm()
        return render(request, 'auth_app/register.html', {'form': form})

    def post(self, request):
        form = RegistrationForm(request.POST)
        if form.is_valid():
            email = form.cleaned_data['email']
            password = form.cleaned_data['password']

            # Use Django's built-in registration
            user = form.save(commit=False)
            user.set_password(password)
            user.save()
            messages.success(request, 'Registration successful. You can now log in.')
            return redirect('login')

        return render(request, 'auth_app/register.html', {'form': form})


class DashboardView(LoginRequiredMixin, View):
    """
    User dashboard view.
    """

    def get(self, request):
        return render(request, 'auth_app/dashboard.html')


class CustomPasswordResetView(DjangoPasswordResetView):
    template_name = 'auth_app/password_reset.html'
    email_template_name = 'auth_app/password_reset_email.html'
    success_url = '/login/'


class CustomPasswordResetConfirmView(DjangoPasswordResetConfirmView):
    template_name = 'auth_app/password_reset_confirm.html'
    success_url = '/login/'


class CustomPasswordChangeView(LoginRequiredMixin, DjangoPasswordChangeView):
    template_name = 'auth_app/password_change.html'
    success_url = '/dashboard/'


class SocialLoginView(View):
    """
    Handles social login initiation.
    """

    def get(self, request, provider):
        return render(request, 'auth_app/social_login.html', {'provider': provider})


class SocialCallbackView(View):
    """
    Handles social login callback.
    """

    def get(self, request, provider):
        return render(request, 'auth_app/social_callback.html', {'provider': provider})


class ProfileView(LoginRequiredMixin, View):
    """
    User profile view.
    """

    def get(self, request):
        return render(request, 'auth_app/profile.html', {'user': request.user})


class ProfileEditView(LoginRequiredMixin, View):
    """
    Handles editing of user profiles.
    """

    def get(self, request):
        form = ProfileEditForm(instance=request.user)
        return render(request, 'auth_app/profile_edit.html', {'form': form})

    def post(self, request):
        form = ProfileEditForm(request.POST, instance=request.user)
        if form.is_valid():
            form.save()
            messages.success(request, 'Profile updated successfully.')
            return redirect('profile')
        return render(request, 'auth_app/profile_edit.html', {'form': form})


class SupabaseCallbackView(View):
    """
    Handles Supabase-specific callbacks if needed.
    """

    def get(self, request):
        return render(request, 'auth_app/supabase_callback.html')
