# Table: Person

**OutSystems Entity**: Person
**Module**: Access_CS
**Purpose**: Core identity entity representing a person in the Maxtel system. Consistent across tenants — the same person has the same PersonId regardless of which tenant they belong to.
**Last Updated**: 2026-05-23

---

## Overview

Person holds identity information (name, email, phone, date of birth, etc.) for individuals in the system. It is referenced by BusinessUser (which is tenant-specific) via `BusinessUser.PersonId`. Because PersonId is consistent across tenants, it is used as the cross-tenant key for features like ReportFavourites.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | BIGINT | PK, NOT NULL | Auto-generated primary key |
| `Name` | VARCHAR | | Full name of the person |
| `Email` | VARCHAR | | Email address |
| `Phone` | VARCHAR | | Phone number |
| `DateOfBirth` | DATE | | Date of birth |
| `GenderId` | BIGINT | FK | References Gender entity |
| `Address1` | VARCHAR | | Address line 1 |
| `Address2` | VARCHAR | | Address line 2 |
| `Suburb` | VARCHAR | | Suburb |
| `PostalCode` | VARCHAR | | Postal/ZIP code |
| `City` | VARCHAR | | City |
| `CountryId` | BIGINT | FK | References Country entity |
| `StateId` | BIGINT | FK | References State entity |
| `EmergencyContactName` | VARCHAR | | Emergency contact name |
| `EmergencyContactPhone` | VARCHAR | | Emergency contact phone |
| `EmergencyContactRelationship` | VARCHAR | | Relationship to emergency contact |
| `ProfilePicture` | BINARY | | Profile picture (binary data) |
| `ProfilePictureFileName` | VARCHAR | | Filename of profile picture |
| `ProfilePictureType` | VARCHAR | | MIME type of profile picture |

---

## Key Constraints

### Primary Key
- `Id` - Auto-generated identifier

### Foreign Keys
- `GenderId` → Gender.Id
- `CountryId` → Country.Id
- `StateId` → State.Id

---

## Relationships

### Tables That Reference This Table
- **BusinessUser** (Access_CS) - Employee record linked to this person
  - Join: `BusinessUser.PersonId = Person.Id`
- **ReportFavourites** (Report_CS) - Cross-tenant report favourites (Story #3826)
  - Join: `ReportFavourites.PersonId = Person.Id`

---

## Cross-Tenant Significance

Person is the **cross-tenant consistent** identity entity. A person logging into different tenants will have:
- **Same PersonId** across all tenants
- **Different BusinessUserId** in each tenant

This makes PersonId the correct key for features that should carry across tenants (e.g., report favourites).

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-05-23 | Claude | Initial documentation from Service Studio screenshot (Story #3826) |
