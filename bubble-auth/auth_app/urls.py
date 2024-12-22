from django.urls import path
from . import views
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from .api_views import UserDetailAPIView, UserAuthProvidersAPIView

urlpatterns = [
    # Authentication views
    path('login/', views.LoginView.as_view(), name='login'),
    path('logout/', views.LogoutView.as_view(), name='logout'),
    path('register/', views.RegisterView.as_view(), name='register'),
    path('dashboard/', views.DashboardView.as_view(), name='dashboard'),

    # Password management
    path('password/reset/', views.CustomPasswordResetView.as_view(), name='password_reset'),
    path('password/reset/confirm/<uidb64>/<token>/', views.CustomPasswordResetConfirmView.as_view(), name='password_reset_confirm'),
    path('password/change/', views.CustomPasswordChangeView.as_view(), name='password_change'),

    # Social authentication (assuming you'll implement these)
    path('social/login/<str:provider>/', views.SocialLoginView.as_view(), name='social_login'),
    path('social/callback/<str:provider>/', views.SocialCallbackView.as_view(), name='social_callback'),

    # User profile
    path('profile/', views.ProfileView.as_view(), name='profile'),
    path('profile/edit/', views.ProfileEditView.as_view(), name='profile_edit'),

    # API endpoints
    path('api/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('api/user/', UserDetailAPIView.as_view(), name='user_api'),
    path('api/providers/', UserAuthProvidersAPIView.as_view(), name='user_providers_api'),

    # Supabase specific (if needed)
    path('supabase/callback/', views.SupabaseCallbackView.as_view(), name='supabase_callback'),
]
