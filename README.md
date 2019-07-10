# FrePPLe ERP connector for uzERP

## What is FrePPLe?

From their README:

> FrePPLe is an easy-to-use and easy-to-implement open source **advanced planning and scheduling** tool for manufacturing companies.
> 
> FrePPLe implements planning algoritms based on best practices such as **theory of constraints** (ie *plan around the bottleneck*),
> **pull-based planning** (ie *start production as late as possible and directly triggered by demand*) and **lean manufacturing** (ie *avoid 
> intermediate delays and inventory*).

More on FrePPLe: https://frepple.com

## What is uzERP?

uzERP is an open source ERP system focused on UK SME/Owner managed businesses. It delivers big company functionality on a small company budget, including accounting, stock, manufacturing and more.

The FrePPLe connector for uzERP allows uzERP users to import sales orders, work orders, stock position, structures, operations, etc. into 
FrePPLe Community Edition and generate proposed purchase and work orders. The connector provides complete two way integration including the export of proposed orders back to uzERP for execution. Proposed orders can be exported en mass, respecting a time-fence, or individually.

More on uzERP: https://www.uzerp.com

## Connector Installation

If you run FrePPLe using a python virtualenv, as we prefer to do, you can use `pip` to install the connector. You can also follow the `setup.py` method.

**Install using pip:**

```
$ pip install git+https://github.com/uzerpllp/uzerpfrepple.git
```

**Install using `setup.py`:**

Clone or download from [github](https://github.com/uzerpllp/uzerpfrepple), then run `setup.py`

```
$ python uzerpfrepple/setup.py install
```

*If you installed FrePPLe from binary packages, you will need to prefix the above command with `sudo` to install it system-wide*

## Add the frepple schema to the uzERP Database

The frepple [schema](https://github.com/uzerpllp/uzerpfrepple/blob/master/schema/frepple.sql) is included in the *schema* folder with the connector software. The `frepple.sql` file assumes that you have created a DB role called 'frepple' when installing the FrePPLe application and will be using that with the uzERP connector.

The schema can can be added to the uzERP database using the PostgreSQL client by running the following command:

```
$ sudo -u postgres psql < /<path-to-connector>/schema/frepple.sql <uzerp-db-name>
```

*Note: you will need to replace `<path-to-connector>` with the location where you downloaded the connector to. `<uzerp-db-name>` is the name of your uzERP database*

## Settings

Once the connector is installed it is configured by adding additional settings to FrePPLe's `djangosetting.py` file, located at `/etc/frepple/djangosettings.py` for binary package installations.

```python
# FrePPLe djangosettings.py

# uzERP database connection settings
UZERP_DB = {
	'NAME': 'uzerp',
	'USER': 'frepple',
	'PASSWORD': 'xxx',
	'HOST': 'localhost',
	'PORT': ''
}

# uzERP connector settings
UZERP_SETTINGS = {
	'EXPORT': {
		'wo_documentation': ('26', '9'),
			# Database id's of the uzERP work order
			# documentation injector classes
		'wo_release_fence': 2,
			# Planned purchase orders due to start after this
			# number of days from today will not be exported
		'po_release_fence': 2
			# Planned purchase orders due to start after this
			# number of days from today will not be exported
	}
}

# Add the uzERP connector
INSTALLED_APPS = (
	...
    # Add any project specific apps here
    'uzerp',
	...

# uzERP Frepple authentication backend (optional)
#
# Authenticate frepple user logins against the uzERP database.
# Users must be assigned to a uzERP role with the name 'frepple'
# and the user must have also been creted in the frepple application.
AUTHENTICATION_BACKENDS = ['uzerp.uzerpauth.uzerpAuthBackend']
```

## Using the connector

The uzERP connector adds two tasks to FrePPLe's *Execute* menu:

* Import data from uzERP (erp2frepple)
* Export data to uzERP (frepple2erp)

These tasks can also be run from the command line, e.g.:

```
$ frepplectl.py erptofrepple
```

### Import Data from uzERP

Data from uzERP is imported via a number of PostgreSQL views under the *frepple* schema in the uzERP database. These views produce output to match FrePPLe's requirements for planning data. The connector retrieves the data from these views, creating a set of CSV files, then runs FrePPLe's *importfromfolder* command to import them.

*See below for more detail on the mapping of data from uzERP to FrePPLe*

### Export Data to uzERP

For both Manufacturing and Purchase Orders, orders are only exported if they have a *proposed* status and their start date falls within the time-fence defined in the connector configuration. Order status in FrePPLe is changed to *approved* after exporting.

As well as using the execute task to export all proposed orders to uzERP, individual orders can be selected and exported from their list in Frepple. Look for the 'Select action' button in, say, Manufacturing Orders and select 'Export to uzERP'. The time-fence settings are ignored for individual exports.

For Manufacturing Orders, the connector selects the operation plan for *routing* type operations in FrePPLe and creates a matching work order in uzERP, at status NEW, for each requirement. Each work order will have the documents defined in the *djangosettings.py* configuration.

Purchase orders from the operation plan are created in uzERP as potential, individual order lines and are viewed in the *Review Planned* screen. From there they can be grouped as required and turned into actual purchase orders.

### uzERP to Fepple Data Mapping

**Table: uzERP/Frepple Data Mapping**

**uzERP Data**   |   uzERP Data Type    |   **FrePPLe Data**  |  FrePPLe Data Type           |            Notes
---|---|---|---|---
**Items** |
Min Qty | Stock Item | Minimum | Buffer | Minimum or *safety* stock. *The solver treats this as a soft constraint, ie it tries to meet this inventory level but will go below the minimum level if required to meet the demand.*
Batch Size | Stock Item | Size Multiple | Operation (MF items) or Item Supplier (Purchased) | Order multiple. For example, if the multiple was 5 and 12 items were ordered, an order for 15 would be planned.
Balance | Stock Balance | On hand | Buffer | Total item on hand stock balance from all of uzERP's locations.
-- | -- | Mininterval | Buffer | Combine multiple replenishments that are planned to fall within this window. *Currently set to 5 days*.
Lead Time | Stock Item | Lead Time | Item Supplier (Purchased) | Purchasing lead time for raw materials, expressed in days.
Supplier Name | Purchased Productline | Supplier Name | Item Supplier | Supplier of each item from the uzERP purchased product-line. *FrePPLe will not buffer replenishment without a supplier source*
**Work Centres** |
Centre         |     Centre    |      Name        |        Resource       |                 Name
Available Qty  |     Centre     |     Maximum     |        Resource       |                 Defines the maximum size of the resource.
**Operations** |
Operation Time   |   Operation   |    Duration Per    |    Sub-operation   | Operation time for each item produced.
Lead Time        |   (Routing outside op.)   |    Duration        |    Sub-operation   | Outside operation lead time, expressed in days in uzERP and converted to seconds for FrePPLe. For example 1 day in uzERP is converted to 1 x 28800 sec = 28800 sec (8 hours), see supplier calendar.
Work Centre Name |   Work Centre |    Resource      |      Name   | Operations are loaded on resources.
**Orders** |
Sales Orders     |   Order line and Customer  |   Sales Orders       | |                                 Dependent demand.
Purchase Orders   |  Order line and Supplier  |   Purchase Orders    | |                                Raw materials on order.
Work Orders     |    Item, Qty, Start Date, End Date   |  Manufacturing Orders  | |                              Work in Progress and Future, firm orders.
**Calendars** |
-- | -- | default | | Applied as the *available* calendar for Operations, Sub-operations and Locations. This calendar represents working time in the factory.
-- | -- | supplier | | Applied as the *available* calendar to 'outside' sub-operations to model supplier lead time in days. The calendar must have 8 hours available Monday - Friday (assumes supplier only work on weekdays).

**Note: this connector has not been tested on windows**