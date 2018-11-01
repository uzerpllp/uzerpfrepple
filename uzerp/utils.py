#
# Copyright (C) 2017 by frePPLe bvba
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

import psycopg2
from django.conf import settings

def getERPconnection():
  '''
  '''
  conn = psycopg2.connect(dbname=settings.UZERP_DB.get('NAME'),
                          user=settings.UZERP_DB.get('USER'),
                          password=settings.UZERP_DB.get('PASSWORD'),
                          host=settings.UZERP_DB.get('HOST'))
  return conn
