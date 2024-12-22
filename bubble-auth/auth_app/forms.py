# forms.py
from django import forms
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password

User = get_user_model()

class RegistrationForm(forms.ModelForm):
    """
    Enhanced registration form with proper styling and validation
    """
    email = forms.EmailField(
        widget=forms.EmailInput(attrs={
            'class': 'w-full py-3 px-4 border border-gray-300 rounded-lg text-sm focus:border-slate-300 focus:ring-slate-500',
            'placeholder': 'you@example.com',
        })
    )

    password = forms.CharField(
        widget=forms.PasswordInput(attrs={
            'class': 'w-full py-3 px-4 border border-gray-300 rounded-lg text-sm focus:border-slate-300 focus:ring-slate-500',
            'placeholder': 'Create a password',
        }),
        validators=[validate_password]
    )

    password_confirm = forms.CharField(
        widget=forms.PasswordInput(attrs={
            'class': 'w-full py-3 px-4 border border-gray-300 rounded-lg text-sm focus:border-slate-300 focus:ring-slate-500',
            'placeholder': 'Confirm your password',
        })
    )

    class Meta:
        model = User
        fields = ('email',)

    def clean_email(self):
        email = self.cleaned_data.get('email')
        if User.objects.filter(email=email).exists():
            raise forms.ValidationError("This email is already registered.")
        return email

    def clean(self):
        cleaned_data = super().clean()
        password = cleaned_data.get('password')
        password_confirm = cleaned_data.get('password_confirm')

        if password and password_confirm:
            if password != password_confirm:
                self.add_error('password_confirm', "Passwords don't match")

        return cleaned_data

    def save(self, commit=True):
        user = super().save(commit=False)
        user.username = self.cleaned_data['email']
        user.email = self.cleaned_data['email']
        user.set_password(self.cleaned_data['password'])
        if commit:
            user.save()
        return user


class ProfileEditForm(forms.ModelForm):
    """
    Form for editing user profile details.
    """

    class Meta:
        model = User
        fields = ['email', 'first_name', 'last_name']  # Adjust fields based on your User model

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        # Apply CSS classes to form fields for better styling
        for field in self.fields.values():
            field.widget.attrs.update({'class': 'form-control'})
