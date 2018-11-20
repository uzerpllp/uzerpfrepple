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

from passlib.hash import bcrypt
from freppledb.common.models import User
from uzerp.utils import getERPconnection

class uzerpAuthBackend:
    """
    uzERP Django authentication backend for frepple
    
    Authenticate user logins against the uzERP database.
    Users must be assigned to a uzERP role with the name 'frepple'
    and the user must have also been creted in the frepple application.
    """
    def authenticate(self, request, username=None, password=None):
        with getERPconnection() as erp_connection:
            cur = erp_connection.cursor()
            cur.execute("select * from frepple.uzerp_auth where username = %s", (username,))
            uzuser = cur.fetchone()
            if uzuser:
                authenticated = bcrypt.verify(password, uzuser[1])
                if authenticated:
                    return User.objects.get(username=username)

        return None

    def get_user(self, user_id):
        try:
            return User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return None