from setuptools import setup, find_packages

setup(
    name="bubble_motor",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[
        "fastapi>=0.68.0",
        "uvicorn>=0.15.0",
        "pydantic>=1.8.0",
        "python-multipart>=0.0.5",
        "aiohttp>=3.8.0",
        "requests>=2.26.0",
        "typing-extensions>=4.0.0",
    ],
    author="Your Name",
    author_email="your.email@example.com",
    description="A scalable API serving framework",
    long_description=open("README.md").read(),
    long_description_content_type="text/markdown",
    url="https://github.com/yourusername/bubble_motor",
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3.8",
    ],
    python_requires=">=3.8",
)
