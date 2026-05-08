package com.campuswalk.dto;

/**
 * 供大模型使用的单轮对话片段（user / assistant），不含系统提示。
 */
public record ChatTurn(String role, String content) {
}
