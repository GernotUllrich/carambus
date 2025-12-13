# ClubCloud Automatic Upload

## Overview

The Carambus system can automatically transfer game results to ClubCloud. After each completed game, the data is directly entered into ClubCloud without manual admin intervention.

## Features

### ✅ Automatic Upload
- **After each game**: Once a game is finished, results are automatically uploaded
- **No intervention needed**: Admin doesn't need to do anything
- **Duplicate protection**: Multiple calls result in only one upload
- **Error handling**: Errors don't interrupt the tournament

### ✅ Secure Credential Management
- **Encrypted**: Credentials stored in Rails Credentials
- **Local**: Credentials not synchronized via API server
- **Per-environment**: Different credentials for Development/Production

### ✅ Intelligent Name Mapping
- **Gruppe 1** → **Gruppe A**
- **Platz 5-6** → **Spiel um Platz 5**
- **hf1** → **Halbfinale**
- **fin** → **Finale**

### ✅ Admin Feedback
- **Errors visible**: Upload errors displayed in tournament UI
- **Consistent logs**: All logs with `[CC-Upload]` prefix
- **Clear messages**: Understandable error messages

## Setup

### 1. Configure ClubCloud Credentials

ClubCloud credentials must be stored **locally and encrypted**:

```bash
# Development
EDITOR=vim rails credentials:edit --environment development

# Production (on server)
EDITOR=vim RAILS_ENV=production rails credentials:edit --environment production
```

Add the following structure:

```yaml
clubcloud:
  nbv:
    username: "your-email@example.com"
    password: "your-password"
```

**Important**: The `.key` files are local and **NOT** committed!

### 2. Tournament Preparation

When resetting the tournament monitor (`do_reset_tournament_monitor`), the system automatically:

1. **Tests ClubCloud login**
2. **Loads group mappings** from ClubCloud
3. **Validates game names** against ClubCloud groups

Problems trigger warnings:

```
WARNING: Missing ClubCloud group mappings for games: group1:1-2, Platz 5-6
```

### 3. Tournament Start

At tournament start, ClubCloud access is validated:

```
ClubCloud access validated ✓
```

If login fails:

```
ClubCloud login failed: Invalid credentials. 
Please check ClubCloud credentials.
```

### 4. Automatic Upload During Tournament

After each game:

```
[CC-Upload] ✓ Successfully uploaded game[123] (Player1 vs Player2, group1:1-2)
```

For duplicates:

```
[CC-Upload] ⊘ Skipping game[123] - already uploaded at 20:30:15
```

For errors:

```
[CC-Upload] ✗ Upload failed: Group 'group1:1-2' could not be mapped
```

## Name Mapping

### Groups

| Carambus | ClubCloud |
|----------|-----------|
| group1:1-2 | Gruppe A |
| Gruppe 1 | Gruppe A |
| group2:1-2 | Gruppe B |
| Gruppe 2 | Gruppe B |
| group3:1-2 | Gruppe C |
| ... | ... |

### Placement Games

| Carambus | ClubCloud |
|----------|-----------|
| Platz 3-4 | Spiel um Platz 3 |
| p<3-4> | Spiel um Platz 3 |
| Platz 5-6 | Spiel um Platz 5 |
| p<5-6> | Spiel um Platz 5 |
| Platz 7-8 | Spiel um Platz 7 |
| ... | ... |

### Semifinals & Final

| Carambus | ClubCloud |
|----------|-----------|
| hf1 | Halbfinale |
| hf2 | Halbfinale |
| Halbfinale | Halbfinale |
| fin | Finale |
| Finale | Finale |

For complete documentation, see the [German version](../de/clubcloud-upload.md).

## See Also

- [Tournament Management](tournament-management.md)
- [ClubCloud Integration](clubcloud-integration.md)
- [API Server Synchronization](api-server-sync.md)

