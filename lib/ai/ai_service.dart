import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'ai_config.dart';

/// 调用 OpenAI 兼容接口的最小客户端。
///
/// 目前只在「AI 接口设置」页里用于连通性测试，不接入任何自动流程。
class AiService {
  AiService({AiConfig? config}) : config = config ?? AiConfig.load();

  final AiConfig config;

  static const String defaultPrompt = '回答截图中的题目，只给答案，不要解释或括号补充。';

  Dio _client() {
    return Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 30),
    ));
  }

  Future<String> chat(String prompt, {Uint8List? imagePng}) async {
    if (!config.isConfigured) {
      throw AiException('尚未配置 AI 接口，请先填写接口地址、密钥和模型');
    }

    final List<Map<String, dynamic>> content = <Map<String, dynamic>>[
      <String, dynamic>{'type': 'text', 'text': prompt},
    ];
    if (imagePng != null && imagePng.isNotEmpty) {
      content.add(<String, dynamic>{
        'type': 'image_url',
        'image_url': <String, dynamic>{
          'url': 'data:image/png;base64,${base64Encode(imagePng)}',
        },
      });
    }

    try {
      final Response<dynamic> resp = await _client().post<dynamic>(
        config.chatCompletionsUrl,
        options: Options(
          headers: <String, dynamic>{
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
          },
          validateStatus: (int? status) => status != null,
        ),
        data: <String, dynamic>{
          'model': config.model,
          'messages': <Map<String, dynamic>>[
            <String, dynamic>{'role': 'user', 'content': content},
          ],
          'temperature': 0,
        },
      );

      if (resp.statusCode == null || resp.statusCode! < 200 || resp.statusCode! >= 300) {
        throw AiException('HTTP ${resp.statusCode}：${_brief(resp.data)}');
      }

      return _extractText(resp.data);
    } on DioException catch (e) {
      throw AiException(_describeDio(e));
    }
  }

  String _extractText(dynamic data) {
    if (data is! Map) {
      throw AiException('返回内容无法解析');
    }
    final dynamic choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw AiException('返回内容缺少 choices：${_brief(data)}');
    }
    final dynamic first = choices.first;
    final dynamic message = first is Map ? first['message'] : null;
    final dynamic content = message is Map ? message['content'] : null;

    String text = '';
    if (content is String) {
      text = content;
    } else if (content is List) {
      text = content
          .whereType<Map>()
          .map((Map e) => (e['text'] ?? '').toString())
          .join();
    }
    text = text.trim();
    if (text.isEmpty) {
      throw AiException('模型返回为空');
    }
    return text;
  }

  String _describeDio(DioException e) {
    final int? status = e.response?.statusCode;
    if (status != null) {
      return 'HTTP $status：${_brief(e.response?.data)}';
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '请求超时，请检查接口地址或网络';
      case DioExceptionType.connectionError:
        return '无法连接接口地址，请检查网络或地址是否正确';
      default:
        return e.message ?? '请求失败';
    }
  }

  String _brief(dynamic data) {
    String text;
    if (data is String) {
      text = data;
    } else if (data is Map) {
      final dynamic err = data['error'];
      if (err is Map && err['message'] != null) {
        text = err['message'].toString();
      } else {
        text = data.toString();
      }
    } else {
      text = data?.toString() ?? '';
    }
    text = text.replaceAll('\n', ' ').trim();
    return text.length > 160 ? '${text.substring(0, 160)}…' : text;
  }
}

class AiException implements Exception {
  AiException(this.message);

  final String message;

  @override
  String toString() => message;
}
