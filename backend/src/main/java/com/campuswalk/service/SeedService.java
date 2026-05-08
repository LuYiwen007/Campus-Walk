package com.campuswalk.service;

import com.campuswalk.config.AppProperties;
import com.campuswalk.entity.Building;
import com.campuswalk.entity.CommunityPost;
import com.campuswalk.entity.User;
import com.campuswalk.repository.BuildingRepository;
import com.campuswalk.repository.CommunityPostRepository;
import com.campuswalk.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class SeedService {

    public static final String TEST_EMAIL = "demo@campuswalk.local";
    public static final String TEST_PASSWORD = "CampusWalk2026!";

    private final AppProperties appProperties;
    private final UserRepository userRepository;
    private final BuildingRepository buildingRepository;
    private final CommunityPostRepository communityPostRepository;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public void seedIfNeeded() {
        if (!appProperties.isSeedOnStartup()) {
            return;
        }
        if (userRepository.findByEmail(TEST_EMAIL).isPresent()) {
            log.info("seed: test user already exists");
            ensureBuildingsAndPosts();
            return;
        }
        User user = new User();
        user.setEmail(TEST_EMAIL);
        user.setPasswordHash(passwordEncoder.encode(TEST_PASSWORD));
        user.setNickname("测试用户");
        userRepository.save(user);
        log.info("seed: created test user {} / {}", TEST_EMAIL, TEST_PASSWORD);
        ensureBuildingsAndPosts();
    }

    private void ensureBuildingsAndPosts() {
        if (buildingRepository.count() == 0) {
            Building lib = new Building();
            lib.setName("图书馆");
            lib.setDescription("校园主图书馆，藏书丰富，玻璃幕墙与中央大厅为标志。");
            lib.setLatitude(23.13219);
            lib.setLongitude(113.264385);
            lib.setAddress("校园中区");
            lib.setCoverImageUrl("https://picsum.photos/seed/library/800/600");
            lib.setGalleryUrls(List.of(
                    "https://picsum.photos/seed/library2/800/600",
                    "https://picsum.photos/seed/library3/800/600"
            ));
            lib.setRecognitionHint(Map.of("keywords", List.of("图书馆", "玻璃")));

            Building gym = new Building();
            gym.setName("体育馆");
            gym.setDescription("综合体育馆，可进行篮球与羽毛球活动。");
            gym.setLatitude(23.1315);
            gym.setLongitude(113.2655);
            gym.setAddress("校园东区");
            gym.setCoverImageUrl("https://picsum.photos/seed/gym/800/600");
            gym.setGalleryUrls(List.of("https://picsum.photos/seed/gym2/800/600"));
            gym.setRecognitionHint(Map.of("keywords", List.of("体育馆")));

            Building pavilion = new Building();
            pavilion.setName("湖心亭");
            pavilion.setDescription("湖畔休憩小景，适合短暂停留。");
            pavilion.setLatitude(23.1319);
            pavilion.setLongitude(113.2640);
            pavilion.setAddress("校园湖区");
            pavilion.setCoverImageUrl("https://picsum.photos/seed/pavilion/800/600");
            pavilion.setGalleryUrls(List.of());
            pavilion.setRecognitionHint(Map.of("keywords", List.of("湖心亭", "湖")));

            buildingRepository.saveAll(List.of(lib, gym, pavilion));
            log.info("seed: inserted 3 buildings");
        }

        if (communityPostRepository.count() == 0) {
            CommunityPost p1 = new CommunityPost();
            p1.setTitle("校园晨跑路线分享");
            p1.setBody("从东门到操场再到湖边，一圈刚好三公里，适合晨跑打卡。");
            p1.setCoverImageUrl("https://picsum.photos/seed/campus1/600/800");
            p1.setAuthorDisplayName("跑友小林");
            p1.setAuthorAvatarUrl("https://picsum.photos/seed/avatar1/200/200");
            p1.setLikesCount(42);

            CommunityPost p2 = new CommunityPost();
            p2.setTitle("图书馆自习攻略");
            p2.setBody("静音区与讨论区分区明确，预约座位更方便。");
            p2.setCoverImageUrl("https://picsum.photos/seed/campus2/600/800");
            p2.setAuthorDisplayName("学习委员");
            p2.setAuthorAvatarUrl("https://picsum.photos/seed/avatar2/200/200");
            p2.setLikesCount(88);

            CommunityPost p3 = new CommunityPost();
            p3.setTitle("食堂新品测评");
            p3.setBody("二楼窗口新出的轻食套餐，适合课多的一天。");
            p3.setCoverImageUrl("https://picsum.photos/seed/campus3/600/800");
            p3.setAuthorDisplayName("吃货阿伟");
            p3.setAuthorAvatarUrl("https://picsum.photos/seed/avatar3/200/200");
            p3.setLikesCount(120);

            communityPostRepository.saveAll(List.of(p1, p2, p3));
            log.info("seed: inserted 3 community posts");
        }
    }
}
