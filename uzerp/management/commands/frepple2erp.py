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

import datetime

from django.core.management.base import BaseCommand, CommandError
from django.conf import settings
from django.db import DEFAULT_DB_ALIAS, connections
from django.template import Template, RequestContext
from django.utils.translation import ugettext_lazy as _

from freppledb import VERSION
from freppledb.common.models import User
from freppledb.execute.models import Task
from freppledb.input.models import PurchaseOrder, DistributionOrder, OperationPlan

from ...utils import getERPconnection


class Command(BaseCommand):
  help = '''
  Update the ERP system with frePPLe planning information.
  '''
  # For the display in the execution screen
  title = _('Export data to %(erp)s') % {'erp': 'uzERP'}

  # For the display in the execution screen
  index = 1500

  requires_system_checks = False

  def get_version(self):
    return VERSION


  def add_arguments(self, parser):
    parser.add_argument(
      '--user', help='User running the command'
      )
    parser.add_argument(
      '--database', default=DEFAULT_DB_ALIAS,
      help='Nominates the frePPLe database to load'
      )
    parser.add_argument(
      '--task', type=int,
      help='Task identifier (generated automatically if not provided)'
      )


  @ staticmethod
  def getHTML(request):
    if 'uzerp' in settings.INSTALLED_APPS:
      context = RequestContext(request)

      template = Template('''
        {% load i18n %}
        <form role="form" method="post" action="{{request.prefix}}/execute/launch/frepple2erp/">{% csrf_token %}
        <table>
          <tr>
            <td style="vertical-align:top; padding: 15px">
               <button  class="btn btn-primary"  type="submit" value="{% trans "launch"|capfirst %}">{% trans "launch"|capfirst %}</button>
            </td>
            <td  style="padding: 0px 15px;">{% trans "Export erp data to uzERP." %}
            </td>
          </tr>
        </table>
        </form>
      ''')
      return template.render(context)
    else:
      return None


  def handle(self, **options):
    '''
    Uploads approved operationplans to the ERP system.
    '''

    # Select the correct frePPLe scenario database
    self.database = options['database']
    if self.database not in settings.DATABASES.keys():
      raise CommandError("No database settings known for '%s'" % self.database)
    self.cursor_frepple = connections[self.database].cursor()

    # FrePPle user running this task
    if options['user']:
      try:
        self.user = User.objects.all().using(self.database).get(username=options['user'])
      except:
        raise CommandError("User '%s' not found" % options['user'] )
    else:
      self.user = None

    # FrePPLe task identifier
    if options['task']:
      try:
        self.task = Task.objects.all().using(self.database).get(pk=options['task'])
      except:
        raise CommandError("Task identifier not found")
      if self.task.started or self.task.finished or self.task.status != "Waiting" or self.task.name != 'frepple2erp':
        raise CommandError("Invalid task identifier")
    else:
      now = datetime.datetime.now()
      self.task = Task(name='frepple2erp', submitted=now, started=now, status='0%', user=self.user)
    self.task.save(using=self.database)

    try:
      # Open database connection
      print("Connecting to the uzERP database")
      with getERPconnection() as erp_connection:
        self.cursor_erp = erp_connection.cursor()
        try:
          self.extractPurchaseOrders()
          self.task.status = '50%'
          self.task.save(using=self.database)

          #self.extractDistributionOrders()
          #self.task.status = '66%'
          #self.task.save(using=self.database)

          self.extractManufacturingOrders()
          self.task.status = '100%'
          self.task.save(using=self.database)
          
          # Optional extra planning output the ERP might be interested in:
          #  - planned delivery date of sales orders
          #  - safety stock (Enterprise Edition only)
          #  - reorder quantities (Enterprise Edition only)
          #  - forecast (Enterprise Edition only)
          self.task.status = 'Done'
        finally:
          self.cursor_erp.close()
    except Exception as e:
      self.task.status = 'Failed'
      self.task.message = 'Failed: %s' % e
    self.task.finished = datetime.datetime.now()
    self.task.save(using=self.database)
    self.cursor_frepple.close()


  def extractPurchaseOrders(self):
    '''
    Export purchase orders from frePPle.
    '''
    print("Start exporting purchase orders to uzERP")

    uz_settings = settings.UZERP_SETTINGS.get('EXPORT', None)

    if uz_settings is None:
      print("No export settings found")
      return

    release_fence = datetime.datetime.now().date() + datetime.timedelta(days=uz_settings['po_release_fence'])

    self.cursor_frepple.execute('''
      select reference, item_id, supplier_id, startdate, enddate, quantity, item.subcategory, description
      from operationplan
      inner join item on item_id = item.name
      where type = 'PO' and status = 'proposed' and startdate <= %s
      ''', (release_fence,))

    po_export = [ i for i in self.cursor_frepple.fetchall()]
    po_data = [el[1:] for el in (tuple(x) for x in po_export)]

    if len(po_export) == 0:
      print("No planned purchases found in frePPLe with matching criteria.")
      return

    with self.cursor_erp as cursor_erp:
      create_po = "INSERT INTO public.po_planned(item_code, supplier_name, order_date, delivery_date, qty, product_group_desc, description)\
        VALUES (%s, %s, %s, %s, %s, %s, %s)"
      cursor_erp.executemany(create_po, po_data)

      # Update the operationplan entry to approved status
      print("Start updating operationplan status on type 'PO'")
      for order in po_export:
        fr_object = OperationPlan.objects.get(pk=order[0])
        print(fr_object.status)
        fr_object.status = 'approved'
        fr_object.save()


  def extractManufacturingOrders(self):
    '''
    Export manufacturing orders to uzERP.
    '''
    print("Start exporting manufacturing orders")

    uz_settings = settings.UZERP_SETTINGS.get('EXPORT', None)

    if uz_settings is None:
      print("No export settings found")
      return

    release_fence = datetime.datetime.now().date() + datetime.timedelta(days=uz_settings['wo_release_fence'])

    self.cursor_frepple.execute('''
      select reference, quantity, enddate, item_id, startdate
      from operationplan
      where type = 'MO' and item_id is not NULL and status = 'proposed' and startdate <= %s
      order by startdate
      ''', (release_fence,))

    mo_export = [ i for i in self.cursor_frepple.fetchall()]

    if len(mo_export) == 0:
      print("No planned manufacturing orders found in frePPLe with matching criteria.")
      return

    with self.cursor_erp as cursor_erp:
      # Get the next work order number
      cursor_erp.execute('''
        SELECT max(wo_number)+1 FROM public.mf_workorders WHERE usercompanyid=1;
      ''')
      wo_number = cursor_erp.fetchone()
      wo_number = wo_number[0]

      for morder in mo_export:
        # Create the work order record
        create_wo = "INSERT INTO public.mf_workorders(\
          wo_number, order_qty, required_by, status, stitem_id, usercompanyid, documentation, start_date) \
          VALUES (%s, %s, %s, 'N',	(select id from st_items where item_code = %s),	1, %s, %s) RETURNING id;"
        wo_data = (wo_number, float(morder[1]), morder[2], morder[3], uz_settings['wo_documentation_string'], morder[4])
        cursor_erp.execute(create_wo, wo_data)
        wo_id = cursor_erp.fetchone()

        # Copy the product structure items (BOM) for the work order
        copy_structure = "INSERT INTO public.mf_wo_structures(\
          line_no, qty, uom_id, remarks, waste_pc, work_order_id, ststructure_id, usercompanyid)\
          (select line_no, qty, uom_id, remarks, waste_pc, %s, ststructure_id, 1 from mf_structures where stitem_id = (select id from st_items where item_code = %s) and (start_date <= now() and (end_date >= now() or end_date is null)));"
        structure_data = (wo_id, morder[3])
        cursor_erp.execute(copy_structure, structure_data)

        # Update the operationplan entry to approved status
        fr_object = OperationPlan.objects.get(pk=morder[0])
        print(fr_object.status)
        fr_object.status = 'approved'
        fr_object.save()

        wo_number = wo_number + 1


  def extractDistributionOrders(self):
    '''
    Not implemented
    '''
    pass
