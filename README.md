# Frepple ERP connector for uzERP

## Settings

```python
# uzERP database connection settings
UZERP_DB = {
	'NAME': 'database',
	'USER': 'frepple',
	'PASSWORD': 'xxx',
	'HOST': 'localhost',
	'PORT': ''
}

# uzERP connector settings
UZERP_SETTINGS = {
	'EXPORT': {
		'wo_documentation': ('26', '9'),
		'wo_release_fence': 2,
		'po_release_fence': 2
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