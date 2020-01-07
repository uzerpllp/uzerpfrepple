# Change Log

All notable changes to this project will be documented in this file.

## Unreleased

- Use the stock item's type code to retrieve the location for manufactured item operations and buffers

## 1.2

### Fixed

- Remove sub_operations table from schema dump

### Changed

- Get locations from uzERP stock actions
    - A 'complete' type action provides the store code for manufactured items
    - and a 'receive' type action provides the store code for purchased items

- Move frePPLe export grants to their own file

## 1.1

### Changed

- Removed suboperations import (deprecated in frePPLe release 6.0.0)
