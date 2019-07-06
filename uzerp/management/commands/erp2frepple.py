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

import csv
from datetime import datetime
import os

from django.core.management.base import BaseCommand, CommandError
from django.conf import settings
from django.db import DEFAULT_DB_ALIAS
from django.template import Template, RequestContext
from django.utils.translation import ugettext_lazy as _

from freppledb import VERSION
from freppledb.common.models import User
from freppledb.execute.models import Task

from ...utils import getERPconnection


class Command(BaseCommand):
  help = '''
  Extract a set of flat files from an ERP system.
  '''

  ext = 'csv'

  # For the display in the execution screen
  title = _('Import data from %(erp)s') % {'erp': 'uzERP'}
  index = 1400

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
        <form role="form" method="post" action="{{request.prefix}}/execute/launch/erp2frepple/">{% csrf_token %}
        <table>
          <tr>
            <td style="vertical-align:top; padding: 15px">
               <button  class="btn btn-primary"  type="submit" value="{% trans "launch"|capfirst %}">{% trans "launch"|capfirst %}</button>
            </td>
            <td  style="padding: 0px 15px;">{% trans "Import erp data into frePPLe." %}
            </td>
          </tr>
        </table>
        </form>
      ''')
      return template.render(context)
    else:
      return None


  def handle(self, **options):

    # Select the correct frePPLe scenario database
    self.database = options['database']
    if self.database not in settings.DATABASES.keys():
      raise CommandError("No database settings known for '%s'" % self.database)

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
      if self.task.started or self.task.finished or self.task.status != "Waiting" or self.task.name != 'erp2frepple':
        raise CommandError("Invalid task identifier")
    else:
      now = datetime.now()
      self.task = Task(name='erp2frepple', submitted=now, started=now, status='0%', user=self.user)
    self.task.save(using=self.database)

    # Set the destination folder
    self.destination = settings.DATABASES[self.database]['FILEUPLOADFOLDER']
    if not os.access(self.destination, os.W_OK):
      raise CommandError("Can't write to folder %s " % self.destination)

    # Open database connection
    print("Connecting to the uzERP database")
    with getERPconnection() as erp_connection:
      self.cursor = erp_connection.cursor()
      self.fk = '_id' if self.ext == 'cpy' else ''

      # Extract all files
      try:
        self.extractLocation()
        self.task.status = '7%'
        self.task.save(using=self.database)

        self.extractCustomer()
        self.task.status = '14%'
        self.task.save(using=self.database)

        self.extractItem()
        self.task.status = '21%'
        self.task.save(using=self.database)

        self.extractSupplier()
        self.task.status = '28%'
        self.task.save(using=self.database)

        self.extractResource()
        self.task.status = '35%'
        self.task.save(using=self.database)

        self.extractSalesOrder()
        self.task.status = '42%'
        self.task.save(using=self.database)

        self.extractOperation()
        self.task.status = '49%'
        self.task.save(using=self.database)

        self.extractSuboperation()
        self.task.status = '48%'
        self.task.save(using=self.database)

        self.extractOperationResource()
        self.task.status = '56%'
        self.task.save(using=self.database)

        self.extractOperationMaterial()
        self.task.status = '63%'
        self.task.save(using=self.database)

        self.extractItemSupplier()
        self.task.status = '70%'
        self.task.save(using=self.database)

        #self.extractCalendar()
        #self.task.status = '72%'
        #self.task.save(using=self.database)

        #self.extractCalendarBucket()
        #self.task.status = '78%'
        #self.task.save(using=self.database)

        self.extractBuffer()
        self.task.status = '77%'
        self.task.save(using=self.database)

        self.extractPurchaseOrders()
        self.task.status = '84%'
        self.task.save(using=self.database)

        self.extractManufacturingOrders()
        self.task.status = '91%'
        self.task.save(using=self.database)

        self.task.status = 'Done'

      except Exception as e:
        self.task.status = 'Failed'
        self.task.message = 'Failed: %s' % e

      finally:
        self.task.finished = datetime.now()
        self.task.save(using=self.database)


  def extractLocation(self):
    '''
    Import uzERP locations to frePPLe.
    '''
    outfilename = os.path.join(self.destination, 'location.%s' % self.ext)
    print("Start extracting locations to %s" % outfilename)
    self.cursor.execute('''
      select * from frepple.locations
      ''')
    with open(outfilename, 'w', newline='') as outfile:
      outcsv = csv.writer(outfile, quoting=csv.QUOTE_MINIMAL)
      outcsv.writerow(['name', 'description', 'available', 'lastmodified'])
      outcsv.writerows(self.cursor.fetchall())


  def extractCustomer(self):
    '''
    Import uzERP customers to frePPLe.
    '''
    outfilename = os.path.join(self.destination, 'customer.%s' % self.ext)
    print("Start extracting customers to %s" % outfilename)
    self.cursor.execute('''
      select name, category
      from frepple.customers;
      ''')
    with open(outfilename, 'w', newline='') as outfile:
      outcsv = csv.writer(outfile, quoting=csv.QUOTE_MINIMAL)
      outcsv.writerow(['name', 'category', 'lastmodified'])
      outcsv.writerows(self.cursor.fetchall())


  def extractItem(self):
    '''
    Import uzERP st_items to frePPLe.
    '''
    outfilename = os.path.join(self.destination, 'item.%s' % self.ext)
    print("Start extracting items to %s" % outfilename)
    self.cursor.execute('''
      select * from frepple.items
      ''')
    with open(outfilename, 'w', newline='') as outfile:
      outcsv = csv.writer(outfile, quoting=csv.QUOTE_MINIMAL)
      outcsv.writerow(['name', 'description', 'category','subcategory', 'cost'])
      outcsv.writerows(self.cursor.fetchall())


  def extractSupplier(self):
    '''
    Import uzERP suppliers to frePPLe.
    '''
    outfilename = os.path.join(self.destination, 'supplier.%s' % self.ext)
    print("Start extracting suppliers to %s" % outfilename)
    self.cursor.execute('''
      select *
      from frepple.suppliers
      ''')
    with open(outfilename, 'w', newline='') as outfile:
      outcsv = csv.writer(outfile, quoting=csv.QUOTE_MINIMAL)
      outcsv.writerow(['name', 'category'])
      outcsv.writerows(self.cursor.fetchall())


  def extractResource(self):
    '''
    Import uzERP work centres to frePPLe.
    '''
    outfilename = os.path.join(self.destination, 'resource.%s' % self.ext)
    print("Start extracting resources to %s" % outfilename)
    self.cursor.execute('''
      select * from frepple.resources
      ''')
    with open(outfilename, 'w', newline='') as outfile:
      outcsv = csv.writer(outfile, quoting=csv.QUOTE_MINIMAL)
      outcsv.writerow(['name', 'location', 'type', 'maximum', 'available'])
      outcsv.writerows(self.cursor.fetchall())


  def extractSalesOrder(self):
    '''
    Import uzERP sales order lines to frePPLe.
    '''
    outfilename = os.path.join(self.destination, 'demand.%s' % self.ext)
    print("Start extracting demand to %s" % outfilename)
    self.cursor.execute('''
      select * from frepple.sales_orders
      ''')
    with open(outfilename, 'w', newline='') as outfile:
      outcsv = csv.writer(outfile, quoting=csv.QUOTE_MINIMAL)
      outcsv.writerow([
        'name', 'quantity', 'item', 'location', 'due', 'customer', 'operation'
        ])
      outcsv.writerows(self.cursor.fetchall())


  def extractOperation(self):
    '''
    Import uzERP opertations to frePPLe.

    The operations are 'containers' for sub-operations.
    '''
    outfilename = os.path.join(self.destination, 'operation.%s' % self.ext)
    print("Start extracting operations to %s" % outfilename)
    self.cursor.execute('''
      select * from frepple.operations
      ''')
    with open(outfilename, 'w', newline='') as outfile:
      outcsv = csv.writer(outfile, quoting=csv.QUOTE_MINIMAL)
      outcsv.writerow([
        'name', 'item', 'duration', 'duration_per', 'type', 'location', 'description', 'sizemultiple', 'available', 'category'
        ])
      outcsv.writerows(self.cursor.fetchall())


  def extractSuboperation(self):
    '''
    Import uzERP operations as frePPLe suboperations.
    '''
    outfilename = os.path.join(self.destination, 'suboperation.%s' % self.ext)
    print("Start extracting suboperations to %s" % outfilename)
    self.cursor.execute('''
      select * from frepple.sub_operations
      ''')
    with open(outfilename, 'w', newline='') as outfile:
      outcsv = csv.writer(outfile, quoting=csv.QUOTE_MINIMAL)
      outcsv.writerow([
        'suboperation', 'operation', 'priority'
        ])
      outcsv.writerows(self.cursor.fetchall())


  def extractOperationResource(self):
    '''
    Import uzERP operation workcenters as frePPLe operation-resources.
    '''
    outfilename = os.path.join(self.destination, 'operationresource.%s' % self.ext)
    print("Start extracting operationresource to %s" % outfilename)
    self.cursor.execute('''
      select * from frepple.operation_resources
      ''')
    with open(outfilename, 'w', newline='') as outfile:
      outcsv = csv.writer(outfile, quoting=csv.QUOTE_MINIMAL)
      outcsv.writerow([
        'operation', 'resource', 'quantity'
        ])
      outcsv.writerows(self.cursor.fetchall())


  def extractOperationMaterial(self):
    '''
    Import uzERP product structures as frePPLe operation-materials.
    '''
    outfilename = os.path.join(self.destination, 'operationmaterial.%s' % self.ext)
    print("Start extracting operationmaterial to %s" % outfilename)
    self.cursor.execute('''
      select * from frepple.operation_materials
      ''')
    with open(outfilename, 'w', newline='') as outfile:
      outcsv = csv.writer(outfile, quoting=csv.QUOTE_MINIMAL)
      outcsv.writerow([
        'operation', 'item', 'quantity', 'type'
        ])
      outcsv.writerows(self.cursor.fetchall())


  def extractBuffer(self):
    '''
    Import uzERP on-hand stock and st_item paramters into frePPLe buffers.
    '''
    outfilename = os.path.join(self.destination, 'buffer.%s' % self.ext)
    print("Start extracting buffer to %s" % outfilename)
    self.cursor.execute('''
      select * from frepple.buffers
      ''')
    with open(outfilename, 'w', newline='') as outfile:
      outcsv = csv.writer(outfile, quoting=csv.QUOTE_MINIMAL)
      outcsv.writerow([
        'name', 'location', 'item', 'onhand', 'minimum', 'min_interval', 
        ])
      outcsv.writerows(self.cursor.fetchall())


  def extractItemSupplier(self):
    '''
    Import uzERP supplier/item links and st_item parameters for purchased items to frePPLe.
    '''
    outfilename = os.path.join(self.destination, 'itemsupplier.%s' % self.ext)
    print("Start extracting buffer to %s" % outfilename)
    self.cursor.execute('''
      select * from frepple.item_suppliers
      ''')
    with open(outfilename, 'w', newline='') as outfile:
      outcsv = csv.writer(outfile, quoting=csv.QUOTE_MINIMAL)
      outcsv.writerow([
        'supplier', 'item', 'location', 'leadtime', 'sizemultiple', 'sizeminimum', 'lastmodified'
        ])
      outcsv.writerows(self.cursor.fetchall())

  def extractPurchaseOrders(self):
    '''
    Import uzERP purchase order lines to frePPLe.
    '''
    outfilename = os.path.join(self.destination, 'purchaseorder.%s' % self.ext)
    print("Start extracting buffer to %s" % outfilename)
    self.cursor.execute('''
      select * from frepple.purchase_orders
      ''')
    with open(outfilename, 'w', newline='') as outfile:
      outcsv = csv.writer(outfile, quoting=csv.QUOTE_MINIMAL)
      outcsv.writerow([
        'reference', 'status', 'item', 'location', 'supplier', 'enddate', 'quantity'
        ])
      outcsv.writerows(self.cursor.fetchall())


  def extractManufacturingOrders(self):
    '''
    Import uzERP work orders to frePPLe.
    '''
    outfilename = os.path.join(self.destination, 'manufacturingorder.%s' % self.ext)
    print("Start extracting buffer to %s" % outfilename)
    self.cursor.execute('''
      select * from frepple.manufacturing_orders
      ''')
    with open(outfilename, 'w', newline='') as outfile:
      outcsv = csv.writer(outfile, quoting=csv.QUOTE_MINIMAL)
      outcsv.writerow([
        'reference', 'status', 'item', 'startdate', 'enddate', 'quantity', 'operation'
        ])
      outcsv.writerows(self.cursor.fetchall())


  def extractCalendar(self):
    pass


  def extractCalendarBucket(self):
    pass
