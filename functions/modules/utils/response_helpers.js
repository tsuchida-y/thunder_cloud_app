// functions/modules/utils/response_helpers.js

class ResponseHelpers {
  /**
   * CORS ヘッダーを設定
   */
  static setCORSHeaders(res) {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
  }

  /**
   * 成功レスポンスを送信
   */
  static sendSuccess(res, data, additionalFields = {}) {
    res.status(200).json({
      success: true,
      data: data,
      timestamp: new Date().toISOString(),
      ...additionalFields
    });
  }

  /**
   * エラーレスポンスを送信
   */
  static sendError(res, statusCode, error, message = null) {
    const response = {
      error: error,
      timestamp: new Date().toISOString()
    };

    if (message) {
      response.message = message;
    }

    res.status(statusCode).json(response);
  }

  /**
   * 夜間モードレスポンスを送信
   */
  static sendNightModeResponse(res, nightModeData) {
    res.status(200).json({
      success: true,
      data: nightModeData,
      timestamp: new Date().toISOString(),
      nightMode: true
    });
  }
}

module.exports = ResponseHelpers;
