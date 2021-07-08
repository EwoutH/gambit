from setuptools import setup, Extension
from Cython.Build import cythonize



setup(
    name="gambit2",
    version="16.0.1",
    description="Software tools for game theory",
    author="Theodore Turocy",
    author_email="ted.turocy@gmail.com",
    url="http://www.gambit-project.org",
    packages=["gambit2"],
)

