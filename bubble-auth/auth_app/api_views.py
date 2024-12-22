from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from rest_framework.permissions import IsAuthenticated
from rest_framework import generics
from django.contrib.auth import get_user_model
from rest_framework.response import Response
from rest_framework import status
from rest_framework.views import APIView

User = get_user_model()

class UserDetailAPIView(APIView):
    """
    API endpoint that retrieves the authenticated user's information.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        data = {
            'username': user.username,
            'email': user.email,
            'first_name': user.first_name,
            'last_name': user.last_name,
            # Add other fields as needed
        }
        return Response(data, status=status.HTTP_200_OK)

class UserAuthProvidersAPIView(APIView):
    """
    API endpoint that lists the user's authentication providers.
    (Placeholder for future implementation)
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Implement logic to retrieve user auth providers if applicable
        # For example, list connected social accounts
        providers = []  # Replace with actual logic
        return Response({'providers': providers}, status=status.HTTP_200_OK)
