package com.campuswalk.web;

public record ApiResponse<T>(boolean success, String resultCode, String message, T data) {

    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(true, "SUCCESS", "", data);
    }

    public static <T> ApiResponse<T> ok(String message, T data) {
        return new ApiResponse<>(true, "SUCCESS", message != null ? message : "", data);
    }

    public static ApiResponse<Void> okEmpty() {
        return new ApiResponse<>(true, "SUCCESS", "", null);
    }
}
