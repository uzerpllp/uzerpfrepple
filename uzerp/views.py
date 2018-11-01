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

import base64
import email
import json
import jwt
import time
from urllib.request import urlopen, HTTPError, Request
from xml.sax.saxutils import quoteattr

from django.conf import settings
from django.contrib.auth.decorators import login_required
from django.http import HttpResponse, HttpResponseServerError
from django.utils.translation import ugettext_lazy as _
from django.views.decorators.csrf import csrf_protect
from django.db import connection

from freppledb.input.models import PurchaseOrder, DistributionOrder, OperationPlan
from freppledb.common.models import Parameter

import logging
logger = logging.getLogger(__name__)

from .utils import getERPconnection

@login_required
@csrf_protect
def Upload(request):
  """
  Export selected Manufacturing Orders to uzERP as Work Orders

  Only selected operationplan entries with type 'routing'
  will be exported as Work Orders
  """
  try:
    data = json.loads(request.body.decode('utf-8'))
    print(data)
    print('**implemented in uzerpfrepple/uzerp/views.py**')

    with getERPconnection() as erp_connection:
      for order in data:
        if order['type'] == 'MO' and order['operation__type'] == 'routing':
          with erp_connection.cursor() as cursor_erp:
            # Get the next work order number
            cursor_erp.execute('''
              SELECT max(wo_number)+1 FROM public.mf_workorders WHERE usercompanyid=1;
            ''')
            wo_number = cursor_erp.fetchone()
            
            # Create the work order record
            create_wo = "INSERT INTO public.mf_workorders(\
              wo_number, order_qty, required_by, status, stitem_id, usercompanyid, documentation, start_date) \
              VALUES (%s, %s, %s, 'N',	(select id from st_items where item_code = %s),	1, %s, %s) RETURNING id;"
            wo_data = (wo_number, float(order['quantity']), order['enddate'], order['operation__item__name'], 'a:2:{i:0;s:2:"26";i:1;s:1:"9";}', order['startdate'])
            cursor_erp.execute(create_wo, wo_data)
            wo_id = cursor_erp.fetchone()

            # Copy the product structure items (BOM) for the work order
            copy_structure = "INSERT INTO public.mf_wo_structures(\
              line_no, qty, uom_id, remarks, waste_pc, work_order_id, ststructure_id, usercompanyid)\
              (select line_no, qty, uom_id, remarks, waste_pc, %s, ststructure_id, 1 from mf_structures where stitem_id = (select id from st_items where item_code = %s) and (start_date <= now() and (end_date >= now() or end_date is null)));"
            structure_data = (wo_id, order['operation__item__name'])
            cursor_erp.execute(copy_structure, structure_data)

            # Update the operationplan entry to approved status
            fr_object = OperationPlan.objects.get(pk=order['id'])
            print(fr_object.status)
            fr_object.status = 'approved'
            fr_object.save()
        
        elif order['type'] == 'PO':
          with erp_connection.cursor() as cursor_erp:
            create_po = "INSERT INTO public.po_planned(item_code, supplier_name, order_date, delivery_date, qty, product_group_desc, description)\
              VALUES (%s, %s, %s, %s, %s, %s, %s)"
            po_data = (order['item'], order['supplier'], order['startdate'], order['enddate'], order['quantity'], order['item__subcategory'], order['item__description'])
            cursor_erp.execute(create_po, po_data)

            # Update the operationplan entry to approved status
            fr_object = OperationPlan.objects.get(pk=order['id'])
            print(fr_object.status)
            fr_object.status = 'approved'
            fr_object.save()

    return HttpResponse("OK")
  except Exception as e:
    logger.error("Problem with ERP export: %s" % e)
    return HttpResponseServerError("Problem with ERP export")
