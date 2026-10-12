# Changelog

All notable changes to b4um Generators will be documented in this file.

## [Unreleased]

## [0.4.0] - 2026-10-12

### Added

- Added administrator management with `b4um:admin`
- Added command-line creation of the first administrator
- Added blocking, unblocking, deletion and administrator permission management
- Added `--required` support to the scaffold generator
- Added automatic required-field handling in generated forms
- Added temporary guest access with `b4um:guest`
- Added configurable guest account expiration with `--expires-in`
- Added guest-to-regular-account conversion while preserving the existing account record
- Added cleanup task for expired guest accounts
- Added guest expiration warnings
- Added dynamic field detection for administrator and guest account creation

### Changed

- Improved authentication integration with required model fields
- Improved administrator creation prompts and validation handling
- Improved administrator creation after guest access has been installed
- Improved generated Admin dashboard and user management layouts
- Improved migration generation to avoid duplicate migration version numbers
- Improved English and German documentation
- Extended `b4um:help` with Admin and Guest documentation

## [0.1.0] - 2026-09-17

- Initial release
