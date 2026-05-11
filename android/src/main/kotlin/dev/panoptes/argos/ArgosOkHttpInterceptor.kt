package dev.panoptes.argos

import okhttp3.Interceptor
import okhttp3.Response
import okhttp3.MediaType
import org.json.JSONObject

class ArgosOkHttpInterceptor : Interceptor {

    companion object {
        val instance = ArgosOkHttpInterceptor()
    }

    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        val startTimestamp = System.currentTimeMillis()

        val requestHeaders = mutableMapOf<String, String>()
        request.headers.forEach { (name, value) -> requestHeaders[name] = value }

        val requestBody = try {
            val body = request.body
            if (body != null && isTextMediaType(body.contentType())) {
                val buffer = okio.Buffer()
                body.writeTo(buffer)
                buffer.readUtf8()
            } else ""
        } catch (_: Exception) { "" }

        val response: Response
        val errorStr: String?
        try {
            response = chain.proceed(request)
            errorStr = null
        } catch (e: Exception) {
            val endTimestamp = System.currentTimeMillis()
            sendEvent(
                id = startTimestamp.toString(),
                uri = request.url.toString(),
                method = request.method,
                startTimestamp = startTimestamp,
                endTimestamp = endTimestamp,
                requestHeaders = requestHeaders,
                requestBody = requestBody,
                responseCode = 0,
                responseBody = "",
                responseHeaders = emptyMap(),
                responseSize = 0,
                error = e.message ?: "Unknown error",
            )
            throw e
        }

        val endTimestamp = System.currentTimeMillis()

        val responseHeaders = mutableMapOf<String, String>()
        response.headers.forEach { (name, value) -> responseHeaders[name] = value }

        val contentType = response.body?.contentType()
        val responseBody = try {
            if (isTextMediaType(contentType)) {
                val source = response.peekBody(100 * 1024)
                source.string()
            } else ""
        } catch (_: Exception) { "" }

        val responseSize = response.body?.contentLength()?.toInt() ?: responseBody.length

        sendEvent(
            id = startTimestamp.toString(),
            uri = request.url.toString(),
            method = request.method,
            startTimestamp = startTimestamp,
            endTimestamp = endTimestamp,
            requestHeaders = requestHeaders,
            requestBody = requestBody,
            responseCode = response.code,
            responseBody = responseBody,
            responseHeaders = responseHeaders,
            responseSize = responseSize,
            error = null,
        )

        return response
    }

    private fun isTextMediaType(mediaType: MediaType?): Boolean {
        if (mediaType == null) return false
        val type = mediaType.type
        val subtype = mediaType.subtype
        return type == "text" ||
                subtype.contains("json") ||
                subtype.contains("xml") ||
                subtype.contains("html") ||
                subtype.contains("plain")
    }

    private fun sendEvent(
        id: String,
        uri: String,
        method: String,
        startTimestamp: Long,
        endTimestamp: Long,
        requestHeaders: Map<String, String>,
        requestBody: String,
        responseCode: Int,
        responseBody: String,
        responseHeaders: Map<String, String>,
        responseSize: Int,
        error: String?,
    ) {
        try {
            val reqHeadersJson = JSONObject(requestHeaders)
            val resHeadersJson = JSONObject(responseHeaders)
            val obj = JSONObject().apply {
                put("id", id)
                put("uri", uri)
                put("method", method)
                put("startTimestamp", startTimestamp)
                put("endTimestamp", endTimestamp)
                put("requestHeaders", reqHeadersJson)
                put("requestBody", requestBody)
                put("responseCode", responseCode)
                put("responseBody", responseBody)
                put("responseHeaders", resHeadersJson)
                put("responseSize", responseSize)
                if (error != null) put("error", error) else put("error", JSONObject.NULL)
                put("routeName", "")
            }
            ArgosPlugin.eventSink?.let { sink ->
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    sink.success(obj.toString())
                }
            }
        } catch (_: Exception) {}
    }
}
