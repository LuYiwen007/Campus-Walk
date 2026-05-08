package com.campuswalk.web;

import com.campuswalk.entity.User;
import com.campuswalk.repository.UserRepository;
import com.campuswalk.security.JwtService;
import com.campuswalk.service.CurrentUserService;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final CurrentUserService currentUserService;

    public record RegisterBody(
            @Email @NotBlank String email,
            @NotBlank @Size(min = 8, max = 128) String password,
            String nickname
    ) {
    }

    public record LoginBody(@Email @NotBlank String email, @NotBlank String password) {
    }

    @PostMapping("/register")
    public ApiResponse<Map<String, Object>> register(@RequestBody @jakarta.validation.Valid RegisterBody body) {
        if (userRepository.existsByEmail(body.email())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "该邮箱已注册");
        }
        String nick = body.nickname();
        if (nick == null || nick.isBlank()) {
            nick = body.email().split("@")[0];
        }
        User user = new User();
        user.setEmail(body.email());
        user.setPasswordHash(passwordEncoder.encode(body.password()));
        user.setNickname(nick);
        user = userRepository.save(user);

        Map<String, Object> u = userVo(user);
        return ApiResponse.ok("注册成功，请登录", Map.of("user", u));
    }

    @PostMapping("/login")
    public ApiResponse<Map<String, Object>> login(@RequestBody @jakarta.validation.Valid LoginBody body) {
        User user = userRepository.findByEmail(body.email())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "邮箱或密码错误"));
        if (!passwordEncoder.matches(body.password(), user.getPasswordHash())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "邮箱或密码错误");
        }
        Map<String, Object> token = new LinkedHashMap<>();
        token.put("access_token", jwtService.createAccessToken(user.getId()));
        token.put("token_type", "bearer");
        token.put("user", userVo(user));
        return ApiResponse.ok(token);
    }

    @GetMapping("/me")
    public ApiResponse<Map<String, Object>> me() {
        User user = currentUserService.requireCurrentUser();
        return ApiResponse.ok(userVo(user));
    }

    private static Map<String, Object> userVo(User user) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", user.getId());
        m.put("email", user.getEmail());
        m.put("nickname", user.getNickname());
        return m;
    }
}
