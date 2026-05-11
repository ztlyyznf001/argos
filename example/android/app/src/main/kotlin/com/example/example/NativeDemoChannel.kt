package com.example.example

import dev.panoptes.argos.ArgosOkHttpInterceptor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import okhttp3.Call
import okhttp3.Callback
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.io.IOException

object NativeDemoChannel {
    private const val CHANNEL_NAME = "argos_example/native_demo"

    private val client: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .addInterceptor(ArgosOkHttpInterceptor.instance)
            .build()
    }

    fun register(messenger: BinaryMessenger) {
        val channel = MethodChannel(messenger, CHANNEL_NAME)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "sendAndroidRequest" -> {
                    sendAndroidRequest()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun sendAndroidRequest() {
        val request = Request.Builder()
            .url("https://httpbin.org/get?platform=android&source=native")
            .build()
        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {}
            override fun onResponse(call: Call, response: Response) {
                response.close()
            }
        })
    }
}
