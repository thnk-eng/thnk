# auth_app/tests.py

from django.urls import reverse
from rest_framework.test import APITestCase
from rest_framework import status
from django.contrib.auth import get_user_model
from .models import Subscription

User = get_user_model()

class SubscriptionTests(APITestCase):

    def setUp(self):
        self.user = User.objects.create_user(username='testuser', email='test@example.com', password='testpass123')
        self.token_url = reverse('token_obtain_pair')
        self.subscription_url = reverse('get_subscription')
        self.update_subscription_url = reverse('update_subscription')

    def authenticate(self):
        response = self.client.post(self.token_url, {'username': 'testuser', 'password': 'testpass123'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.access_token = response.data['access']
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + self.access_token)

    def test_get_subscription_not_exists(self):
        self.authenticate()
        response = self.client.get(self.subscription_url, format='json')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(response.data['error'], 'Subscription not found.')

    def test_create_and_get_subscription(self):
        self.authenticate()
        # Update subscription to create it
        response = self.client.post(self.update_subscription_url, {'plan': 'premium'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['subscription']['plan'], 'premium')

        # Retrieve the subscription
        response = self.client.get(self.subscription_url, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['plan'], 'premium')

    def test_update_subscription_invalid_plan(self):
        self.authenticate()
        response = self.client.post(self.update_subscription_url, {'plan': 'invalid_plan'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data['error'], 'Invalid plan selected.')

    def test_update_subscription_valid_plan(self):
        self.authenticate()
        response = self.client.post(self.update_subscription_url, {'plan': 'pro'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['subscription']['plan'], 'pro')
