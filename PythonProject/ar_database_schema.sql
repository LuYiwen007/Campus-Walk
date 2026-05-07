-- AR功能数据库设计
-- 基于现有数据库结构扩展

-- 1. 建筑信息表
CREATE TABLE buildings (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL COMMENT '建筑名称',
    description TEXT COMMENT '建筑描述',
    latitude DECIMAL(10, 8) NOT NULL COMMENT '纬度',
    longitude DECIMAL(11, 8) NOT NULL COMMENT '经度',
    address VARCHAR(512) COMMENT '详细地址',
    building_type VARCHAR(64) DEFAULT 'unknown' COMMENT '建筑类型',
    floor_count INT DEFAULT 0 COMMENT '楼层数',
    year_built YEAR COMMENT '建造年份',
    architect VARCHAR(255) COMMENT '建筑师',
    style VARCHAR(128) COMMENT '建筑风格',
    features JSON COMMENT '建筑特色',
    images JSON COMMENT '建筑图片URLs',
    is_landmark BOOLEAN DEFAULT FALSE COMMENT '是否为地标建筑',
    popularity_score FLOAT DEFAULT 0.0 COMMENT '热门度评分',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_location (latitude, longitude),
    INDEX idx_name (name),
    INDEX idx_landmark (is_landmark)
);

-- 2. AR地标表
CREATE TABLE ar_landmarks (
    id INT PRIMARY KEY AUTO_INCREMENT,
    building_id INT NOT NULL,
    landmark_name VARCHAR(255) NOT NULL COMMENT '地标名称',
    landmark_type VARCHAR(64) DEFAULT 'building' COMMENT '地标类型',
    ar_anchor_id VARCHAR(128) UNIQUE COMMENT 'AR锚点ID',
    position_x FLOAT COMMENT 'AR场景中的X坐标',
    position_y FLOAT COMMENT 'AR场景中的Y坐标', 
    position_z FLOAT COMMENT 'AR场景中的Z坐标',
    rotation_x FLOAT DEFAULT 0 COMMENT 'X轴旋转角度',
    rotation_y FLOAT DEFAULT 0 COMMENT 'Y轴旋转角度',
    rotation_z FLOAT DEFAULT 0 COMMENT 'Z轴旋转角度',
    scale_x FLOAT DEFAULT 1.0 COMMENT 'X轴缩放',
    scale_y FLOAT DEFAULT 1.0 COMMENT 'Y轴缩放',
    scale_z FLOAT DEFAULT 1.0 COMMENT 'Z轴缩放',
    is_active BOOLEAN DEFAULT TRUE COMMENT '是否激活',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (building_id) REFERENCES buildings(id) ON DELETE CASCADE,
    INDEX idx_building (building_id),
    INDEX idx_anchor (ar_anchor_id)
);

-- 3. 导航路线表
CREATE TABLE navigation_routes (
    id INT PRIMARY KEY AUTO_INCREMENT,
    route_name VARCHAR(255) NOT NULL COMMENT '路线名称',
    start_building_id INT COMMENT '起点建筑ID',
    end_building_id INT COMMENT '终点建筑ID',
    start_latitude DECIMAL(10, 8) NOT NULL COMMENT '起点纬度',
    start_longitude DECIMAL(11, 8) NOT NULL COMMENT '起点经度',
    end_latitude DECIMAL(10, 8) NOT NULL COMMENT '终点纬度', 
    end_longitude DECIMAL(11, 8) NOT NULL COMMENT '终点经度',
    route_type VARCHAR(32) DEFAULT 'walking' COMMENT '路线类型',
    distance_meters INT COMMENT '总距离(米)',
    estimated_time_seconds INT COMMENT '预计时间(秒)',
    route_data JSON COMMENT '详细路线数据',
    waypoints JSON COMMENT '途经点',
    difficulty_level INT DEFAULT 1 COMMENT '难度等级 1-5',
    is_accessible BOOLEAN DEFAULT TRUE COMMENT '是否无障碍',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (start_building_id) REFERENCES buildings(id),
    FOREIGN KEY (end_building_id) REFERENCES buildings(id),
    INDEX idx_start_location (start_latitude, start_longitude),
    INDEX idx_end_location (end_latitude, end_longitude)
);

-- 4. 用户AR会话表
CREATE TABLE user_ar_sessions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id VARCHAR(64) NOT NULL COMMENT '用户ID',
    session_type VARCHAR(32) NOT NULL COMMENT '会话类型: recognition/navigation',
    start_latitude DECIMAL(10, 8) COMMENT '开始纬度',
    start_longitude DECIMAL(11, 8) COMMENT '开始经度',
    current_latitude DECIMAL(10, 8) COMMENT '当前纬度',
    current_longitude DECIMAL(11, 8) COMMENT '当前经度',
    heading_degrees FLOAT COMMENT '朝向角度',
    pitch_degrees FLOAT COMMENT '俯仰角度',
    roll_degrees FLOAT COMMENT '翻滚角度',
    device_info JSON COMMENT '设备信息',
    session_data JSON COMMENT '会话数据',
    is_active BOOLEAN DEFAULT TRUE COMMENT '是否活跃',
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user (user_id),
    INDEX idx_session_type (session_type),
    INDEX idx_active (is_active)
);

-- 5. AR识别记录表
CREATE TABLE ar_recognition_logs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    session_id INT NOT NULL,
    user_id VARCHAR(64) NOT NULL,
    image_data LONGBLOB COMMENT '识别图片数据',
    image_url VARCHAR(512) COMMENT '图片URL',
    recognized_building_id INT COMMENT '识别到的建筑ID',
    confidence_score FLOAT COMMENT '识别置信度',
    recognition_method VARCHAR(32) DEFAULT 'vision' COMMENT '识别方法',
    processing_time_ms INT COMMENT '处理时间(毫秒)',
    device_orientation VARCHAR(32) COMMENT '设备朝向',
    lighting_conditions VARCHAR(32) COMMENT '光照条件',
    weather_conditions VARCHAR(32) COMMENT '天气条件',
    recognition_result JSON COMMENT '识别结果详情',
    is_correct BOOLEAN COMMENT '识别是否正确',
    user_feedback VARCHAR(512) COMMENT '用户反馈',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (session_id) REFERENCES user_ar_sessions(id) ON DELETE CASCADE,
    FOREIGN KEY (recognized_building_id) REFERENCES buildings(id),
    INDEX idx_session (session_id),
    INDEX idx_user (user_id),
    INDEX idx_building (recognized_building_id)
);

-- 6. 导航历史表
CREATE TABLE navigation_history (
    id INT PRIMARY KEY AUTO_INCREMENT,
    session_id INT NOT NULL,
    user_id VARCHAR(64) NOT NULL,
    route_id INT COMMENT '使用的路线ID',
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP NULL,
    total_distance_meters INT COMMENT '总距离',
    actual_duration_seconds INT COMMENT '实际用时',
    navigation_points JSON COMMENT '导航点数据',
    user_rating INT COMMENT '用户评分 1-5',
    user_feedback TEXT COMMENT '用户反馈',
    completion_status VARCHAR(32) DEFAULT 'in_progress' COMMENT '完成状态',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (session_id) REFERENCES user_ar_sessions(id) ON DELETE CASCADE,
    FOREIGN KEY (route_id) REFERENCES navigation_routes(id),
    INDEX idx_session (session_id),
    INDEX idx_user (user_id),
    INDEX idx_route (route_id)
);

-- 7. 建筑特征表 (用于机器学习)
CREATE TABLE building_features (
    id INT PRIMARY KEY AUTO_INCREMENT,
    building_id INT NOT NULL,
    feature_type VARCHAR(64) NOT NULL COMMENT '特征类型',
    feature_data JSON NOT NULL COMMENT '特征数据',
    model_version VARCHAR(32) COMMENT '模型版本',
    confidence_score FLOAT COMMENT '特征置信度',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (building_id) REFERENCES buildings(id) ON DELETE CASCADE,
    INDEX idx_building (building_id),
    INDEX idx_type (feature_type)
);

-- 8. 用户偏好表
CREATE TABLE user_preferences (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id VARCHAR(64) NOT NULL,
    preferred_building_types JSON COMMENT '偏好建筑类型',
    preferred_route_types JSON COMMENT '偏好路线类型',
    accessibility_needs JSON COMMENT '无障碍需求',
    language_preference VARCHAR(8) DEFAULT 'zh-CN' COMMENT '语言偏好',
    ar_settings JSON COMMENT 'AR设置',
    notification_settings JSON COMMENT '通知设置',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_user (user_id)
);

-- 插入示例数据
INSERT INTO buildings (name, description, latitude, longitude, address, building_type, is_landmark) VALUES
('图书馆', '校园主图书馆，藏书丰富，学习氛围浓厚', 23.132, 113.264, '广州市天河区', 'library', TRUE),
('教学楼A', '主要教学楼，包含多个教室和实验室', 23.133, 113.265, '广州市天河区', 'classroom', FALSE),
('体育馆', '现代化体育设施，包含篮球场、游泳池等', 23.131, 113.263, '广州市天河区', 'sports', TRUE);

INSERT INTO ar_landmarks (building_id, landmark_name, ar_anchor_id, position_x, position_y, position_z) VALUES
(1, '图书馆主入口', 'lib_main_001', 0.0, 0.0, -2.0),
(2, '教学楼A正门', 'class_a_001', 1.5, 0.0, -1.8),
(3, '体育馆入口', 'gym_001', -1.2, 0.0, -2.5);
