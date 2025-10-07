#!/usr/bin/env python3
"""
Great Circle Path Calculator
Calculates great circle paths between two points in lat/lon format without external libraries.
Handles dateline crossing (180°/-180° longitude).
"""

import math


def degrees_to_radians(degrees):
    """Convert degrees to radians."""
    return degrees * math.pi / 180.0


def radians_to_degrees(radians):
    """Convert radians to degrees."""
    return radians * 180.0 / math.pi


def normalize_longitude(lon):
    """Normalize longitude to [-180, 180] range."""
    while lon > 180:
        lon -= 360
    while lon < -180:
        lon += 360
    return lon


def great_circle_distance(lat1, lon1, lat2, lon2, earth_radius=6371.0):
    """
    Calculate great circle distance between two points using Haversine formula.
    
    Args:
        lat1, lon1: Latitude and longitude of first point in degrees
        lat2, lon2: Latitude and longitude of second point in degrees
        earth_radius: Earth radius in kilometers (default: 6371.0 km)
    
    Returns:
        Distance in kilometers
    """
    # Convert to radians
    lat1_rad = degrees_to_radians(lat1)
    lon1_rad = degrees_to_radians(lon1)
    lat2_rad = degrees_to_radians(lat2)
    lon2_rad = degrees_to_radians(lon2)
    
    # Haversine formula
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad
    
    a = (math.sin(dlat/2)**2 + 
         math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon/2)**2)
    c = 2 * math.asin(math.sqrt(a))
    
    return earth_radius * c


def initial_bearing(lat1, lon1, lat2, lon2):
    """
    Calculate initial bearing from point 1 to point 2.
    
    Args:
        lat1, lon1: Latitude and longitude of first point in degrees
        lat2, lon2: Latitude and longitude of second point in degrees
    
    Returns:
        Bearing in degrees (0-360, where 0 is North)
    """
    # Convert to radians
    lat1_rad = degrees_to_radians(lat1)
    lon1_rad = degrees_to_radians(lon1)
    lat2_rad = degrees_to_radians(lat2)
    lon2_rad = degrees_to_radians(lon2)
    
    dlon = lon2_rad - lon1_rad
    
    y = math.sin(dlon) * math.cos(lat2_rad)
    x = (math.cos(lat1_rad) * math.sin(lat2_rad) - 
         math.sin(lat1_rad) * math.cos(lat2_rad) * math.cos(dlon))
    
    bearing_rad = math.atan2(y, x)
    bearing_deg = radians_to_degrees(bearing_rad)
    
    # Normalize to 0-360
    return (bearing_deg + 360) % 360


def destination_point(lat, lon, bearing, distance, earth_radius=6371.0):
    """
    Calculate destination point given start point, bearing, and distance.
    
    Args:
        lat, lon: Starting latitude and longitude in degrees
        bearing: Bearing in degrees (0-360, where 0 is North)
        distance: Distance in kilometers
        earth_radius: Earth radius in kilometers (default: 6371.0 km)
    
    Returns:
        Tuple of (latitude, longitude) in degrees
    """
    # Convert to radians
    lat_rad = degrees_to_radians(lat)
    lon_rad = degrees_to_radians(lon)
    bearing_rad = degrees_to_radians(bearing)
    
    angular_distance = distance / earth_radius
    
    # Calculate destination point
    lat2_rad = math.asin(
        math.sin(lat_rad) * math.cos(angular_distance) +
        math.cos(lat_rad) * math.sin(angular_distance) * math.cos(bearing_rad)
    )
    
    lon2_rad = lon_rad + math.atan2(
        math.sin(bearing_rad) * math.sin(angular_distance) * math.cos(lat_rad),
        math.cos(angular_distance) - math.sin(lat_rad) * math.sin(lat2_rad)
    )
    
    # Convert back to degrees
    lat2 = radians_to_degrees(lat2_rad)
    lon2 = radians_to_degrees(lon2_rad)
    
    # Normalize longitude
    lon2 = normalize_longitude(lon2)
    
    return lat2, lon2


def great_circle_path(lat1, lon1, lat2, lon2, num_points=100):
    """
    Generate great circle path between two points.
    
    Args:
        lat1, lon1: Starting latitude and longitude in degrees
        lat2, lon2: Ending latitude and longitude in degrees
        num_points: Number of intermediate points to generate
    
    Returns:
        List of tuples (latitude, longitude) representing the path
    """
    # Calculate total distance
    total_distance = great_circle_distance(lat1, lon1, lat2, lon2)
    
    # Calculate initial bearing
    bearing = initial_bearing(lat1, lon1, lat2, lon2)
    
    # Generate path points
    path = [(lat1, lon1)]
    
    for i in range(1, num_points - 1):
        # Calculate distance for this point
        fraction = i / (num_points - 1)
        distance = total_distance * fraction
        
        # Calculate destination point
        lat, lon = destination_point(lat1, lon1, bearing, distance)
        path.append((lat, lon))
    
    # Add final point
    path.append((lat2, lon2))
    
    return path


def handle_dateline_crossing(path):
    """
    Handle dateline crossing by adjusting longitude values.
    
    Args:
        path: List of (lat, lon) tuples
    
    Returns:
        List of (lat, lon) tuples with adjusted longitudes
    """
    if not path:
        return path
    
    adjusted_path = []
    prev_lon = path[0][1]
    
    for lat, lon in path:
        # Check if we've crossed the dateline
        if abs(lon - prev_lon) > 180:
            if lon > prev_lon:
                lon -= 360  # Crossed from west to east
            else:
                lon += 360  # Crossed from east to west
        
        adjusted_path.append((lat, lon))
        prev_lon = lon
    
    return adjusted_path


def format_coordinates(lat, lon, precision=6):
    """Format coordinates for display."""
    return f"({lat:.{precision}f}, {lon:.{precision}f})"


def main():
    """Example usage of the great circle path calculator."""
    print("Great Circle Path Calculator")
    print("=" * 40)
    
    # Example points
    A_lat, A_lon = 21.2, -60.1
    B_lat, B_lon = 18.7, -58.4
    
    print(f"Point A: {format_coordinates(A_lat, A_lon)}")
    print(f"Point B: {format_coordinates(B_lat, B_lon)}")
    print()
    
    # Calculate distance
    distance = great_circle_distance(A_lat, A_lon, B_lat, B_lon)
    print(f"Great circle distance: {distance:.2f} km")
    
    # Calculate bearing
    bearing = initial_bearing(A_lat, A_lon, B_lat, B_lon)
    print(f"Initial bearing: {bearing:.2f}°")
    print()
    
    # Generate path
    print("Great circle path (10 points):")
    print("-" * 30)
    path = great_circle_path(A_lat, A_lon, B_lat, B_lon, num_points=10)
    
    for i, (lat, lon) in enumerate(path):
        print(f"Point {i+1:2d}: {format_coordinates(lat, lon)}")
    
    print()
    
    # Test dateline crossing
    print("Dateline crossing example:")
    print("-" * 30)
    # Points that cross the dateline
    C_lat, C_lon = 0.0, 179.0
    D_lat, D_lon = 0.0, -179.0
    
    print(f"Point C: {format_coordinates(C_lat, C_lon)}")
    print(f"Point D: {format_coordinates(D_lat, D_lon)}")
    
    dateline_path = great_circle_path(C_lat, C_lon, D_lat, D_lon, num_points=5)
    adjusted_path = handle_dateline_crossing(dateline_path)
    
    print("Path with dateline handling:")
    for i, (lat, lon) in enumerate(adjusted_path):
        print(f"Point {i+1}: {format_coordinates(lat, lon)}")


if __name__ == "__main__":
    main()