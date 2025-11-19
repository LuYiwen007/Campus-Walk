"""
POI数据导入脚本
支持从高德地图API、JSON文件、CSV文件导入POI数据
"""
import sys
import os
import json
import csv
from pathlib import Path

# 添加项目根目录到路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.db import SessionLocal, engine
from app.models import POI, Base
from datetime import datetime
from decimal import Decimal


def init_database():
    """初始化数据库表"""
    Base.metadata.create_all(bind=engine)
    print("✅ 数据库表初始化完成")


def validate_poi_data(poi_dict: dict) -> tuple[bool, str]:
    """
    验证POI数据
    
    Args:
        poi_dict: POI数据字典
    
    Returns:
        (是否有效, 错误信息)
    """
    # 检查必填字段
    required_fields = ['poi_id', 'name', 'latitude', 'longitude']
    for field in required_fields:
        if field not in poi_dict or poi_dict[field] is None:
            return False, f"缺少必填字段: {field}"
    
    # 验证数据类型和范围
    try:
        lat = float(poi_dict['latitude'])
        lon = float(poi_dict['longitude'])
        if not (-90 <= lat <= 90):
            return False, f"纬度超出范围: {lat}"
        if not (-180 <= lon <= 180):
            return False, f"经度超出范围: {lon}"
    except (ValueError, TypeError):
        return False, "经纬度格式错误"
    
    # 验证POI ID
    if not isinstance(poi_dict['poi_id'], str) or len(poi_dict['poi_id']) == 0:
        return False, "poi_id必须是非空字符串"
    
    # 验证名称
    if not isinstance(poi_dict['name'], str) or len(poi_dict['name']) == 0:
        return False, "name必须是非空字符串"
    
    return True, ""


def clean_poi_data(poi_dict: dict) -> dict:
    """
    清洗POI数据
    
    Args:
        poi_dict: 原始POI数据字典
    
    Returns:
        清洗后的POI数据字典
    """
    cleaned = {}
    
    # 必填字段
    cleaned['poi_id'] = str(poi_dict.get('poi_id', '')).strip()
    cleaned['name'] = str(poi_dict.get('name', '')).strip()
    cleaned['latitude'] = float(poi_dict.get('latitude', 0))
    cleaned['longitude'] = float(poi_dict.get('longitude', 0))
    
    # 可选字段
    cleaned['address'] = str(poi_dict.get('address', '')).strip() or None
    cleaned['description'] = str(poi_dict.get('description', '')).strip() or None
    cleaned['poi_type'] = str(poi_dict.get('poi_type', '')).strip() or None
    cleaned['type_code'] = str(poi_dict.get('type_code', '')).strip() or None
    cleaned['phone'] = str(poi_dict.get('phone', '')).strip() or None
    cleaned['website'] = str(poi_dict.get('website', '')).strip() or None
    cleaned['business_area'] = str(poi_dict.get('business_area', '')).strip() or None
    cleaned['province'] = str(poi_dict.get('province', '')).strip() or None
    cleaned['city'] = str(poi_dict.get('city', '')).strip() or None
    cleaned['district'] = str(poi_dict.get('district', '')).strip() or None
    cleaned['adcode'] = str(poi_dict.get('adcode', '')).strip() or None
    
    # 数值字段
    if 'distance' in poi_dict and poi_dict['distance'] is not None:
        try:
            cleaned['distance'] = float(poi_dict['distance'])
        except (ValueError, TypeError):
            cleaned['distance'] = None
    else:
        cleaned['distance'] = None
    
    if 'rating' in poi_dict and poi_dict['rating'] is not None:
        try:
            rating = float(poi_dict['rating'])
            cleaned['rating'] = max(0, min(5, rating))  # 限制在0-5之间
        except (ValueError, TypeError):
            cleaned['rating'] = None
    else:
        cleaned['rating'] = None
    
    # 图片列表
    if 'images' in poi_dict and poi_dict['images']:
        if isinstance(poi_dict['images'], list):
            cleaned['images'] = [str(img).strip() for img in poi_dict['images'] if img]
        elif isinstance(poi_dict['images'], str):
            try:
                cleaned['images'] = json.loads(poi_dict['images'])
            except json.JSONDecodeError:
                cleaned['images'] = []
        else:
            cleaned['images'] = []
    else:
        cleaned['images'] = []
    
    return cleaned


def import_from_json(json_file: str, db: SessionLocal):
    """
    从JSON文件导入POI数据
    
    Args:
        json_file: JSON文件路径
        db: 数据库会话
    """
    print(f"📂 从JSON文件导入: {json_file}")
    
    with open(json_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # 支持多种JSON格式
    if isinstance(data, list):
        poi_list = data
    elif isinstance(data, dict) and 'pois' in data:
        poi_list = data['pois']
    elif isinstance(data, dict) and 'data' in data:
        poi_list = data['data']
    else:
        print("❌ JSON格式不支持，期望数组或包含'pois'/'data'字段的对象")
        return
    
    import_poi_list(poi_list, db, source="json")


def import_from_csv(csv_file: str, db: SessionLocal):
    """
    从CSV文件导入POI数据
    
    Args:
        csv_file: CSV文件路径
        db: 数据库会话
    """
    print(f"📂 从CSV文件导入: {csv_file}")
    
    poi_list = []
    with open(csv_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            poi_list.append(row)
    
    import_poi_list(poi_list, db, source="csv")


def import_poi_list(poi_list: list, db: SessionLocal, source: str = "manual"):
    """
    批量导入POI列表
    
    Args:
        poi_list: POI数据列表
        db: 数据库会话
        source: 数据来源
    """
    print(f"📊 开始导入 {len(poi_list)} 条POI数据...")
    
    success_count = 0
    skip_count = 0
    error_count = 0
    errors = []
    
    for idx, poi_dict in enumerate(poi_list, 1):
        try:
            # 清洗数据
            cleaned = clean_poi_data(poi_dict)
            
            # 验证数据
            is_valid, error_msg = validate_poi_data(cleaned)
            if not is_valid:
                error_count += 1
                errors.append(f"第{idx}条: {error_msg}")
                print(f"  ❌ [{idx}/{len(poi_list)}] 验证失败: {error_msg}")
                continue
            
            # 检查POI是否已存在
            existing_poi = db.query(POI).filter(POI.poi_id == cleaned['poi_id']).first()
            if existing_poi:
                # 更新现有POI
                existing_poi.name = cleaned['name']
                existing_poi.latitude = Decimal(str(cleaned['latitude']))
                existing_poi.longitude = Decimal(str(cleaned['longitude']))
                existing_poi.address = cleaned['address']
                existing_poi.description = cleaned['description']
                existing_poi.poi_type = cleaned['poi_type']
                existing_poi.type_code = cleaned['type_code']
                existing_poi.distance = Decimal(str(cleaned['distance'])) if cleaned['distance'] else None
                existing_poi.phone = cleaned['phone']
                existing_poi.website = cleaned['website']
                existing_poi.business_area = cleaned['business_area']
                existing_poi.province = cleaned['province']
                existing_poi.city = cleaned['city']
                existing_poi.district = cleaned['district']
                existing_poi.adcode = cleaned['adcode']
                existing_poi.rating = Decimal(str(cleaned['rating'])) if cleaned['rating'] else None
                existing_poi.images = cleaned['images'] if cleaned['images'] else None
                existing_poi.updated_at = datetime.utcnow()
                skip_count += 1
                print(f"  🔄 [{idx}/{len(poi_list)}] 更新: {cleaned['name']}")
            else:
                # 创建新POI
                new_poi = POI(
                    poi_id=cleaned['poi_id'],
                    name=cleaned['name'],
                    latitude=Decimal(str(cleaned['latitude'])),
                    longitude=Decimal(str(cleaned['longitude'])),
                    address=cleaned['address'],
                    description=cleaned['description'],
                    poi_type=cleaned['poi_type'],
                    type_code=cleaned['type_code'],
                    distance=Decimal(str(cleaned['distance'])) if cleaned['distance'] else None,
                    phone=cleaned['phone'],
                    website=cleaned['website'],
                    business_area=cleaned['business_area'],
                    province=cleaned['province'],
                    city=cleaned['city'],
                    district=cleaned['district'],
                    adcode=cleaned['adcode'],
                    rating=Decimal(str(cleaned['rating'])) if cleaned['rating'] else None,
                    images=cleaned['images'] if cleaned['images'] else None
                )
                db.add(new_poi)
                success_count += 1
                print(f"  ✅ [{idx}/{len(poi_list)}] 新增: {cleaned['name']}")
            
            # 每100条提交一次
            if (success_count + skip_count) % 100 == 0:
                db.commit()
                print(f"  💾 已提交 {success_count + skip_count} 条记录")
        
        except Exception as e:
            error_count += 1
            error_msg = f"第{idx}条: {str(e)}"
            errors.append(error_msg)
            print(f"  ❌ [{idx}/{len(poi_list)}] 导入失败: {str(e)}")
            db.rollback()
    
    # 最终提交
    try:
        db.commit()
        print(f"\n✅ 导入完成!")
        print(f"  ✅ 新增: {success_count} 条")
        print(f"  🔄 更新: {skip_count} 条")
        print(f"  ❌ 失败: {error_count} 条")
        
        if errors:
            print(f"\n⚠️ 错误详情:")
            for error in errors[:10]:  # 只显示前10个错误
                print(f"  - {error}")
            if len(errors) > 10:
                print(f"  ... 还有 {len(errors) - 10} 个错误")
    except Exception as e:
        db.rollback()
        print(f"❌ 提交失败: {str(e)}")


def test_data_integrity(db: SessionLocal):
    """
    测试数据完整性
    
    Args:
        db: 数据库会话
    """
    print("\n🔍 测试数据完整性...")
    
    # 统计总数
    total_count = db.query(POI).count()
    print(f"  📊 总POI数: {total_count}")
    
    # 检查必填字段
    missing_name = db.query(POI).filter(
        (POI.name == None) | (POI.name == '')
    ).count()
    missing_lat = db.query(POI).filter(POI.latitude == None).count()
    missing_lon = db.query(POI).filter(POI.longitude == None).count()
    
    print(f"  ✅ 缺少名称: {missing_name} 条")
    print(f"  ✅ 缺少纬度: {missing_lat} 条")
    print(f"  ✅ 缺少经度: {missing_lon} 条")
    
    # 检查重复POI ID
    from sqlalchemy import func
    duplicate_poi_ids = db.query(
        POI.poi_id, func.count(POI.id).label('count')
    ).group_by(POI.poi_id).having(func.count(POI.id) > 1).all()
    
    if duplicate_poi_ids:
        print(f"  ⚠️ 发现重复POI ID: {len(duplicate_poi_ids)} 个")
        for poi_id, count in duplicate_poi_ids[:5]:
            print(f"    - {poi_id}: {count} 条")
    else:
        print(f"  ✅ 无重复POI ID")
    
    # 检查坐标范围
    invalid_lat = db.query(POI).filter(
        (POI.latitude < -90) | (POI.latitude > 90)
    ).count()
    invalid_lon = db.query(POI).filter(
        (POI.longitude < -180) | (POI.longitude > 180)
    ).count()
    
    print(f"  ✅ 纬度超出范围: {invalid_lat} 条")
    print(f"  ✅ 经度超出范围: {invalid_lon} 条")
    
    print("\n✅ 数据完整性测试完成")


def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='POI数据导入脚本')
    parser.add_argument('--json', type=str, help='从JSON文件导入')
    parser.add_argument('--csv', type=str, help='从CSV文件导入')
    parser.add_argument('--init-db', action='store_true', help='初始化数据库表')
    parser.add_argument('--test', action='store_true', help='测试数据完整性')
    
    args = parser.parse_args()
    
    # 初始化数据库
    if args.init_db:
        init_database()
    
    db = SessionLocal()
    
    try:
        # 导入数据
        if args.json:
            import_from_json(args.json, db)
        elif args.csv:
            import_from_csv(args.csv, db)
        
        # 测试数据完整性
        if args.test:
            test_data_integrity(db)
    
    finally:
        db.close()


if __name__ == '__main__':
    main()

