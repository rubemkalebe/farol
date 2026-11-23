package dev.merkab.farol

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // "Passar o Farol adiante": onde está o APK instalado, para enviar
        // a outro celular sem internet.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "farol/apk")
            .setMethodCallHandler { call, result ->
                if (call.method == "apk") {
                    val info = applicationInfo
                    result.success(
                        mapOf(
                            "caminho" to info.sourceDir,
                            "dividido" to !info.splitSourceDirs.isNullOrEmpty(),
                        )
                    )
                } else {
                    result.notImplemented()
                }
            }
    }
}
