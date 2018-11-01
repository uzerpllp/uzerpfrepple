#!/usr/bin/python3
#
# Copyright (C) 2018 uzERP LLP
#
# This library is free software; you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero
# General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public
# License along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

import setuptools

with open("README.md", "r") as fh:
    long_description = fh.read()

setuptools.setup(
    name="uzerpfrepple",
    version="0.0.1",
    author="uzERP LLP",
    author_email="sblamey@uzerp.com",
    description="Frepple ERP connector for uzERP",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/uzerpllp/uzerpfrepple",
    packages=setuptools.find_packages(),
    classifiers=[
        "Programming Language :: Python :: 3",
        "Intended Audience :: Manufacturing",
        "License :: OSI Approved :: GNU Affero General Public License v3 or later (AGPLv3+)",
    ],
)
