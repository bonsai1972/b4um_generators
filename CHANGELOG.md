# Changelog

All notable changes to b4um Generators will be documented in this file.

## [Unreleased]

## [0.5.0] - 2026-10-14

### Added

- Added complete Todo application generator with `b4um:todo`
- Added task creation, completion, reopening and deletion
- Added separate lists for open and completed tasks
- Added automatic task counters and progress tracking
- Added progress bar with completion percentage
- Added Turbo Stream updates without full page reloads
- Added Stimulus controller for task input handling
- Added automatic input reset after successful task creation
- Added responsive Todo layout with b4um cards and floating labels
- Added light and dark mode support for Todo components
- Added optional `--owner=MODEL` support for personal Todo lists
- Added integration with b4um authentication and current account helpers
- Added owner-specific task access protection
- Added HTTP 401 responses for unauthenticated owner-specific Todo requests
- Added 35 RSpec examples for the Todo generator

### Changed

- Extended `b4um:help` with Todo generator documentation
- Extended Help generator RSpec coverage for Todo
- Updated English and German README documentation
- Updated the generator overview to include `b4um:todo`

## [0.4.2] - 2026-10-13

### Fixed

- Fixed indentation of generated `to_param` methods in the Readable generator
- Fixed `--param` formatting in generated scaffold models
- Fixed scaffold revoke behavior so generated model, controller and navigation changes are removed cleanly
- Fixed scaffold navigation cleanup during revoke
- Fixed Sortable migration detection when another database table already contains a `position` column
- Fixed Sortable model formatting when adding position callbacks
- Fixed Sortable fixture generation for `NOT NULL` position columns
- Fixed partially positioned Sortable fixtures while preserving fixture metadata
- Fixed Comments routing when the target resource already uses a block
- Fixed Authentication helper formatting in `ApplicationController`
- Fixed Admin helper and blocked-session formatting
- Fixed Admin revoke handling for generated authentication and route changes
- Fixed In-Place generator integration and formatting edge cases

### Changed

- Improved generator idempotency and revoke behavior
- Improved integration between Scaffold, Authentication, Admin, Comments, Sortable and In-Place generators
- Expanded regression coverage for generator formatting, routing, fixtures and revoke behavior
- Increased RuboCop line-length configuration for the generator source
- Verified the complete generator suite with 466 RSpec examples and 0 failures
- Verified generated applications with Rails 8.1.4

## [0.4.1] - 2026-10-13

### Fixed

- Fixed scaffold password tests for bcrypt-backed authentication
- Fixed generated destroy formatting
- Fixed generated fixtures for authentication models with unique email addresses
- Fixed generated authentication tests for protected actions

### Changed

- Improved Authentication integration with generated scaffold tests
- Improved generated test setup for authenticated resources
- Improved bcrypt integration in generated applications

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
