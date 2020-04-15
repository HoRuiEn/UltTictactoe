import Cython.Compiler.Options
Cython.Compiler.Options.annotate = True

from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize
import numpy

ext_modules = [
    Extension(
        "tictactoe_destroyer",
        ["tictactoe_destroyer.pyx"],
        extra_compile_args=['/openmp'],
        extra_link_args=['/openmp'],
    )
]

setup(
  name = 'MyProject',
  ext_modules = cythonize(ext_modules, annotate=True),
  include_dirs=[numpy.get_include()]
)
"""
from setuptools import setup, find_packages
from setuptools.extension import Extension
from Cython.Build import cythonize

extensions = [
    Extension(
        "myPackage.myModule",
        ["myPackage/myModule.pyx"],
        include_dirs=['/some/path/to/include/'], # not needed for fftw unless it is installed in an unusual place
        libraries=['fftw3', 'fftw3f', 'fftw3l', 'fftw3_threads', 'fftw3f_threads', 'fftw3l_threads'],
        library_dirs=['/some/path/to/include/'], # not needed for fftw unless it is installed in an unusual place
    ),
]

setup(
    name = "myPackage",
    packages = find_packages(),
    ext_modules = cythonize(extensions)
)
"""
