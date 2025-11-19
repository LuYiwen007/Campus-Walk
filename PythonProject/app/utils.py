"""
地理计算工具函数
用于计算距离、方位角、视野范围等
"""
import math
from typing import Tuple, List


# 地球半径（米）
EARTH_RADIUS = 6371000


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    使用Haversine公式计算两点之间的距离（米）
    
    Args:
        lat1: 第一个点的纬度
        lon1: 第一个点的经度
        lat2: 第二个点的纬度
        lon2: 第二个点的经度
    
    Returns:
        两点之间的距离（米）
    """
    # 转换为弧度
    lat1_rad = math.radians(lat1)
    lon1_rad = math.radians(lon1)
    lat2_rad = math.radians(lat2)
    lon2_rad = math.radians(lon2)
    
    # 计算差值
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad
    
    # Haversine公式
    a = math.sin(dlat / 2) ** 2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon / 2) ** 2
    c = 2 * math.asin(math.sqrt(a))
    
    # 返回距离（米）
    return EARTH_RADIUS * c


def calculate_bearing(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    计算从点1到点2的方位角（度，0-360）
    0度表示正北，90度表示正东，180度表示正南，270度表示正西
    
    Args:
        lat1: 起点纬度
        lon1: 起点经度
        lat2: 终点纬度
        lon2: 终点经度
    
    Returns:
        方位角（度，0-360）
    """
    # 转换为弧度
    lat1_rad = math.radians(lat1)
    lon1_rad = math.radians(lon1)
    lat2_rad = math.radians(lat2)
    lon2_rad = math.radians(lon2)
    
    # 计算差值
    dlon = lon2_rad - lon1_rad
    
    # 计算方位角
    y = math.sin(dlon) * math.cos(lat2_rad)
    x = math.cos(lat1_rad) * math.sin(lat2_rad) - math.sin(lat1_rad) * math.cos(lat2_rad) * math.cos(dlon)
    
    # 转换为度并规范化到0-360
    bearing = math.degrees(math.atan2(y, x))
    bearing = (bearing + 360) % 360
    
    return bearing


def normalize_angle(angle: float) -> float:
    """
    规范化角度到0-360度范围
    
    Args:
        angle: 输入角度（度）
    
    Returns:
        规范化后的角度（0-360度）
    """
    angle = angle % 360
    if angle < 0:
        angle += 360
    return angle


def is_in_fov(
    center_lat: float,
    center_lon: float,
    center_heading: float,
    fov: float,
    target_lat: float,
    target_lon: float
) -> bool:
    """
    判断目标点是否在视野范围内（扇形区域）
    
    Args:
        center_lat: 中心点纬度
        center_lon: 中心点经度
        center_heading: 中心点朝向（度，0-360，0表示正北）
        fov: 视野角度（度）
        target_lat: 目标点纬度
        target_lon: 目标点经度
    
    Returns:
        如果目标点在视野范围内返回True，否则返回False
    """
    # 计算从中心点到目标点的方位角
    bearing = calculate_bearing(center_lat, center_lon, target_lat, target_lon)
    
    # 规范化角度
    center_heading = normalize_angle(center_heading)
    bearing = normalize_angle(bearing)
    
    # 计算视野范围的边界角度
    half_fov = fov / 2
    left_bound = normalize_angle(center_heading - half_fov)
    right_bound = normalize_angle(center_heading + half_fov)
    
    # 判断目标点是否在视野范围内
    # 需要考虑跨越0度/360度边界的情况
    if left_bound > right_bound:
        # 视野范围跨越0度/360度边界
        return bearing >= left_bound or bearing <= right_bound
    else:
        # 视野范围在正常范围内
        return left_bound <= bearing <= right_bound


def filter_pois_in_fov(
    center_lat: float,
    center_lon: float,
    center_heading: float,
    fov: float,
    radius: float,
    pois: List[dict]
) -> List[dict]:
    """
    筛选在视野范围内的POI列表
    
    Args:
        center_lat: 中心点纬度
        center_lon: 中心点经度
        center_heading: 中心点朝向（度）
        fov: 视野角度（度）
        radius: 搜索半径（米）
        pois: POI列表，每个POI包含latitude和longitude字段
    
    Returns:
        在视野范围内的POI列表，每个POI添加了distance和bearing字段
    """
    filtered_pois = []
    
    for poi in pois:
        poi_lat = float(poi.get('latitude', 0))
        poi_lon = float(poi.get('longitude', 0))
        
        # 计算距离
        distance = haversine_distance(center_lat, center_lon, poi_lat, poi_lon)
        
        # 检查是否在半径范围内
        if distance > radius:
            continue
        
        # 检查是否在视野范围内
        if not is_in_fov(center_lat, center_lon, center_heading, fov, poi_lat, poi_lon):
            continue
        
        # 添加距离和方位角信息
        poi_with_info = poi.copy()
        poi_with_info['distance'] = distance
        poi_with_info['bearing'] = calculate_bearing(center_lat, center_lon, poi_lat, poi_lon)
        
        filtered_pois.append(poi_with_info)
    
    return filtered_pois


def sort_pois_by_distance(pois: List[dict]) -> List[dict]:
    """
    按距离对POI列表进行排序（从近到远）
    
    Args:
        pois: POI列表，每个POI包含distance字段
    
    Returns:
        排序后的POI列表
    """
    return sorted(pois, key=lambda x: x.get('distance', float('inf')))


def generate_cache_key(
    latitude: float,
    longitude: float,
    radius: float,
    heading: float = None,
    fov: float = None
) -> str:
    """
    生成缓存键（基于位置和参数）
    
    将位置四舍五入到一定精度，减少缓存碎片
    
    Args:
        latitude: 纬度
        longitude: 经度
        radius: 半径（米）
        heading: 朝向（可选）
        fov: 视野角度（可选）
    
    Returns:
        唯一的缓存键字符串
    """
    # 将位置四舍五入到一定精度，减少缓存碎片
    lat_rounded = round(latitude * 1000) / 1000  # 约111米精度
    lon_rounded = round(longitude * 1000) / 1000
    
    # 半径四舍五入到50米
    radius_rounded = round(radius / 50) * 50
    
    key = f"poi_{lat_rounded}_{lon_rounded}_r{radius_rounded}"
    
    if heading is not None:
        heading_rounded = round(heading / 10) * 10  # 朝向四舍五入到10度
        key += f"_h{heading_rounded}"
    if fov is not None:
        fov_rounded = round(fov / 5) * 5  # 视野角度四舍五入到5度
        key += f"_f{fov_rounded}"
    
    return key

