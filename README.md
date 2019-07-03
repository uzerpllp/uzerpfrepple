# FrePPLe ERP connector for uzERP

FrePPLe is an easy-to-use and easy-to-implement open source **advanced planning and scheduling** tool for manufacturing companies.

FrePPLe implements planning algoritms based on best practices such as **theory of constraints** (ie *plan around the bottleneck*), **pull-based planning** (ie *start production as late as possible and directly triggered by demand*) and **lean manufacturing** (ie *avoid intermediate delays and inventory*).

The FrePPLe connector for uzERP allows uzERP users to import sales orders, work orders, stock position, structures, operations, etc. into FrePPLe Community Edition and generate proposed purchase and work orders. The connector also provides integration for the export of proposed orders back to uzERP for execution.

More on FrePPLe: https://frepple.com

More on uzERP: https://www.uzerp.com

**Note: this connector has not been tested on windows**

## Installation

If you run FrePPLe using a python virtualenv, as we prefer to do, you can use `pip` to install the connector. If you have installed FrePPLe from the binary packages (e.g. on Ubuntu) then you can follow the `setup.py` method.

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