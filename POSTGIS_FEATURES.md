# PostGIS Location Features Implementation

## Overview
This implementation adds PostGIS spatial functionality to the Socialite application, allowing users to set their location and discover nearby users.

## Features Implemented

### 1. Database Schema Updates
- **User Location Fields**: Added latitude, longitude, address, city, state, country, postal_code
- **PostGIS Integration**: Added `location_point` geometry field with SRID 4326 (WGS84)
- **Spatial Indexes**: Created GIST index for efficient spatial queries

### 2. User Schema Enhancements
- **Location Fields**: New fields for storing user location data
- **Validation**: Lat/lng validation with proper bounds checking
- **Helper Functions**: 
  - `has_location?/1` - Check if user has location set
  - `full_address/1` - Format complete address string
  - **PostGIS Integration**: Automatic geometry point creation from lat/lng

### 3. Settings Page (`/settings`)
- **Profile Management**: Update basic user information
- **Location Settings**: 
  - Manual lat/lng input
  - Address fields (street, city, state, postal code, country)
  - **Geolocation API**: "Get Current Location" button using browser geolocation
  - Real-time location display with coordinates and formatted address

### 4. Location-Based Features

#### Profile Page Enhancements
- **Location Display**: Shows user's location on profile pages
- **Distance Calculation**: Shows distance between current user and profile user
- **Nearby Users**: Displays users within 50km radius on own profile

#### Spatial Query Functions
- `find_nearby_users/4` - Find users within specified radius
- `distance_between_users/2` - Calculate distance between two users
- `list_users_with_location/0` - Get all users with location data

### 5. UI Components
- **Geolocation Button**: JavaScript hook for getting current position
- **Location Indicators**: Visual indicators for location-enabled profiles
- **Distance Badges**: Show distance between users
- **Nearby Users Grid**: Display nearby users with profile links

## Technical Implementation

### PostGIS Setup
```sql
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE INDEX users_location_point_idx ON users USING gist (location_point);
```

### Spatial Queries
- Uses `ST_DWithin` for radius-based searches
- Uses `ST_Distance` for distance calculations
- Converts lat/lng to PostGIS Point geometry with SRID 4326

### JavaScript Integration
- Browser Geolocation API integration
- Phoenix LiveView hooks for seamless location updates
- Real-time form updates when location is obtained

## Usage

### Setting User Location
1. Navigate to `/settings`
2. Either:
   - Click "Get Current Location" to use GPS
   - Manually enter coordinates and address
3. Save changes

### Viewing Location Features
- **Profile Pages**: Shows location info and distance to other users
- **Own Profile**: Shows nearby users within 50km
- **User Discovery**: Find people in your area

## Database Queries Examples

### Find nearby users:
```elixir
Accounts.find_nearby_users(40.7128, -74.0060, 25) # 25km radius from NYC
```

### Calculate distance:
```elixir
Accounts.distance_between_users(user1, user2) # Returns distance in km
```

## Configuration
- Default search radius: 50km
- Maximum nearby users displayed: 5
- Coordinate precision: 4 decimal places (≈11m accuracy)

## Future Enhancements
- Map visualization integration
- Location-based event discovery
- Privacy controls for location sharing
- Location history and check-ins
- Group discovery based on location 